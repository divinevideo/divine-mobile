// ABOUTME: Firebase configuration options for different platforms
// ABOUTME: Generated placeholder config - replace with real Firebase project config

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'placeholder-api-key',
    appId: '1:placeholder:web:placeholder',
    messagingSenderId: 'placeholder-sender-id',
    projectId: 'openvine-placeholder',
    authDomain: 'openvine-placeholder.firebaseapp.com',
    storageBucket: 'openvine-placeholder.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'placeholder-api-key',
    appId: '1:placeholder:android:placeholder',
    messagingSenderId: 'placeholder-sender-id',
    projectId: 'openvine-placeholder',
    storageBucket: 'openvine-placeholder.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyChiPGndRdZwsMoLqnel2WSocROmoKLdB4',
    appId: '1:972941478875:ios:f61272b3cf485df244b5fe',
    messagingSenderId: '972941478875',
    projectId: 'openvine-co',
    storageBucket: 'openvine-co.firebasestorage.app',
    iosBundleId: 'co.openvine.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyChiPGndRdZwsMoLqnel2WSocROmoKLdB4',
    appId: '1:972941478875:ios:f61272b3cf485df244b5fe',
    messagingSenderId: '972941478875',
    projectId: 'openvine-co',
    storageBucket: 'openvine-co.firebasestorage.app',
    iosBundleId: 'co.openvine.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'placeholder-api-key',
    appId: '1:placeholder:web:placeholder',
    messagingSenderId: 'placeholder-sender-id',
    projectId: 'openvine-placeholder',
    authDomain: 'openvine-placeholder.firebaseapp.com',
    storageBucket: 'openvine-placeholder.appspot.com',
  );
}
