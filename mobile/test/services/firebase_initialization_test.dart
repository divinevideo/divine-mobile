// ABOUTME: Regression tests for idempotent Firebase default app initialization.
// ABOUTME: Covers Android native auto-init before Dart startup.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/firebase_initialization.dart';

const _firebaseOptions = FirebaseOptions(
  apiKey: 'test-api-key',
  appId: 'test-app-id',
  messagingSenderId: 'test-sender-id',
  projectId: 'test-project-id',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ensureDefaultFirebaseInitialized', () {
    test('initializes Firebase when no default app exists', () async {
      var initializeAppCalls = 0;

      await ensureDefaultFirebaseInitialized(
        options: _firebaseOptions,
        appsProvider: () => const [],
        initializeApp: ({FirebaseOptions? options}) async {
          initializeAppCalls++;
          expect(options?.projectId, 'test-project-id');
          return _FakeFirebaseApp();
        },
      );

      expect(initializeAppCalls, 1);
    });

    test('swallows duplicate-app from native default app auto-init', () async {
      var initializeAppCalls = 0;

      await ensureDefaultFirebaseInitialized(
        options: _firebaseOptions,
        appsProvider: () => const [],
        initializeApp: ({FirebaseOptions? options}) async {
          initializeAppCalls++;
          throw FirebaseException(
            plugin: 'firebase_core',
            code: 'duplicate-app',
            message: 'A Firebase App named "[DEFAULT]" already exists',
          );
        },
      );

      expect(initializeAppCalls, 1);
    });

    test('rethrows non-duplicate Firebase initialization failures', () async {
      final error = FirebaseException(
        plugin: 'firebase_core',
        code: 'invalid-configuration',
        message: 'Broken Firebase config',
      );

      await expectLater(
        ensureDefaultFirebaseInitialized(
          options: _firebaseOptions,
          appsProvider: () => const [],
          initializeApp: ({FirebaseOptions? options}) async => throw error,
        ),
        throwsA(same(error)),
      );
    });

    test('uses Firebase.apps fast path after core is initialized', () async {
      var initializeAppCalls = 0;

      await ensureDefaultFirebaseInitialized(
        options: _firebaseOptions,
        appsProvider: () => [_FakeFirebaseApp()],
        initializeApp: ({FirebaseOptions? options}) async {
          initializeAppCalls++;
          return _FakeFirebaseApp();
        },
      );

      expect(initializeAppCalls, isZero);
    });
  });
}

class _FakeFirebaseApp implements FirebaseApp {
  @override
  String get name => defaultFirebaseAppName;

  @override
  FirebaseOptions get options => _firebaseOptions;

  @override
  Future<void> delete() async {}

  @override
  bool get isAutomaticDataCollectionEnabled => false;

  @override
  Future<void> setAutomaticDataCollectionEnabled(bool enabled) async {}

  @override
  Future<void> setAutomaticResourceManagementEnabled(bool enabled) async {}

  @override
  T? getService<T extends FirebaseService>() => null;

  @override
  void registerService<T extends FirebaseService>(
    T service, {
    Future<void> Function(T service)? dispose,
  }) {}
}
