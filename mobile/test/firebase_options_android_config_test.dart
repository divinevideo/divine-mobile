// ABOUTME: Pins Dart Android Firebase options to the tracked native config.
// ABOUTME: Prevents google-services.json and firebase_options.dart drift.

import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/firebase_options.dart';

void main() {
  group(DefaultFirebaseOptions, () {
    test('Android Firebase options match each registered app', () {
      final config = jsonDecode(
        File('android/app/google-services.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final projectInfo = config['project_info'] as Map<String, dynamic>;
      final clients = config['client'] as List<dynamic>;

      void expectOptionsMatch(
        String packageName,
        FirebaseOptions options,
      ) {
        final client = clients.cast<Map<String, dynamic>>().singleWhere((
          client,
        ) {
          final clientInfo = client['client_info'] as Map<String, dynamic>;
          final androidInfo =
              clientInfo['android_client_info'] as Map<String, dynamic>;
          return androidInfo['package_name'] == packageName;
        });
        final clientInfo = client['client_info'] as Map<String, dynamic>;
        final apiKeys = client['api_key'] as List<dynamic>;
        final apiKey = apiKeys.single as Map<String, dynamic>;

        expect(options.apiKey, apiKey['current_key']);
        expect(options.appId, clientInfo['mobilesdk_app_id']);
        expect(options.messagingSenderId, projectInfo['project_number']);
        expect(options.projectId, projectInfo['project_id']);
        expect(options.storageBucket, projectInfo['storage_bucket']);
      }

      expectOptionsMatch('co.openvine.app', DefaultFirebaseOptions.android);
      expectOptionsMatch(
        'co.openvine.app.staging',
        DefaultFirebaseOptions.androidStaging,
      );
    });
  });
}
