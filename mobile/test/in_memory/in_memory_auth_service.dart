// ABOUTME: In-memory implementation of AuthService for testing
// ABOUTME: Provides authentication without persistent storage

import 'dart:async';

import '../builders/auth_state_builder.dart';

class InMemoryAuthService {
  AuthData _currentState = const AuthData(isAuthenticated: false);
  final StreamController<AuthData> _authController =
      StreamController<AuthData>.broadcast();

  Stream<AuthData> get authStateStream => _authController.stream;
  AuthData get currentState => _currentState;

  Future<void> login(String privateKey) async {
    _currentState = AuthData(
      isAuthenticated: true,
      privateKey: privateKey,
      lastAuthenticated: DateTime.now(),
    );
    _authController.add(_currentState);
  }

  Future<void> logout() async {
    _currentState = const AuthData(isAuthenticated: false);
    _authController.add(_currentState);
  }

  void dispose() {
    _authController.close();
  }
}
