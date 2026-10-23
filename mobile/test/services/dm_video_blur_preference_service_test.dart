// ABOUTME: Verifies the per-account "blur video previews in messages" choice:
// ABOUTME: off by default, kept per account, and announced when it changes.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/dm_video_blur_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RefusingPreferences extends Mock implements SharedPreferences {}

void main() {
  group(DmVideoBlurPreferenceService, () {
    final first = 'a' * 64;
    final second = 'b' * 64;

    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    group('blurVideoPreviews', () {
      test('is off for an account that never chose', () {
        expect(
          DmVideoBlurPreferenceService(prefs, account: first).blurVideoPreviews,
          isFalse,
        );
      });

      test('restores each account independently after recreation', () async {
        await DmVideoBlurPreferenceService(
          prefs,
          account: first,
        ).setBlurVideoPreviews(true);

        expect(
          DmVideoBlurPreferenceService(prefs, account: first).blurVideoPreviews,
          isTrue,
        );
        expect(
          DmVideoBlurPreferenceService(
            prefs,
            account: second,
          ).blurVideoPreviews,
          isFalse,
        );
      });
    });

    group('setBlurVideoPreviews', () {
      test('notifies listeners when the choice changes', () async {
        final service = DmVideoBlurPreferenceService(prefs, account: first);
        var notifications = 0;
        service.addListener(() => notifications++);

        await service.setBlurVideoPreviews(true);
        await service.setBlurVideoPreviews(true);

        expect(service.blurVideoPreviews, isTrue);
        expect(notifications, equals(1));
      });

      test(
        'reports a save the platform refused, keeping the old choice',
        () async {
          final refusing = _RefusingPreferences();
          when(() => refusing.getBool(any())).thenReturn(null);
          when(
            () => refusing.setBool(any(), any()),
          ).thenAnswer((_) async => false);
          final service = DmVideoBlurPreferenceService(
            refusing,
            account: first,
          );

          await expectLater(
            service.setBlurVideoPreviews(true),
            throwsStateError,
          );
          expect(service.blurVideoPreviews, isFalse);
        },
      );
    });
  });
}
