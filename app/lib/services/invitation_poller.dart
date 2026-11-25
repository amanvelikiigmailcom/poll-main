import 'dart:async';

/// At most one request in flight; idle checks back off to once a minute.
/// Only transport scheduling lives here, never invitation/reward authority.
class InvitationPoller {
  InvitationPoller({required this.check, required this.isVisible});

  final Future<void> Function() check;
  final bool Function() isVisible;
  static const _delays = [5, 15, 30, 60];
  Timer? _timer;
  int _step = 1, _generation = 0;
  bool _disposed = false, _running = false;

  void start({bool afterInvitation = false}) {
    if (_disposed) return;
    _generation++;
    _timer?.cancel();
    _step = afterInvitation ? 0 : 1;
    _schedule(_generation);
  }

  void pause() {
    _generation++;
    _timer?.cancel();
    _timer = null;
  }

  void _schedule(int generation) {
    _timer = Timer(Duration(seconds: _delays[_step]), () async {
      if (_disposed || generation != _generation) return;
      if (!_running && isVisible()) {
        _running = true;
        try {
          await check();
        } catch (_) {
          // The screen owns its error state; retries still back off.
        } finally {
          _running = false;
        }
        if (_disposed || generation != _generation) return;
        if (_step < _delays.length - 1) _step++;
      }
      _schedule(generation);
    });
  }

  void dispose() {
    pause();
    _disposed = true;
  }
}
