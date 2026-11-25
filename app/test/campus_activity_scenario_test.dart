import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/services/activity_service.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/social_service.dart';
import 'fakes/social_storage.dart';

// Scripted in-memory campus: 15 classmates in one school across graduation
// years, plus one outsider in another school. It defines CLIENT-visible
// shapes only; it never proves real server counting, Auth, SMS or APNs.
// Real counting stays in backend isolated QA with fixture cleanup.
class FakeCampusServer {
  FakeCampusServer._();
  factory FakeCampusServer.seeded() {
    final server = FakeCampusServer._();
    const school = 'US-CCD-100';
    final rows = [
      ('qa00', 'aman_qa', 'Aman', 'Iskakov', 2027),
      ('qa01', 'qa_aylin', 'Aylin', 'Serik', 2027),
      ('qa02', 'qa_dias', 'Dias', 'Bolat', 2027),
      ('qa03', 'qa_alina', 'Alina', 'Kim', 2027),
      ('qa04', 'qa_timur', 'Timur', 'Akhmet', 2027),
      ('qa05', 'qa_madina', 'Madina', 'Nurlan', 2025),
      ('qa06', 'qa_arman', 'Arman', 'Doszhan', 2025),
      ('qa07', 'qa_dana', 'Dana', 'Erkin', 2026),
      ('qa08', 'qa_yerlan', 'Yerlan', 'Samat', 2026),
      ('qa09', 'qa_kamila', 'Kamila', 'Omar', 2028),
      ('qa10', 'qa_nurs', 'Nursultan', 'Bauyr', 2028),
      ('qa11', 'qa_aigerim', 'Aigerim', 'Talgar', 2029),
      ('qa12', 'qa_olzhas', 'Olzhas', 'Kanat', 2029),
      ('qa13', 'qa_sabina', 'Sabina', 'Renat', 2030),
      ('qa14', 'qa_damir', 'Damir', 'Ilyas', 2030),
    ];
    for (final (id, username, first, last, year) in rows) {
      server.users[id] = {
        'id': id,
        'username': username,
        'firstName': first,
        'lastName': last,
        'schoolId': school,
        'graduationYear': year,
      };
    }
    server.users['qa99'] = {
      'id': 'qa99',
      'username': 'outsider_lee',
      'firstName': 'Lee',
      'lastName': 'Outsider',
      'schoolId': 'US-CCD-200',
      'graduationYear': 2027,
    };
    // Five classmates nominate the target across two questions.
    server.nominate('qa01', 'qa00', 'q1', 'Who makes everyone smile?');
    server.nominate('qa02', 'qa00', 'q1', 'Who makes everyone smile?');
    server.nominate('qa03', 'qa00', 'q1', 'Who makes everyone smile?');
    server.nominate('qa04', 'qa00', 'q2', 'Best study buddy');
    server.nominate('qa05', 'qa00', 'q2', 'Best study buddy');
    // Classmates vote among themselves.
    server.nominate('qa06', 'qa07', 'q3', 'Most likely to help');
    server.nominate('qa07', 'qa06', 'q3', 'Most likely to help');
    server.nominate('qa08', 'qa09', 'q3', 'Most likely to help');
    server.nominate('qa10', 'qa11', 'q3', 'Most likely to help');
    server.nominate('qa12', 'qa13', 'q3', 'Most likely to help');
    // Six incoming friend requests for the target; one incoming block.
    for (final from in ['qa01', 'qa02', 'qa03', 'qa04', 'qa05', 'qa06']) {
      server.requests.add('$from>qa00');
    }
    server.blocks.add('qa07>qa00');
    // 25 activity events, newest first; the target wins six of them.
    final winners = [
      'qa00', 'qa03', 'qa06', 'qa09', 'qa00', 'qa12', 'qa01', 'qa00', 'qa07',
      'qa10', 'qa00', 'qa04', 'qa13', 'qa08', 'qa00', 'qa11', 'qa02', 'qa14',
      'qa00', 'qa05', 'qa09', 'qa03', 'qa12', 'qa06', 'qa01',
    ];
    final questions = [
      'Who makes everyone smile?',
      'Best study buddy',
      'Most likely to help',
    ];
    for (var i = 0; i < winners.length; i++) {
      final winner = server.users[winners[i]]!;
      server.events.add({
        'id': 'ev$i',
        'chosenName': '${winner['firstName']} ${winner['lastName']}',
        'question': questions[i % questions.length],
        'graduationYear': winner['graduationYear'],
        'occurredAt': '2026-11-2${i % 10}T12:00:00Z',
      });
    }
    return server;
  }

  final users = <String, Map<String, dynamic>>{};
  final requests = <String>{};
  final friends = <String>{};
  final blocks = <String>{};
  final nominations = <String, List<Map<String, String>>>{};
  final events = <Map<String, dynamic>>[];
  // Test-only gate: hold an in-flight response to switch accounts mid-flight.
  Completer<void>? entered;
  Future<void>? hold;

  void reset() {
    users.clear();
    requests.clear();
    friends.clear();
    blocks.clear();
    nominations.clear();
    events.clear();
  }

  bool get isEmpty =>
      users.isEmpty &&
      requests.isEmpty &&
      friends.isEmpty &&
      blocks.isEmpty &&
      nominations.isEmpty &&
      events.isEmpty;

  /// Records one nomination; self-votes are rejected, never stored.
  void nominate(String voter, String target, String questionId, String question) {
    if (voter == target) throw StateError('self-vote is not a candidate');
    if (!users.containsKey(voter) || !users.containsKey(target)) {
      throw StateError('unknown voter or target');
    }
    nominations
        .putIfAbsent(target, () => [])
        .add({'questionId': questionId, 'question': question});
  }

  String? userByToken(String? token) {
    if (token == null || !token.startsWith('token-')) return null;
    final id = token.substring('token-'.length);
    return users.containsKey(id) ? id : null;
  }

  bool blockedEitherWay(String a, String b) =>
      blocks.contains('$a>$b') || blocks.contains('$b>$a');

  bool visible(String me, String other) {
    if (me == other) return false;
    final a = users[me], b = users[other];
    if (a == null || b == null) return false;
    if (a['schoolId'] != b['schoolId']) return false;
    return !blockedEitherWay(me, other);
  }

  String relationship(String me, String other) {
    final pair = [me, other]..sort();
    if (friends.contains('${pair[0]}|${pair[1]}')) return 'friends';
    if (requests.contains('$me>$other')) return 'outgoing';
    if (requests.contains('$other>$me')) return 'incoming';
    return 'none';
  }

  Map<String, dynamic> card(String me, String id) => {
    'id': id,
    'username': users[id]!['username'],
    'relationship': relationship(me, id),
  };

  int friendsCount(String id) =>
      friends.where((p) => p.split('|').contains(id)).length;

  ResponseBody json(int status, Map<String, dynamic> data) =>
      ResponseBody.fromString(
        jsonEncode(data),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  Future<ResponseBody> handle(RequestOptions req) async {
    if (entered != null && !entered!.isCompleted) entered!.complete();
    if (hold != null) await hold;
    final auth = req.headers['Authorization'] as String?;
    final me = userByToken(
      auth != null && auth.startsWith('Bearer ') ? auth.substring(7) : null,
    );
    if (me == null) return json(401, {'message': 'Sign in.'});
    final path = req.uri.path;
    if (req.method == 'GET' && path == '/api/social/suggestions') {
      final campus = users.keys
          .where((id) => visible(me, id))
          .map((id) => card(me, id))
          .toList();
      return json(200, {'campus': campus, 'friendsOfFriends': []});
    }
    if (req.method == 'GET' && path == '/api/social/search') {
      final q = (req.uri.queryParameters['q'] ?? req.uri.queryParameters['username'] ?? '').toLowerCase();
      if (q.length < 2) return json(200, {'users': []});
      final found = users.keys
          .where(
            (id) =>
                visible(me, id) &&
                (users[id]!['username'] as String).toLowerCase().startsWith(q),
          )
          .map((id) => card(me, id))
          .toList();
      return json(200, {'users': found});
    }
    if (req.method == 'GET' && path == '/api/social/list') {
      final kind = req.uri.queryParameters['kind'];
      if (kind == 'requests') {
        final incoming = requests
            .where((r) => r.endsWith('>$me'))
            .map((r) => card(me, r.split('>').first))
            .toList();
        return json(200, {'users': incoming});
      }
      if (kind == 'friends') {
        final mine = friends
            .where((p) => p.split('|').contains(me))
            .map(
              (p) => card(
                me,
                p.split('|').firstWhere((id) => id != me),
              ),
            )
            .toList();
        return json(200, {'users': mine});
      }
      return json(400, {'message': 'Unknown list.'});
    }
    if (path.startsWith('/api/social/users/')) {
      final rest = path.substring('/api/social/users/'.length);
      final parts = rest.split('/');
      final id = Uri.decodeComponent(parts.first);
      if (parts.length == 2 && parts[1] == 'nominations') {
        if (id != me && !visible(me, id)) {
          return json(404, {'message': 'Not found.'});
        }
        final votes = nominations[id] ?? [];
        final grouped = <String, Map<String, dynamic>>{};
        for (final v in votes) {
          grouped
              .putIfAbsent(v['questionId']!, () => {
                'questionId': v['questionId'],
                'question': v['question'],
                'count': 0,
              })
              .update('count', (c) => (c as int) + 1);
        }
        return json(200, {
          'friendsCount': friendsCount(id),
          'votesReceived': votes.length,
          'items': grouped.values.toList(),
          'nextCursor': null,
        });
      }
      if (parts.length == 1 && req.method == 'GET') {
        if (id != me && !visible(me, id)) {
          return json(404, {'message': 'Not found.'});
        }
        return json(200, card(me, id));
      }
      if (parts.length == 2 && req.method == 'POST') {
        return _act(me, id, parts[1]);
      }
      return json(404, {'message': 'Not found.'});
    }
    if (req.method == 'GET' && path == '/api/activity') {
      final offset = int.tryParse(req.uri.queryParameters['cursor'] ?? '0') ?? 0;
      final slice = events.skip(offset).take(20).toList();
      final next = offset + 20;
      return json(200, {
        'items': slice,
        'nextCursor': next < events.length ? '$next' : null,
        'campusRequired': false,
      });
    }
    return json(404, {'message': 'Not found.'});
  }

  ResponseBody _act(String me, String id, String action) {
    if (!users.containsKey(id)) return json(404, {'message': 'Not found.'});
    if (action == 'block') {
      blocks.add('$me>$id');
      final pair = [me, id]..sort();
      friends.remove('${pair[0]}|${pair[1]}');
      requests.remove('$me>$id');
      requests.remove('$id>$me');
      return json(200, {'ok': true});
    }
    if (action == 'unblock') {
      blocks.remove('$me>$id');
      return json(200, {'ok': true});
    }
    // request/accept/decline require mutual visibility: same campus,
    // no block either way, never self.
    if (!visible(me, id)) return json(404, {'message': 'Not found.'});
    if (action == 'request') {
      requests.add('$me>$id');
      return json(200, {'ok': true});
    }
    if (action == 'accept') {
      if (!requests.remove('$id>$me')) {
        return json(404, {'message': 'No request.'});
      }
      final pair = [me, id]..sort();
      friends.add('${pair[0]}|${pair[1]}');
      return json(200, {'ok': true});
    }
    if (action == 'decline') {
      requests.remove('$id>$me');
      return json(200, {'ok': true});
    }
    return json(404, {'message': 'Not found.'});
  }
}

class _CampusAdapter implements HttpClientAdapter {
  _CampusAdapter(this.server);
  final FakeCampusServer server;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => server.handle(options);
  @override
  void close({bool force = false}) {}
}

void main() {
  ({
    FakeCampusServer server,
    SessionStorage storage,
    SocialService social,
    ActivityService activity,
  })
  mount(String userId, [FakeCampusServer? shared]) {
    final server = shared ?? FakeCampusServer.seeded();
    final storage = SessionStorage()..token = 'token-$userId';
    final api = ApiService(storage)
      ..dio.httpClientAdapter = _CampusAdapter(server);
    return (
      server: server,
      storage: storage,
      social: SocialService(api, storage),
      activity: ActivityService(api, storage),
    );
  }

  test('fifteen classmates share one campus across graduation years', () async {
    final f = mount('qa00');
    final data = await f.social.suggestions();
    final campus = (data['campus'] as List).cast<Map<String, dynamic>>();
    // 15 classmates minus self minus the incoming blocker (both directions).
    expect(campus.length, 13);
    expect(campus.map((c) => c['id']), containsAll(['qa01', 'qa14']));
    expect(campus.map((c) => c['id']), isNot(contains('qa07')));
    expect(campus.map((c) => c['id']), isNot(contains('qa99')));
    final years = {
      for (final c in campus)
        f.server.users[c['id']]!['graduationYear'] as int,
    }..add(f.server.users['qa00']!['graduationYear'] as int);
    expect(years, {2025, 2026, 2027, 2028, 2029, 2030});
    // The outsider is alone in their own school.
    final o = mount('qa99');
    final alone = await o.social.suggestions();
    expect((alone['campus'] as List), isEmpty);
    f.server.reset();
    o.server.reset();
    expect(f.server.isEmpty, isTrue);
    expect(o.server.isEmpty, isTrue);
  });

  test('five classmates nominate the target; self-votes never exist', () async {
    final f = mount('qa00');
    expect(
      () => f.server.nominate('qa00', 'qa00', 'q1', 'Self praise'),
      throwsStateError,
    );
    final data = await f.social.nominations('qa00');
    expect(data.votesReceived, 5);
    expect(data.friendsCount, 0);
    expect(
      {for (final i in data.items) i.questionId: i.count},
      {'q1': 3, 'q2': 2},
    );
    // Raw payload carries counts only, never voter identity.
    final raw = await f.social.request('/users/qa00/nominations');
    expect(jsonEncode(raw).toLowerCase(), isNot(contains('voter')));
    f.server.reset();
    expect(f.server.isEmpty, isTrue);
  });

  test('six incoming requests land; two accepted become friends', () async {
    final f = mount('qa00');
    final pending = await f.social.list('requests');
    expect((pending['users'] as List).length, 6);
    await f.social.act('qa01', 'accept');
    await f.social.act('qa02', 'accept');
    final friends = await f.social.list('friends');
    expect(
      (friends['users'] as List).map((u) => (u as Map)['id']),
      containsAll(['qa01', 'qa02']),
    );
    final left = await f.social.list('requests');
    expect((left['users'] as List).length, 4);
    final found = await f.social.search('qa_aylin');
    expect((found['users'] as List).single['relationship'], 'friends');
    f.server.reset();
    expect(f.server.isEmpty, isTrue);
  });

  test('one blocker hides both ways until unblocked', () async {
    final shared = FakeCampusServer.seeded();
    final target = mount('qa00', shared);
    final blocker = mount('qa07', shared);
    expect(
      ((await target.social.suggestions())['campus'] as List)
          .map((c) => (c as Map)['id']),
      isNot(contains('qa07')),
    );
    expect(
      ((await blocker.social.suggestions())['campus'] as List)
          .map((c) => (c as Map)['id']),
      isNot(contains('qa00')),
    );
    expect(
      (await target.social.search('qa_dana'))['users'] as List,
      isEmpty,
    );
    await expectLater(
      target.social.profile('qa07'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
    );
    await blocker.social.act('qa00', 'unblock');
    expect(
      ((await target.social.suggestions())['campus'] as List)
          .map((c) => (c as Map)['id']),
      contains('qa07'),
    );
    target.server.reset();
    blocker.server.reset();
    expect(target.server.isEmpty, isTrue);
  });

  test('activity pages twenty then rest with years and no voter identity', () async {
    final f = mount('qa00');
    final first = await f.activity.page();
    final items = (first['items'] as List).cast<Map<String, dynamic>>();
    expect(items.length, 20);
    expect(first['nextCursor'], '20');
    for (final item in items) {
      expect(item['graduationYear'], isA<int>());
      expect(item['question'], isNotEmpty);
      expect(item['occurredAt'], isNotEmpty);
      expect(item['chosenName'], isNotEmpty);
    }
    expect(jsonEncode(first).toLowerCase(), isNot(contains('voter')));
    final second = await f.activity.page(cursor: first['nextCursor'] as String);
    expect((second['items'] as List).length, 5);
    expect(second['nextCursor'], isNull);
    final names = [
      ...items,
      ...(second['items'] as List).cast<Map<String, dynamic>>(),
    ].map((i) => i['chosenName'] as String);
    expect(names.where((n) => n == 'Aman Iskakov').length, 6);
    f.server.reset();
    expect(f.server.isEmpty, isTrue);
  });

  test('cross-campus requests are rejected and the outsider stays hidden', () async {
    final f = mount('qa00');
    await expectLater(
      f.social.act('qa99', 'request'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
    );
    expect((await f.social.search('outsider'))['users'] as List, isEmpty);
    final o = mount('qa99');
    await expectLater(
      o.social.act('qa00', 'request'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
    );
    f.server.reset();
    o.server.reset();
    expect(f.server.isEmpty, isTrue);
  });

  test('account switch mid-scenario cannot leak the other account', () async {
    final f = mount('qa00');
    expect(((await f.social.list('requests'))['users'] as List).length, 6);
    final release = Completer<void>();
    f.server.entered = Completer<void>();
    f.server.hold = release.future;
    final pending = f.social.list('requests');
    final assertion = expectLater(
      pending,
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
    );
    await f.server.entered!.future;
    f.storage.token = 'token-qa01';
    release.complete();
    await assertion;
    // A fresh client bound to the new account sees only its own data.
    final g = mount('qa01');
    expect(((await g.social.list('requests'))['users'] as List), isEmpty);
    f.server.reset();
    g.server.reset();
    expect(f.server.isEmpty, isTrue);
  });
}
