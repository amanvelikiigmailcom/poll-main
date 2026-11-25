import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'invite_code_store.dart';
import 'local_game_service.dart';
import 'storage_service.dart';
import 'contact_sync_service.dart';

class InvitationService extends ChangeNotifier with WidgetsBindingObserver {
  InvitationService(this.api, this.storage, {DateTime Function()? now})
    : _now = now ?? DateTime.now {
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_finishWhatsApp);
  }
  final ApiService api;
  final StorageService storage;
  final DateTime Function() _now;
  int? balance;
  int earned = 0;
  int used = 0;
  int policyVersion = 1,
      messagesSent = 0,
      whatsappAttempts = 0,
      whatsappAdvancesToday = 0;
  int whatsappAdvanceLimit = 5;
  String preferredChannel = 'messages';
  bool invitationsEnabled = true;
  String inviteButtonText = 'Invite friends';
  int? dailyRemaining;
  DateTime? dailyResetsAt;
  bool signedIn = false;
  String? error;
  String? _owner;
  String? _checkedToken;
  Future<void>? _refreshing;
  Future<bool>? _claiming;
  String get _registrationOwner => sha256
      .convert(utf8.encode('invite-registration:${storage.getPhone()}'))
      .toString();
  Future<bool> registrationPending() async =>
      (await SharedPreferences.getInstance()).getString(
        'invite_registration_pending_v1',
      ) ==
      _registrationOwner;
  Future<bool> completeRegistration() async {
    await (await SharedPreferences.getInstance()).setString(
      'invite_registration_pending_v1',
      _registrationOwner,
    );
    return claimPending();
  }

  Future<void> _composeQueue = Future.value();
  Future<void> _serializeCompose(Future<void> Function() action) {
    final operation = _composeQueue.then((_) => action());
    _composeQueue = operation.catchError((Object _) {});
    return operation;
  }

  bool _disposed = false;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  static const messages = MethodChannel('flyprox/invitations');

  Future<void> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  Future<void> _refresh() async {
    final token = await storage.getToken();
    if (_checkedToken != token) {
      _checkedToken = token;
      balance = null;
      earned = 0;
      used = 0;
      _owner = null;
      error = null;
      invitationsEnabled = true;
      inviteButtonText = 'Invite friends';
      preferredChannel = 'messages';
      policyVersion = 1;
      messagesSent = whatsappAttempts = whatsappAdvancesToday = 0;
      dailyRemaining = null;
      dailyResetsAt = null;
    }
    signedIn = token != null && token.isNotEmpty;
    if (!signedIn) {
      balance = null;
      earned = 0;
      used = 0;
      _owner = null;
      error = null;
      _emit();
      return;
    }
    try {
      var data = (await api.get<Map<String, dynamic>>(
        '/api/invites/rewards',
      )).data!;
      if (await storage.getToken() != token) return;
      _owner = data['userId'] as String;
      policyVersion = (data['version'] as num?)?.toInt() ?? 1;
      if (policyVersion == 2) {
        final attemptedDelivery = await _flushDelivery();
        if (await storage.getToken() != token) return;
        if (attemptedDelivery) {
          data = (await api.get<Map<String, dynamic>>(
            '/api/invites/rewards',
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          )).data!;
          if (await storage.getToken() != token) return;
        }
      }
      final game = LocalGameService.instance;
      final daily = data['daily'] as Map?;
      dailyRemaining = (daily?['remaining'] as num?)?.toInt();
      dailyResetsAt = DateTime.tryParse(daily?['resetsAt'] as String? ?? '');
      final key = await game.cooldownKey();
      if (dailyRemaining != 0 &&
          key != null &&
          await game.secondsUntilNextRound() > 0) {
        final confirmed = (data['redemptions'] as List? ?? []).any(
          (r) => r['cooldownKey'] == key,
        );
        if (confirmed) {
          await game.bypassTimerFor(key);
        } else if ((data['balance'] as num).toInt() > 0) {
          final id = (data['rewards'] as List).first['id'];
          final result = (await api.post<Map<String, dynamic>>(
            '/api/invites/rewards/$id/redeem',
            data: {'cooldownKey': key},
          )).data!;
          if (await storage.getToken() != token) return;
          if (result['redeemed'] == true && result['cooldownKey'] == key) {
            await game.bypassTimerFor(key);
          }
          data = (await api.get<Map<String, dynamic>>(
            '/api/invites/rewards',
          )).data!;
        }
      }
      if (await storage.getToken() != token) return;
      balance = (data['balance'] as num).toInt();
      earned = (data['earned'] as num).toInt();
      used = (data['used'] as num).toInt();
      messagesSent = (data['messagesSent'] as num?)?.toInt() ?? 0;
      whatsappAttempts = (data['whatsappAttempts'] as num?)?.toInt() ?? 0;
      whatsappAdvancesToday =
          (data['whatsappAdvancesToday'] as num?)?.toInt() ?? 0;
      whatsappAdvanceLimit =
          (data['whatsappAdvanceLimit'] as num?)?.toInt() ?? 5;
      preferredChannel = data['preferredChannel'] as String? ?? 'messages';
      final policy = data['policy'] as Map?;
      invitationsEnabled = policy?['enabled'] != false;
      inviteButtonText =
          policy?['buttonText'] as String? ??
          (preferredChannel == 'whatsapp'
              ? 'Invite via WhatsApp'
              : 'Invite via Messages');
      error = null;
      await _flushCompose();
    } catch (_) {
      // Never display a guessed zero after a failed check.
      error =
          'Couldn’t check invitations. Check your connection and try again.';
    }
    _emit();
  }

  Future<void> syncProfile() async {
    if ((await storage.getToken())?.isNotEmpty != true) return;
    final game = LocalGameService.instance;
    final names = await game.getFullName();
    if (names.$1.isEmpty || names.$2.isEmpty) return;
    await api.patch(
      '/api/users/profile',
      data: {'firstName': names.$1, 'lastName': names.$2},
    );
  }

  Future<bool> claimPending() =>
      _claiming ??= _claimPending().whenComplete(() => _claiming = null);
  Future<bool> _claimPending() async {
    final token = await storage.getToken();
    if (token == null || token.isEmpty) return false;
    final code = await InviteCodeStore.code();
    // A successful response belongs to the session that sent it. Switching
    // accounts must not clear attribution or trigger a redemption for the
    // next account. Require confirmation before reusing its pending code.
    Future<bool> sameAccount() async {
      if (await storage.getToken() == token) return true;
      if (code != null && await InviteCodeStore.code() == code) {
        await InviteCodeStore.requireAttention();
      }
      return false;
    }

    await syncProfile();
    if (!await sameAccount()) return false;
    if (code != null && !await InviteCodeStore.accepted()) return false;
    final source = await InviteCodeStore.source();
    late Map<String, dynamic> data;
    try {
      data = (await api.post<Map<String, dynamic>>(
        '/api/invites/claim',
        data: {if (code != null) 'code': code, 'source': source},
      )).data!;
    } on ApiException catch (e) {
      if (!await sameAccount()) return false;
      if ([400, 403, 404, 409, 410].contains(e.statusCode)) {
        await (await SharedPreferences.getInstance()).remove(
          'invite_registration_pending_v1',
        );
        if (code != null && await InviteCodeStore.code() == code) {
          await InviteCodeStore.requireAttention();
        }
      }
      rethrow;
    }
    if (!await sameAccount()) return false;
    await (await SharedPreferences.getInstance()).remove(
      'invite_registration_pending_v1',
    );
    if (data['claimed'] == true) {
      if (code != null) {
        try {
          await api.post(
            '/api/invites/$code/events',
            data: {
              'type': switch (source) {
                'pasted' => 'code_pasted',
                'link' => 'app_open_with_code',
                _ => 'code_typed',
              },
            },
          );
        } catch (_) {
          /* Attribution is already durable in the claim. */
        }
      }
      if (!await sameAccount()) return false;
      if (await InviteCodeStore.code() == code) await InviteCodeStore.clear();
      await refresh();
      return true;
    }
    if (data['retired'] == true && await sameAccount()) {
      if (await InviteCodeStore.code() == code) await InviteCodeStore.clear();
      // The old attribution step is acknowledged, without granting a round.
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>> create({String? phone}) async {
    if (phone == null) throw const ApiException('Choose one friend first.');
    await syncProfile();
    final prefs = await SharedPreferences.getInstance();
    final token = await storage.getToken();
    if (token == null || token.isEmpty) {
      throw const ApiException('Sign in to invite friends.');
    }
    // Retain the request ID on transport errors so Retry cannot create a
    // second invitation. Never persist the selected raw contact number.
    const pendingKey = 'invite_creation_request_v1';
    final tag = sha256
        .convert(utf8.encode('${storage.getPhone()}|$phone'))
        .toString();
    if (prefs.getString('invite_creation_tag_v1') != tag) {
      await prefs.remove(pendingKey);
    }
    await prefs.setString('invite_creation_tag_v1', tag);
    var id = prefs.getString(pendingKey);
    id ??= List.generate(
      24,
      (_) => Random.secure().nextInt(16).toRadixString(16),
    ).join();
    await prefs.setString(pendingKey, id);
    final result = (await api.post<Map<String, dynamic>>(
      '/api/invites',
      data: {
        'requestId': id,
        'recipientHash': ContactSyncService.hashPhone(phone),
        'policyVersion': 2,
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    )).data!;
    if (await storage.getToken() != token) {
      throw const ApiException('Sign-in changed. Try again.');
    }
    if (result['version'] != 2) {
      throw const ApiException('Invitation upgrade is not available yet.');
    }
    await prefs.remove(pendingKey);
    _owner = result['ownerUserId'] as String? ?? _owner;
    return result;
  }

  static String message(Map<String, dynamic> invite) {
    final policy = invite['policy'] as Map?;
    final template =
        policy?['message'] as String? ??
        'I just played Flyprox. Join me: {url}\nInvitation code: {code}';
    return template
        .replaceAll('{url}', '${invite['url']}')
        .replaceAll('{code}', '${invite['code']}');
  }

  Map<String, dynamic>? _whatsapp;
  bool _finishingWhatsApp = false;
  static const _deliveryKey = 'invite_delivery_queue_v2';
  static const _whatsappKey = 'invite_whatsapp_pending_v2';
  String _newId() => List.generate(
    24,
    (_) => Random.secure().nextInt(16).toRadixString(16),
  ).join();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _whatsapp != null) {
      _whatsapp!['backgroundAt'] ??= _now().millisecondsSinceEpoch;
      _saveWhatsApp();
    } else if (state == AppLifecycleState.resumed) {
      _finishWhatsApp();
    }
  }

  Future<void> _saveWhatsApp() async {
    final prefs = await SharedPreferences.getInstance();
    if (_whatsapp == null) {
      await prefs.remove(_whatsappKey);
    } else {
      await prefs.setString(_whatsappKey, jsonEncode(_whatsapp));
    }
  }

  Future<void> processWhatsAppReturn() => _finishWhatsApp();

  Future<void> _finishWhatsApp() async {
    if (_finishingWhatsApp || _disposed) return;
    _finishingWhatsApp = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_whatsappKey);
      _whatsapp ??= saved == null
          ? null
          : Map<String, dynamic>.from(jsonDecode(saved) as Map);
      final pending = _whatsapp;
      if (pending == null ||
          pending['opened'] != true ||
          pending['backgroundAt'] == null) {
        return;
      }
      final token = await storage.getToken();
      if (token == null ||
          sha256.convert(utf8.encode(token)).toString() !=
              pending['sessionKey']) {
        return;
      }
      final elapsed =
          _now().millisecondsSinceEpoch -
          (pending['backgroundAt'] as num).toInt();
      final result = elapsed > 4000 ? 'returned' : 'cancelled';
      await _enqueueDelivery({
        'owner': pending['owner'],
        'code': pending['code'],
        'launchId': pending['launchId'],
        'result': result,
        if (result == 'returned') 'backgroundMs': elapsed,
      });
      // Persist the callback first. Restart/retry cannot lose or double it.
      _whatsapp = null;
      await _saveWhatsApp();
      await refresh();
    } catch (_) {
      // A durable pending result is retried on refresh/resume.
    } finally {
      _finishingWhatsApp = false;
    }
  }

  Future<void> _enqueueDelivery(Map<String, dynamic> result) =>
      _serializeCompose(() async {
        final prefs = await SharedPreferences.getInstance();
        final pending = prefs.getStringList(_deliveryKey) ?? [];
        final exists = pending.any((item) {
          final value = jsonDecode(item) as Map;
          return value['owner'] == result['owner'] &&
              value['launchId'] == result['launchId'];
        });
        if (!exists) pending.add(jsonEncode(result));
        await prefs.setStringList(_deliveryKey, pending);
      });

  Future<bool> _flushDelivery() async {
    var attempted = false;
    await _serializeCompose(() async {
      final owner = _owner;
      final token = await storage.getToken();
      if (owner == null || token == null) return;
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList(_deliveryKey) ?? [];
      final remaining = <String>[];
      for (final item in pending) {
        final data = Map<String, dynamic>.from(jsonDecode(item) as Map);
        if (data['owner'] != owner ||
            await storage.getToken() != token ||
            _owner != owner) {
          remaining.add(item);
          continue;
        }
        try {
          // A lost acknowledgement may still have committed. Re-read rewards
          // after any attempted delivery, not only a successful HTTP response.
          attempted = true;
          await api.post(
            '/api/invites/${data['code']}/delivery-result',
            data: {
              'launchId': data['launchId'],
              'result': data['result'],
              if (data['backgroundMs'] != null)
                'backgroundMs': data['backgroundMs'],
            },
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          );
        } on ApiException catch (e) {
          // Terminal rejection cannot award anything; transport errors stay queued.
          if (![400, 403, 404, 409, 410].contains(e.statusCode)) {
            remaining.add(item);
          }
        } catch (_) {
          remaining.add(item);
        }
      }
      await prefs.setStringList(_deliveryKey, remaining);
    });
    return attempted;
  }

  /// The server selects the country channel and owns all grants and counters.
  Future<String> sendV2(Map<String, dynamic> invite, String phone) async {
    final token = await storage.getToken();
    final owner = invite['ownerUserId'] as String?;
    if (token == null || owner == null || invite['version'] != 2) {
      throw const ApiException('Refresh invitations and try again.');
    }
    if (invite['activated'] == true) {
      throw const ApiException('This friend already activated a round.');
    }
    final launchId = _newId();
    final options = Options(headers: {'Authorization': 'Bearer $token'});
    await api.post(
      '/api/invites/${invite['code']}/launch',
      data: {'launchId': launchId},
      options: options,
    );
    if (await storage.getToken() != token) {
      throw const ApiException('Sign-in changed. Try again.');
    }
    if (invite['channel'] == 'whatsapp') {
      _whatsapp = {
        'owner': owner,
        'code': invite['code'],
        'launchId': launchId,
        'sessionKey': sha256.convert(utf8.encode(token)).toString(),
        'opened': false,
      };
      await _saveWhatsApp();
      final result = await messages.invokeMethod<String>('openWhatsApp', {
        'recipient': phone,
        'body': message(invite),
      });
      if (result == 'opened') {
        if (_whatsapp?['launchId'] == launchId) {
          _whatsapp!['opened'] = true;
          await _saveWhatsApp();
          if (WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed) {
            await _finishWhatsApp();
          }
        }
        return 'opened';
      }
      _whatsapp = null;
      await _saveWhatsApp();
      if (await storage.getToken() != token) {
        throw const ApiException('Sign-in changed. Try again.');
      }
      return _shareFallback(invite, token);
    }
    final result =
        await messages.invokeMethod<String>('compose', {
          'recipient': phone,
          'body': message(invite),
        }) ??
        'failed';
    if (result == 'unavailable') {
      if (await storage.getToken() != token) {
        throw const ApiException('Sign-in changed. Try again.');
      }
      return _shareFallback(invite, token);
    }
    if (['sent', 'cancelled', 'failed'].contains(result)) {
      await _enqueueDelivery({
        'owner': owner,
        'code': invite['code'],
        'launchId': launchId,
        'result': result,
      });
      if (await storage.getToken() == token) await refresh();
    }
    return result;
  }

  Future<String> _shareFallback(
    Map<String, dynamic> invite,
    String token,
  ) async {
    if ((invite['policy'] as Map?)?['fallback'] == 'none') {
      throw const ApiException('Messaging is unavailable on this device.');
    }
    await api.post(
      '/api/invites/${invite['code']}/launch',
      data: {'launchId': _newId(), 'fallback': true},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (await storage.getToken() != token) {
      throw const ApiException('Sign-in changed. Try again.');
    }
    await messages.invokeMethod<String>('share', {'body': message(invite)});
    return 'shared';
  }

  Future<String> compose(
    Map<String, dynamic> invite, {
    String? phone,
    bool reminder = false,
  }) async {
    if (reminder) await api.post('/api/invites/${invite['code']}/remind');
    final result =
        await messages.invokeMethod<String>('compose', {
          'body': message(invite),
          if (phone != null) 'recipient': phone,
        }) ??
        'failed';
    if (['sent', 'cancelled', 'failed'].contains(result)) {
      final prefs = await SharedPreferences.getInstance();
      // Owner is an account ID, never a bearer token. Entries are retried only
      // for the same account; another signed-in account cannot report them.
      if (_owner == null) await refresh();
      if (_owner != null) {
        await _serializeCompose(() async {
          final pending = prefs.getStringList('invite_compose_queue_v1') ?? [];
          pending.add('$_owner|${invite['code']}|$result|$reminder');
          await prefs.setStringList(
            'invite_compose_queue_v1',
            pending.take(100).toList(),
          );
          await _flushComposeNow();
        });
      }
    }
    return result;
  }

  Future<void> _flushCompose() => _serializeCompose(_flushComposeNow);

  Future<void> _flushComposeNow() async {
    if (_owner == null) return;
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList('invite_compose_queue_v1') ?? [];
    final remaining = <String>[];
    for (final item in pending) {
      final parts = item.split('|');
      if (parts.length != 4 || parts.first != _owner) {
        remaining.add(item);
        continue;
      }
      try {
        await api.post(
          '/api/invites/${parts[1]}/compose-result',
          data: {'result': parts[2], 'reminder': parts[3] == 'true'},
        );
      } catch (_) {
        remaining.add(item);
      }
    }
    await prefs.setStringList('invite_compose_queue_v1', remaining);
  }
}
