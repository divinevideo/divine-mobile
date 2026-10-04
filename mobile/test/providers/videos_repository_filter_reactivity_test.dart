// ABOUTME: Regression test for #4755 — verifies that videosRepositoryProvider
// ABOUTME: rebuilds (yielding a fresh cache) when content filter preferences change.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/app_version_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/divine_host_filter_service.dart';
import 'package:openvine/services/feed_aspect_ratio_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockSharedPreferences extends Mock implements SharedPreferences {}

class _MockContentFilterService extends Mock implements ContentFilterService {}

class _MockFeedAspectRatioPreferenceService extends Mock
    implements FeedAspectRatioPreferenceService {}

class _MockDivineHostFilterService extends Mock
    implements DivineHostFilterService {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

/// Toggleable version counter that simulates contentFilterVersionProvider
/// changing when the user changes a filter preference.
final _filterVersionTrigger = StateProvider<int>((ref) => 0);

class _ContentFilterVersionFromTrigger extends ContentFilterVersion {
  @override
  int build() => ref.watch(_filterVersionTrigger);
}

class _DivineHostFilterVersionFromTrigger extends DivineHostFilterVersion {
  _DivineHostFilterVersionFromTrigger(this._trigger);

  final StateProvider<int> _trigger;

  @override
  int build() => ref.watch(_trigger);
}

class _StaticContentFilterVersion extends ContentFilterVersion {
  @override
  int build() => 0;
}

class _StaticDivineHostFilterVersion extends DivineHostFilterVersion {
  @override
  int build() => 0;
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeVideoEvent());
  });
  group('videosRepositoryProvider filter reactivity (#4755)', () {
    late _MockSharedPreferences mockPrefs;
    late _MockContentFilterService mockContentFilter;
    late _MockFeedAspectRatioPreferenceService mockAspectRatio;
    late _MockDivineHostFilterService mockDivineHost;
    late _MockNostrClient mockNostrClient;

    setUp(() {
      mockPrefs = _MockSharedPreferences();
      when(() => mockPrefs.getBool(any())).thenReturn(null);
      when(() => mockPrefs.setBool(any(), any())).thenAnswer((_) async => true);
      when(() => mockPrefs.getString(any())).thenReturn(null);
      when(
        () => mockPrefs.setString(any(), any()),
      ).thenAnswer((_) async => true);
      when(() => mockPrefs.getInt(any())).thenReturn(null);
      when(() => mockPrefs.setInt(any(), any())).thenAnswer((_) async => true);
      when(() => mockPrefs.getStringList(any())).thenReturn(null);
      when(
        () => mockPrefs.setStringList(any(), any()),
      ).thenAnswer((_) async => true);
      when(() => mockPrefs.containsKey(any())).thenReturn(false);
      when(() => mockPrefs.remove(any())).thenAnswer((_) async => true);

      mockContentFilter = _MockContentFilterService();
      mockAspectRatio = _MockFeedAspectRatioPreferenceService();
      mockDivineHost = _MockDivineHostFilterService();
      mockNostrClient = _MockNostrClient();

      when(() => mockNostrClient.isInitialized).thenReturn(true);
      when(() => mockNostrClient.hasKeys).thenReturn(false);
      when(() => mockNostrClient.connectedRelayCount).thenReturn(1);
      when(() => mockNostrClient.configuredRelays).thenReturn(<String>[]);

      when(() => mockDivineHost.showDivineHostedOnly).thenReturn(false);
      when(() => mockAspectRatio.shouldHideVideo(any())).thenReturn(false);
    });

    test(
      'rebuilds with fresh instance when contentFilterVersionProvider changes',
      () async {
        final container = ProviderContainer(
          overrides: [
            appVersionProvider.overrideWithValue('test'),
            sharedPreferencesProvider.overrideWithValue(mockPrefs),
            nostrServiceProvider.overrideWithValue(mockNostrClient),
            contentFilterServiceProvider.overrideWithValue(mockContentFilter),
            feedAspectRatioPreferenceServiceProvider.overrideWithValue(
              mockAspectRatio,
            ),
            divineHostFilterServiceProvider.overrideWithValue(mockDivineHost),
            // Override the version providers with a state provider we control.
            contentFilterVersionProvider.overrideWith(
              _ContentFilterVersionFromTrigger.new,
            ),
            divineHostFilterVersionProvider.overrideWith(
              _StaticDivineHostFilterVersion.new,
            ),
          ],
        );
        addTearDown(container.dispose);

        final repo1 = container.read(videosRepositoryProvider);

        // Simulate a content filter preference change by bumping the version.
        container.read(_filterVersionTrigger.notifier).state++;

        // Allow provider rebuild to propagate.
        await container.pump();

        final repo2 = container.read(videosRepositoryProvider);

        expect(
          identical(repo1, repo2),
          isFalse,
          reason:
              'videosRepositoryProvider must yield a new instance '
              '(with fresh InMemoryFeedCache) when content filter version '
              'changes',
        );
      },
    );

    test('rebuilds with fresh instance when divineHostFilterVersionProvider '
        'changes', () async {
      final divineHostTrigger = StateProvider<int>((ref) => 0);

      final container = ProviderContainer(
        overrides: [
          appVersionProvider.overrideWithValue('test'),
          sharedPreferencesProvider.overrideWithValue(mockPrefs),
          nostrServiceProvider.overrideWithValue(mockNostrClient),
          contentFilterServiceProvider.overrideWithValue(mockContentFilter),
          feedAspectRatioPreferenceServiceProvider.overrideWithValue(
            mockAspectRatio,
          ),
          divineHostFilterServiceProvider.overrideWithValue(mockDivineHost),
          contentFilterVersionProvider.overrideWith(
            _StaticContentFilterVersion.new,
          ),
          divineHostFilterVersionProvider.overrideWith(
            () => _DivineHostFilterVersionFromTrigger(divineHostTrigger),
          ),
        ],
      );
      addTearDown(container.dispose);

      final repo1 = container.read(videosRepositoryProvider);

      // Simulate divine host filter toggle.
      container.read(divineHostTrigger.notifier).state++;

      // Allow provider rebuild to propagate.
      await container.pump();

      final repo2 = container.read(videosRepositoryProvider);

      expect(
        identical(repo1, repo2),
        isFalse,
        reason:
            'videosRepositoryProvider must yield a new instance '
            '(with fresh InMemoryFeedCache) when divine host filter version '
            'changes',
      );
    });
  });
}
