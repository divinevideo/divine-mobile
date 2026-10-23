// ABOUTME: Verifies the signed-in account's "blur video previews in messages"
// ABOUTME: choice and its played-video memory are that account's alone.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/saved_sounds_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/dm_video_blur_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for the signed-in account, so a test can switch it.
final _signedIn = StateProvider<String?>((_) => null);

void main() {
  final first = 'a' * 64;
  final second = 'b' * 64;

  Future<ProviderContainer> buildContainer({required String? account}) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentAccountIdProvider.overrideWith((ref) => ref.watch(_signedIn)),
      ],
    );
    addTearDown(container.dispose);
    container.read(_signedIn.notifier).state = account;
    return container;
  }

  group('dmVideoBlurPreferenceServiceProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        DmVideoBlurPreferenceService.storageKey(first): true,
      });
    });

    test('is null when no account is signed in', () async {
      final container = await buildContainer(account: null);

      expect(container.read(dmVideoBlurPreferenceServiceProvider), isNull);
    });

    test("reads the signed-in account's own choice", () async {
      final firstContainer = await buildContainer(account: first);
      final secondContainer = await buildContainer(account: second);

      expect(
        firstContainer
            .read(dmVideoBlurPreferenceServiceProvider)!
            .blurVideoPreviews,
        isTrue,
      );
      expect(
        secondContainer
            .read(dmVideoBlurPreferenceServiceProvider)!
            .blurVideoPreviews,
        isFalse,
      );
    });
  });

  group('dmVideoBlurPreviewsEnabledProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('is off when no account is signed in', () async {
      final container = await buildContainer(account: null);

      expect(container.read(dmVideoBlurPreviewsEnabledProvider), isFalse);
    });

    test("follows the signed-in account's choice as it changes", () async {
      final container = await buildContainer(account: first);
      final subscription = container.listen<bool>(
        dmVideoBlurPreviewsEnabledProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      expect(container.read(dmVideoBlurPreviewsEnabledProvider), isFalse);

      await container
          .read(dmVideoBlurPreferenceServiceProvider)!
          .setBlurVideoPreviews(true);

      expect(container.read(dmVideoBlurPreviewsEnabledProvider), isTrue);
    });
  });

  group('dmVideoPreviewMemoryProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('is null when no account is signed in', () async {
      final container = await buildContainer(account: null);

      expect(container.read(dmVideoPreviewMemoryProvider), isNull);
    });

    test('forgets what was played when the account changes', () async {
      final container = await buildContainer(account: first);
      final subscription = container.listen(
        dmVideoPreviewMemoryProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final messageId = 'c' * 64;
      container.read(dmVideoPreviewMemoryProvider)!.markWatched(messageId);
      expect(
        container.read(dmVideoPreviewMemoryProvider)!.isWatched(messageId),
        isTrue,
      );

      container.read(_signedIn.notifier).state = second;

      expect(
        container.read(dmVideoPreviewMemoryProvider)!.isWatched(messageId),
        isFalse,
      );
    });
  });
}
