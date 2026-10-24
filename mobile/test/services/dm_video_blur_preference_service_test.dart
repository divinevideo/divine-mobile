// ABOUTME: Verifies the per-account "blur video previews in messages" choice:
// ABOUTME: off by default, kept per account, and announced when it changes.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/dm_video_blur_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _RefusingPreferences extends Mock implements SharedPreferences {}

/// A platform store that refuses every write, as a full disk does.
class _RefusingStore extends InMemorySharedPreferencesStore {
  _RefusingStore() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;
}

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
      test('two refused saves restore the last saved choice', () async {
        final refusing = _RefusingPreferences();
        final firstSave = Completer<bool>();
        final secondSave = Completer<bool>();
        when(() => refusing.getBool(any())).thenReturn(null);
        var saves = 0;
        when(() => refusing.setBool(any(), any())).thenAnswer((_) {
          saves++;
          return saves == 1 ? firstSave.future : secondSave.future;
        });
        final service = DmVideoBlurPreferenceService(refusing, account: first);
        addTearDown(service.dispose);
        final firstResult = expectLater(
          service.setBlurVideoPreviews(true),
          throwsA(isA<DmVideoBlurPreferenceSaveException>()),
        );
        final secondResult = expectLater(
          service.setBlurVideoPreviews(false),
          throwsA(isA<DmVideoBlurPreferenceSaveException>()),
        );

        firstSave.complete(false);
        await firstResult;
        secondSave.complete(false);
        await secondResult;

        expect(service.blurVideoPreviews, isFalse);
      });

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

      test('a refused save preserves an earlier successful choice', () async {
        final refusing = _RefusingPreferences();
        when(() => refusing.getBool(any())).thenReturn(null);
        when(() => refusing.setBool(any(), true)).thenAnswer((_) async => true);
        when(() => refusing.setBool(any(), false))
            .thenAnswer((_) async => false);
        final service = DmVideoBlurPreferenceService(refusing, account: first);
        addTearDown(service.dispose);
        await service.setBlurVideoPreviews(true);

        await expectLater(
          service.setBlurVideoPreviews(false),
          throwsA(isA<DmVideoBlurPreferenceSaveException>()),
        );

        expect(service.blurVideoPreviews, isTrue);
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

      group('when the platform refuses every save', () {
        late SharedPreferences refusingPrefs;

        setUp(() async {
          final originalStore = SharedPreferencesStorePlatform.instance;
          addTearDown(() {
            SharedPreferencesStorePlatform.instance = originalStore;
            SharedPreferences.resetStatic();
          });
          SharedPreferences.setMockInitialValues({});
          SharedPreferencesStorePlatform.instance = _RefusingStore();
          refusingPrefs = await SharedPreferences.getInstance();
        });

        test('a service built afterwards reads the stored choice', () async {
          final service = DmVideoBlurPreferenceService(
            refusingPrefs,
            account: first,
          );
          addTearDown(service.dispose);

          await expectLater(
            service.setBlurVideoPreviews(true),
            throwsA(isA<DmVideoBlurPreferenceSaveException>()),
          );

          expect(
            DmVideoBlurPreferenceService(
              refusingPrefs,
              account: first,
            ).blurVideoPreviews,
            isFalse,
          );
        });

        test('a save refused after an account switch leaves no trace for '
            'the next service', () async {
          final service = DmVideoBlurPreferenceService(
            refusingPrefs,
            account: first,
          );
          final result = expectLater(
            service.setBlurVideoPreviews(true),
            throwsA(isA<DmVideoBlurPreferenceSaveException>()),
          );

          service.dispose();
          await result;

          expect(
            DmVideoBlurPreferenceService(
              refusingPrefs,
              account: first,
            ).blurVideoPreviews,
            isFalse,
          );
        });
      });

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
