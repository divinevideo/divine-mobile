// ABOUTME: Verifies local Classics onboarding progress and account isolation.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/classics_warmup.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final viewer = 'a' * 64;
  final otherViewer = 'b' * 64;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('enroll', () {
    test('only a newly enrolled account starts in Classics', () async {
      await ClassicsWarmup.enroll(prefs, viewer);
      expect(ClassicsWarmup.startsInClassics(prefs, viewer), isTrue);
      expect(ClassicsWarmup.startsInClassics(prefs, otherViewer), isFalse);
      expect(ClassicsWarmup.startsInClassics(prefs, null), isFalse);
    });
  });

  group('recordView', () {
    test('graduates after 100 distinct views and releases the IDs', () async {
      await ClassicsWarmup.enroll(prefs, viewer);
      final warmup = ClassicsWarmup(prefs, viewer);
      final otherWarmup = ClassicsWarmup(prefs, otherViewer);
      for (var i = 0; i < 99; i++) {
        final videoId = i.toRadixString(16).padLeft(64, '0');
        await warmup.recordView(videoId);
        await warmup.recordView(videoId);
        await otherWarmup.recordView(videoId);
      }

      await prefs.reload();
      expect(ClassicsWarmup.startsInClassics(prefs, viewer), isTrue);
      expect(ClassicsWarmup.isEnrolled(prefs, otherViewer), isFalse);

      await warmup.recordView('f' * 64);
      await prefs.reload();
      expect(ClassicsWarmup.isEnrolled(prefs, viewer), isTrue);
      expect(ClassicsWarmup.startsInClassics(prefs, viewer), isFalse);
      expect(
        prefs.getStringList(ClassicsWarmup.storageKey(viewer)),
        hasLength(1),
      );

      await ClassicsWarmup.enroll(prefs, viewer);
      await warmup.recordView('c' * 64);
      expect(ClassicsWarmup.startsInClassics(prefs, viewer), isFalse);
    });
  });
}
