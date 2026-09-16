import 'dart:async';

/// Keeps account cleanup exclusive with operations that can commit user data.
/// Nested operations are allowed to finish while logout drains their parent.
class SessionCoordinator {
  static final instance = SessionCoordinator();
  final Object _zoneKey = Object();
  int _active = 0;
  bool _closing = false;
  Completer<void>? _idle;
  bool get isClosing => _closing;

  Future<T> run<T>(Future<T> Function() action) async {
    final nested = Zone.current[_zoneKey] == this;
    if (_closing && !nested) throw StateError('Session is closing');
    _active++;
    try {
      return await runZoned(action, zoneValues: {_zoneKey: this});
    } finally {
      if (--_active == 0) {
        _idle?.complete();
        _idle = null;
      }
    }
  }

  Future<void> beginClose() async {
    if (_closing) throw StateError('Logout already in progress');
    _closing = true;
    if (_active > 0) {
      _idle ??= Completer<void>();
      await _idle!.future;
    }
  }

  void reopen() => _closing = false;
}
