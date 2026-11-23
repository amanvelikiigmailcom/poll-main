import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'invite_code_store.dart';
import 'local_game_service.dart';
import 'storage_service.dart';

class InvitationService extends ChangeNotifier {
  InvitationService(this.api, this.storage);
  final ApiService api;
  final StorageService storage;
  int? balance;
  int earned = 0;
  int used = 0;
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
      final game = LocalGameService.instance;
      final key = await game.cooldownKey();
      if (key != null && await game.secondsUntilNextRound() > 0) {
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
      data: {
        'firstName': names.$1,
        'lastName': names.$2,
        if (await game.getUsername() case final String username)
          'username': username,
      },
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
    return false;
  }

  Future<Map<String, dynamic>> create({String? phone}) async {
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
        .convert(utf8.encode('${storage.getPhone()}|${phone ?? ''}'))
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
      data: {'requestId': id, if (phone != null) 'phone': phone},
    )).data!;
    await prefs.remove(pendingKey);
    _owner = result['ownerUserId'] as String? ?? _owner;
    return result;
  }

  static String message(Map<String, dynamic> invite) =>
      'I just voted in Flyprox. Join me: ${invite['url']}\nYour invitation code: ${invite['code']}. '
      'Register with the code and we both get one pass to skip a 60-minute wait.';

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
