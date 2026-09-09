// ABOUTME: Shared Firebase initialization guard for app and background isolates.
// ABOUTME: Reuses native auto-initialized default apps to avoid duplicate-app errors.

import 'package:firebase_core/firebase_core.dart';
import 'package:openvine/firebase_options.dart';

typedef FirebaseAppsProvider = List<FirebaseApp> Function();
typedef FirebaseInitializer = Future<FirebaseApp> Function({
  FirebaseOptions? options,
});

/// Ensures the default Firebase app exists exactly once.
///
/// Android can auto-create the default app before Dart startup via the
/// google-services plugin. The pre-check covers repeat Dart calls after
/// Firebase core has loaded its app list; the duplicate-app catch covers native
/// auto-init discovered during the first Dart initialize call.
Future<void> ensureDefaultFirebaseInitialized({
  FirebaseOptions? options,
  FirebaseAppsProvider? appsProvider,
  FirebaseInitializer? initializeApp,
}) async {
  if ((appsProvider ?? () => Firebase.apps)().isNotEmpty) return;

  try {
    await (initializeApp ?? Firebase.initializeApp)(
      options: options ?? DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (error) {
    if (error.code == 'duplicate-app') return;
    rethrow;
  }
}
