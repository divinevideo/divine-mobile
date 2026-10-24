// ABOUTME: Verifies the per-account "blur video previews in messages" choice:
// ABOUTME: off by default, kept per account, and announced when it changes.

import 'dart:async';

import 'package:flutter/services.dart';
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
      test('restores the choice when saving throws', () async {
        final refusing = _RefusingPreferences();
        when(() => refusing.getBool(any())).thenReturn(null);
        when(() => refusing.setBool(any(), any())).thenThrow(
          PlatformException(code: 'write_failed'),
        );
        final service = DmVideoBlurPreferenceService(refusing, account: first);
        addTearDown(service.dispose);

        await expectLater(
          service.setBlurVideoPreviews(true),
          throwsA(isA<PlatformException>()),
        );

        expect(service.blurVideoPreviews, isFalse);
      });

      test('an older refused save cannot undo the latest choice', () async {
        final refusing = _RefusingPreferences();
        final oldSave = Completer<bool>();
        when(() => refusing.getBool(any())).thenReturn(null);
        var saves = 0;
        when(() => refusing.setBool(any(), any())).thenAnswer((_) {
          saves++;
          return saves == 1 ? oldSave.future : Future.value(true);
        });
        final service = DmVideoBlurPreferenceService(refusing, account: first);
        addTearDown(service.dispose);
        final oldResult = expectLater(
          service.setBlurVideoPreviews(true),
          throwsA(isA<DmVideoBlurPreferenceSaveException>()),
        );
        await service.setBlurVideoPreviews(false);
        await service.setBlurVideoPreviews(true);

        oldSave.complete(false);
        await oldResult;

        expect(service.blurVideoPreviews, isTrue);
      });

      test(
        'a refused save after an account switch preserves its error',
        () async {
          final refusing = _RefusingPreferences();
          final save = Completer<bool>();
          when(() => refusing.getBool(any())).thenReturn(null);
          when(() => refusing.setBool(any(), any()))
              .thenAnswer((_) => save.future);
          final service = DmVideoBlurPreferenceService(
            refusing,
            account: first,
          );
          final result = expectLater(
            service.setBlurVideoPreviews(true),
            throwsA(isA<DmVideoBlurPreferenceSaveException>()),
          );

          service.dispose();
          save.complete(false);

          await result;
        },
      );

      test('keeps the latest of two quick choices', () async {
        SharedPreferences.setMockInitialValues({
          DmVideoBlurPreferenceService.storageKey(first): true,
        });
        final prefs = await SharedPreferences.getInstance();
        final service = DmVideoBlurPreferenceService(prefs, account: first);

        await Future.wait([
          service.setBlurVideoPreviews(false),
          service.setBlurVideoPreviews(true),
        ]);

        expect(service.blurVideoPreviews, isTrue);
        expect(
          DmVideoBlurPreferenceService(prefs, account: first).blurVideoPreviews,
          isTrue,
        );
      });

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
            throwsA(isA<DmVideoBlurPreferenceSaveException>()),
          );
          expect(service.blurVideoPreviews, isFalse);
        },
      );
    });
  });
}
