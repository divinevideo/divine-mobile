// ABOUTME: Holds session-scoped recovery context when Keycast already owns a local key
// ABOUTME: Binds the conflict to its originating pubkey and clears it with auth teardown

import 'dart:async';

import 'package:openvine/services/auth_service.dart';

class RegisteredKeyConflict {
  const RegisteredKeyConflict({required this.pubkeyHex, required this.email});

  final String pubkeyHex;
  final String email;
}

class RegisteredKeyConflictStore {
  RegisteredKeyConflictStore(this._authService);

  final AuthService _authService;
  final _controller = StreamController<RegisteredKeyConflict?>.broadcast();
  RegisteredKeyConflict? _conflict;

  RegisteredKeyConflict? get current {
    final conflict = _conflict;
    return conflict?.pubkeyHex == _authService.currentPublicKeyHex
        ? conflict
        : null;
  }

  Stream<RegisteredKeyConflict?> get stream => _controller.stream;

  void record({required String expectedPubkeyHex, required String email}) {
    if (_controller.isClosed) return;
    if (_authService.currentPublicKeyHex != expectedPubkeyHex) return;

    _conflict = RegisteredKeyConflict(
      pubkeyHex: expectedPubkeyHex,
      email: email,
    );
    _controller.add(_conflict);
  }

  void syncAuthState(AuthState state) {
    if (_controller.isClosed) return;
    final conflict = _conflict;
    if (conflict == null) return;
    if (state != AuthState.unauthenticated &&
        conflict.pubkeyHex == _authService.currentPublicKeyHex) {
      return;
    }

    _conflict = null;
    _controller.add(null);
  }

  Future<void> dispose() => _controller.close();
}
