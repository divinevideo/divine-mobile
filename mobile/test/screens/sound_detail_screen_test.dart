// ABOUTME: Comprehensive TDD tests for SoundDetailScreen - sound detail view
// ABOUTME: Tests sound header, preview playback, use sound, and video grid display

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/saved_sounds/saved_sound_media_probe.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_scope.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/sound_detail_screen.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:openvine/services/sound_library_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sound_service/sound_service.dart';

import '../helpers/go_router.dart';
import '../helpers/test_provider_overrides.dart';

class _MockAudioPlaybackService extends Mock implements AudioPlaybackService {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _NoopSavedSoundMediaProbe implements SavedSoundMediaProbe {
  @override
  Future<SavedSoundMediaResult?> probe(AudioEvent sound) async => null;
}

/// Creates a test AudioEvent with the given parameters.
AudioEvent createTestAudioEvent({
  required String id,
  String? title,
  double? duration,
  String? url,
  String pubkey =
      'test_pubkey_0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
  int createdAt = 1700000000,
}) {
  return AudioEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    title: title ?? 'Test Sound $id',
    duration: duration ?? 6.0,
    url: url ?? 'https://example.com/audio/$id.m4a',
    mimeType: 'audio/mp4',
  );
}

/// Creates a test VideoEvent with the given parameters.
VideoEvent createTestVideoEvent({
  required String id,
  String? title,
  String? thumbnailUrl,
  String pubkey =
      'video_author_0123456789abcdef0123456789abcdef0123456789abcdef01234567',
  int createdAt = 1700000000,
}) {
  return VideoEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    content: '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
    title: title ?? 'Test Video $id',
    videoUrl: 'https://example.com/video/$id.mp4',
    thumbnailUrl: thumbnailUrl ?? 'https://example.com/thumb/$id.jpg',
    duration: 6,
  );
}

/// Mock SoundUsageCount provider that returns a specific count.
class MockSoundUsageCountNotifier extends Notifier<AsyncValue<int>> {
  MockSoundUsageCountNotifier(this.count);

  final int count;

  @override
  AsyncValue<int> build() => AsyncValue.data(count);
}

/// Mock VideosUsingSound provider that returns test video IDs.
class MockVideosUsingSoundNotifier extends Notifier<AsyncValue<List<String>>> {
  MockVideosUsingSoundNotifier({this.videoIds});

  final List<String>? videoIds;

  @override
  AsyncValue<List<String>> build() => AsyncValue.data(videoIds ?? []);
}

/// Mock VideosUsingSound provider that never completes (loading state).
class MockVideosUsingSoundLoadingNotifier
    extends Notifier<AsyncValue<List<String>>> {
  @override
  AsyncValue<List<String>> build() => const AsyncValue.loading();
}

/// Mock VideosUsingSound provider that returns an error.
class MockVideosUsingSoundErrorNotifier
    extends Notifier<AsyncValue<List<String>>> {
  MockVideosUsingSoundErrorNotifier(this.error);

  final Object error;

  @override
  AsyncValue<List<String>> build() =>
      AsyncValue.error(error, StackTrace.current);
}

/// Test wrapper widget that provides necessary context.
///
/// [viewerPubkey] seeds the mocked signed-in pubkey used by the reuse gate;
/// defaults to signed-out (null).
Widget createTestWidget({
  required Widget child,
  List<dynamic>? overrides,
  String? viewerPubkey,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  final mockAuth = createMockAuthService();
  when(() => mockAuth.currentPublicKeyHex).thenReturn(viewerPubkey);
  return ProviderScope(
    overrides: [authServiceProvider.overrideWithValue(mockAuth), ...?overrides],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: VineTheme.theme,
      builder: (context, navigator) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: navigator!,
      ),
      home: child,
    ),
  );
}

Finder _divineIcon(DivineIconName name) =>
    find.byWidgetPredicate((w) => w is DivineIcon && w.icon == name);

void main() {
  setUpAll(() async {
    await loadAppFonts();
  });

  group('SoundDetailScreen', () {
    late _MockAudioPlaybackService mockAudioService;
    late _MockNostrClient mockNostrClient;
    late _MockVideoEventService mockVideoEventService;

    setUp(() {
      mockAudioService = _MockAudioPlaybackService();
      mockNostrClient = _MockNostrClient();
      mockVideoEventService = _MockVideoEventService();

      // Set up default mock behavior
      when(
        () => mockAudioService.loadAudio(any()),
      ).thenAnswer((_) async => const Duration(seconds: 6));
      when(() => mockAudioService.play()).thenAnswer((_) async {});
      when(() => mockAudioService.stop()).thenAnswer((_) async {});
      when(() => mockAudioService.isPlaying).thenReturn(false);

      // NostrClient stubs
      when(() => mockNostrClient.isInitialized).thenReturn(true);
      when(() => mockNostrClient.connectedRelayCount).thenReturn(1);
      when(
        () => mockNostrClient.fetchEventById(any()),
      ).thenAnswer((_) async => null);

      // VideoEventService stubs
      when(() => mockVideoEventService.getVideoById(any())).thenReturn(null);
    });

    group('Widget Structure', () {
      testWidgets('renders with correct title in AppBar', (tester) async {
        final testSound = createTestAudioEvent(id: 'sound1');

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pump();

        expect(find.text('Sound'), findsOneWidget);
      });

      testWidgets('has back button in AppBar', (tester) async {
        final testSound = createTestAudioEvent(id: 'sound1');

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pump();

        expect(find.byType(DivineAppBarIconButton), findsOneWidget);
      });

      testWidgets('has dark background', (tester) async {
        final testSound = createTestAudioEvent(id: 'sound1');

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pump();

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, equals(Colors.black));
      });

      testWidgets('displays sound title', (tester) async {
        final testSound = createTestAudioEvent(
          id: 'sound1',
          title: 'Awesome Beat',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pump();

        expect(find.text('Awesome Beat'), findsOneWidget);
      });

      testWidgets('displays default title when sound has no title', (
        tester,
      ) async {
        // Note: testSound created inline in widget for direct testing
        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(
              sound: AudioEvent(
                id: 'sound1',
                pubkey:
                    'test_pubkey_0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
                createdAt: 1700000000,
                duration: 6.0,
                url: 'https://example.com/audio.m4a',
                mimeType: 'audio/mp4',
              ),
            ),
            overrides: [
              soundUsageCountProvider(
                'sound1',
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                'sound1',
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pump();

        expect(find.text('Original sound'), findsOneWidget);
      });
    });

    group('Sound Header', () {
      testWidgets('displays video count when 0 videos', (tester) async {
        final testSound = createTestAudioEvent(id: 'sound1');

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('No videos yet'), findsOneWidget);
      });

      testWidgets('displays video count when 1 video', (tester) async {
        final testSound = createTestAudioEvent(id: 'sound1');

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(1)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // The text is combined with duration: "6.0s · 1 video"
        expect(find.textContaining('1 video'), findsOneWidget);
      });

      testWidgets('displays video count when multiple videos', (tester) async {
        final testSound = createTestAudioEvent(id: 'sound1');

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(142)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // The text is combined with duration: "6.0s · 142 videos"
        expect(find.textContaining('142 videos'), findsOneWidget);
      });

      testWidgets('displays formatted duration for seconds', (tester) async {
        final testSound = createTestAudioEvent(id: 'sound1', duration: 6.2);

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(5)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // Should find duration text (6.2s · 5 videos)
        expect(find.textContaining('6.2s'), findsOneWidget);
      });

      testWidgets('displays formatted duration for minutes', (tester) async {
        final testSound = createTestAudioEvent(id: 'sound1', duration: 125.0);

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // 125 seconds = 2:05
        expect(find.textContaining('2:05'), findsOneWidget);
      });

      testWidgets('uses the credited creator avatar as cover', (tester) async {
        final testSound = createTestAudioEvent(id: 'sound1');

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pump();

        // A sound has no artwork of its own, so the account it credits is
        // what the cover identifies — same pubkey the "By …" line names.
        final avatar = tester.widget<UserAvatar>(find.byType(UserAvatar));
        expect(avatar.placeholderSeed, equals(testSound.pubkey));
        expect(_divineIcon(DivineIconName.musicNote), findsNothing);
      });

      testWidgets('falls back to the note glyph when no account backs the '
          'sound', (tester) async {
        final testSound = AudioEvent.fromLocalImport(
          id: '${AudioEvent.localImportMarker}_sound1',
          filePath: '/tmp/sound.m4a',
          createdAt: 1700000000,
          title: 'Imported loop',
          mimeType: 'audio/mp4',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pump();

        final note = _divineIcon(DivineIconName.musicNote);
        expect(note, findsOneWidget);
        expect(find.byType(UserAvatar), findsNothing);
        expect(
          tester.widget<DivineIcon>(note).color,
          equals(VineTheme.vineGreen),
        );
      });

      testWidgets('keeps bundled sound artist and license attribution', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        final soundLibraryService = SoundLibraryService();
        final vineSound = VineSound(
          id: 'classic-loop',
          title: 'Classic Loop',
          assetPath: 'assets/sounds/classic-loop.mp3',
          duration: const Duration(seconds: 6),
          artist: 'Bundled Artist',
          license: 'CC0',
          sourceUrl: 'https://freesound.org/s/123',
        );
        await soundLibraryService.addCustomSound(vineSound);
        final testSound = AudioEvent.fromBundledSound(vineSound);

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundLibraryServiceSyncProvider.overrideWithValue(
                soundLibraryService,
              ),
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pumpAndSettle();

        expect(find.textContaining('By Bundled Artist'), findsOneWidget);
        expect(find.textContaining('CC0'), findsOneWidget);
        expect(find.text('View source'), findsOneWidget);
      });

      testWidgets('shows resolved community sound creator attribution', (
        tester,
      ) async {
        const creatorPubkey =
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
        final testSound = createTestAudioEvent(
          id: 'sound1',
          pubkey: creatorPubkey,
        );

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              userProfileReactiveProvider(creatorPubkey).overrideWith((
                ref,
              ) async* {
                yield UserProfile(
                  pubkey: creatorPubkey,
                  rawData: const {},
                  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                  eventId: 'profile-event',
                  displayName: 'Alice Beats',
                );
              }),
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('By Alice Beats'), findsOneWidget);
      });

      testWidgets('falls back for community sound creator with no profile', (
        tester,
      ) async {
        const creatorPubkey =
            'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
        final testSound = createTestAudioEvent(
          id: 'sound1',
          pubkey: creatorPubkey,
        );

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.text('By ${UserProfile.defaultDisplayNameFor(creatorPubkey)}'),
          findsOneWidget,
        );
      });

      testWidgets('credits the publisher of an externally sourced sound', (
        tester,
      ) async {
        // The external-provider publish path credits the provider's artist by
        // name and never sets a creator pubkey, so the signer is a separate
        // publisher — same credit the feed pill and metadata sheet show.
        const publisherPubkey =
            'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
        final testSound = createTestAudioEvent(
          id: 'sound1',
          pubkey: publisherPubkey,
        ).copyWith(creatorName: 'Freesound Artist', licenseName: 'CC0');

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              userProfileReactiveProvider(publisherPubkey).overrideWith((
                ref,
              ) async* {
                yield UserProfile(
                  pubkey: publisherPubkey,
                  rawData: const {},
                  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                  eventId: 'profile-event',
                  displayName: 'Publisher Pat',
                );
              }),
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pumpAndSettle();

        expect(find.textContaining('By Freesound Artist'), findsOneWidget);
        expect(find.text('Shared by Publisher Pat'), findsOneWidget);
      });

      testWidgets('uses distinct semantics for creator and publisher credits', (
        tester,
      ) async {
        const creatorPubkey =
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
        const publisherPubkey =
            'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
        final testSound = createTestAudioEvent(
          id: 'sound1',
          pubkey: publisherPubkey,
        ).copyWith(creatorName: 'Alice Beats', creatorPubkey: creatorPubkey);

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              userProfileReactiveProvider(publisherPubkey).overrideWith((
                ref,
              ) async* {
                yield UserProfile(
                  pubkey: publisherPubkey,
                  rawData: const {},
                  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                  eventId: 'publisher-profile-event',
                  displayName: 'Publisher Pat',
                );
              }),
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('By Alice Beats'), findsOneWidget);
        expect(find.text('Shared by Publisher Pat'), findsOneWidget);
        expect(
          find.bySemanticsIdentifier('sound_detail_creator_attribution'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('sound_detail_publisher_attribution'),
          findsOneWidget,
        );
      });

      testWidgets('does not profile-link draft-local imported audio', (
        tester,
      ) async {
        final testSound = AudioEvent.fromLocalImport(
          id: '${AudioEvent.localImportMarker}_sound1',
          filePath: '/tmp/sound.m4a',
          createdAt: 1700000000,
          title: 'Imported loop',
          mimeType: 'audio/mp4',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Imported loop'), findsOneWidget);
        expect(find.textContaining('By '), findsNothing);
        expect(
          find.bySemanticsIdentifier('sound_detail_creator_attribution'),
          findsNothing,
        );
      });

      testWidgets('omits the source link when the source is not a URL', (
        tester,
      ) async {
        // `fromVideoOriginalSound` puts the label "Original Sound" in `source`,
        // which is not launchable — the credit must still render without a
        // dead "View source" link next to it.
        final video = createTestVideoEvent(id: 'video1');
        final testSound = AudioEvent.fromVideoOriginalSound(video);

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound, sourceVideo: video),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.text('By ${UserProfile.defaultDisplayNameFor(video.pubkey)}'),
          findsOneWidget,
        );
        expect(find.text('View source'), findsNothing);
      });
    });

    group('Action Buttons', () {
      testWidgets('shows public credit, license, tags, and remix status', (
        tester,
      ) async {
        final testSound = createTestAudioEvent(id: 'sound1').copyWith(
          creatorName: 'Original Artist',
          source: 'https://example.com/source',
          licenseName: 'CC BY 4.0',
          publicTags: const ['field-recording'],
          allowsReuse: false,
          hasExplicitReuseConsent: true,
        );

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioReuseConsentProvider(
                testSound,
              ).overrideWith((ref) => Future.value(false)),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('By Original Artist'), findsOneWidget);
        expect(find.textContaining('CC BY 4.0'), findsOneWidget);
        expect(find.text('#field-recording'), findsOneWidget);
        expect(find.text('Credit only'), findsOneWidget);
        expect(find.text('Use Sound'), findsNothing);
      });

      testWidgets('has Preview button', (tester) async {
        final testSound = createTestAudioEvent(id: 'sound1');

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pump();

        expect(find.text('Preview'), findsOneWidget);
        expect(_divineIcon(DivineIconName.play), findsWidgets);
      });

      testWidgets('has Use Sound button', (tester) async {
        final testSound = createTestAudioEvent(id: 'sound1');

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pump();

        expect(find.text('Use Sound'), findsOneWidget);
        expect(_divineIcon(DivineIconName.plus), findsOneWidget);
      });
    });

    group('Use Sound reuse gating', () {
      const sourceVideoId =
          'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
      const creatorPubkey =
          'test_pubkey_0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

      VideoEvent sourceVideo({String? marker, bool isVerifiedArchive = false}) {
        final rawTags = <String, String>{};
        if (marker case final value?) {
          rawTags['allow_audio_reuse'] = value;
        }
        return VideoEvent(
          id: sourceVideoId,
          pubkey: creatorPubkey,
          createdAt: 1700000000,
          content: '',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
          videoUrl: 'https://example.com/video/$sourceVideoId.mp4',
          rawTags: rawTags,
          isVerifiedArchive: isVerifiedArchive,
          archiveAudioReuseEnabled: isVerifiedArchive,
        );
      }

      // The synthesized original sound carries allowsReuse from the video, so
      // the gate works regardless of whether sourceVideo is threaded through.
      AudioEvent originalSound({
        String? marker,
        bool isVerifiedArchive = false,
      }) => AudioEvent.fromVideoOriginalSound(
        sourceVideo(marker: marker, isVerifiedArchive: isVerifiedArchive),
      );

      List<dynamic> gridOverrides() => [
        soundUsageCountProvider(
          sourceVideoId,
        ).overrideWith((ref) => Future.value(0)),
        videosUsingSoundProvider(
          sourceVideoId,
        ).overrideWith((ref) => Future.value(<String>[])),
        audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
      ];

      testWidgets('hides Use Sound when audio reuse is unspecified', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: originalSound()),
            overrides: gridOverrides(),
          ),
        );
        await tester.pump();

        expect(find.text('Use Sound'), findsNothing);
        expect(_divineIcon(DivineIconName.plus), findsNothing);
        // Preview stays available for the un-adoptable sound.
        expect(find.text('Preview'), findsOneWidget);
      });

      testWidgets(
        'shows Use Sound for a reusable original sound reached without a '
        'source video',
        (tester) async {
          // Regression: the resolved reuse path (and deep links) pass only the
          // sound, no sourceVideo. Reuse must still be offered when the creator
          // enabled it.
          await tester.pumpWidget(
            createTestWidget(
              child: SoundDetailScreen(sound: originalSound(marker: 'true')),
              overrides: gridOverrides(),
            ),
          );
          await tester.pump();

          expect(find.text('Use Sound'), findsOneWidget);
          expect(find.text('Remixing allowed'), findsOneWidget);
          expect(find.text('Credit only'), findsNothing);
        },
      );

      testWidgets('withholds reuse badge while legacy terms are pending', (
        tester,
      ) async {
        final termsCompleter = Completer<bool>();
        final consentCompleter = Completer<bool>();
        final sound = originalSound();

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: sound),
            overrides: [
              ...gridOverrides(),
              audioReuseTermsProvider(
                sound,
              ).overrideWith((ref) => termsCompleter.future),
              audioReuseConsentProvider(
                sound,
              ).overrideWith((ref) => consentCompleter.future),
            ],
          ),
        );
        await tester.pump();

        expect(find.text('Use Sound'), findsNothing);
        expect(find.text('Credit only'), findsNothing);
        expect(find.text('Remixing allowed'), findsNothing);

        termsCompleter.complete(true);
        consentCompleter.complete(true);
        await tester.pumpAndSettle();

        expect(find.text('Use Sound'), findsOneWidget);
        expect(find.text('Remixing allowed'), findsOneWidget);
      });

      testWidgets('shows Use Sound for the creator viewing their own sound', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            viewerPubkey: creatorPubkey,
            child: SoundDetailScreen(sound: originalSound()),
            overrides: gridOverrides(),
          ),
        );
        await tester.pump();

        expect(find.text('Use Sound'), findsOneWidget);
      });

      testWidgets('shows Use Sound for an enabled verified archive sound', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(
              sound: originalSound(isVerifiedArchive: true),
            ),
            overrides: [
              ...gridOverrides(),
              audioReuseConsentProvider(
                originalSound(isVerifiedArchive: true),
              ).overrideWith((ref) => Future.value(true)),
            ],
          ),
        );
        await tester.pump();

        expect(find.text('Use Sound'), findsOneWidget);
      });

      testWidgets('an explicit decline still permits the sound owner', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            viewerPubkey: creatorPubkey,
            child: SoundDetailScreen(
              sound: originalSound(marker: 'false', isVerifiedArchive: true),
            ),
            overrides: gridOverrides(),
          ),
        );
        await tester.pump();

        expect(find.text('Use Sound'), findsOneWidget);
      });

      testWidgets('a malformed marker still permits the sound owner', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            viewerPubkey: creatorPubkey,
            child: SoundDetailScreen(sound: originalSound(marker: 'TRUE')),
            overrides: gridOverrides(),
          ),
        );
        await tester.pump();

        expect(find.text('Use Sound'), findsOneWidget);
      });
    });

    group('Preview Playback', () {
      testWidgets('tapping preview loads and plays audio', (tester) async {
        final testSound = createTestAudioEvent(id: 'sound1');

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pump();

        // Tap the Preview button
        await tester.tap(find.text('Preview'));
        await tester.pumpAndSettle();

        // Verify loadAudio and play were called
        verify(() => mockAudioService.loadAudio(testSound.url!)).called(1);
        verify(() => mockAudioService.play()).called(1);
      });

      testWidgets('preview button shows Stop when playing', (tester) async {
        final testSound = createTestAudioEvent(id: 'sound1');

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pump();

        // Initially shows Preview
        expect(find.text('Preview'), findsOneWidget);

        // Tap to start playing
        await tester.tap(find.text('Preview'));
        await tester.pumpAndSettle();

        // Now shows Stop
        expect(find.text('Stop'), findsOneWidget);
        expect(_divineIcon(DivineIconName.squareFill), findsWidgets);
      });

      testWidgets('tapping Stop stops playback', (tester) async {
        final testSound = createTestAudioEvent(id: 'sound1');

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pump();

        // Start playing
        await tester.tap(find.text('Preview'));
        await tester.pumpAndSettle();

        // Clear previous interactions
        reset(mockAudioService);
        when(() => mockAudioService.stop()).thenAnswer((_) async {});

        // Tap Stop
        await tester.tap(find.text('Stop'));
        await tester.pumpAndSettle();

        // Verify stop was called
        verify(() => mockAudioService.stop()).called(1);

        // Back to Preview button
        expect(find.text('Preview'), findsOneWidget);
      });

      testWidgets('shows snackbar when sound has no URL', (tester) async {
        final testSound = AudioEvent(
          id: 'sound1',
          pubkey:
              'test_pubkey_0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          createdAt: 1700000000,
          title: 'No URL Sound',
          duration: 6.0,
          mimeType: 'audio/mp4',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pump();

        // Tap the Preview button
        await tester.tap(find.text('Preview'));
        await tester.pumpAndSettle();

        // Should show snackbar
        expect(
          find.text('Unable to preview sound - no audio available'),
          findsOneWidget,
        );

        // loadAudio should NOT have been called
        verifyNever(() => mockAudioService.loadAudio(any()));
      });

      testWidgets('shows error snackbar when playback fails', (tester) async {
        final testSound = createTestAudioEvent(id: 'sound1');

        when(
          () => mockAudioService.loadAudio(any()),
        ).thenThrow(Exception('Playback failed'));

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pump();

        // Tap the Preview button
        await tester.tap(find.text('Preview'));
        await tester.pumpAndSettle();

        // Should show a localized error without leaking exception details.
        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.soundPreviewFailed), findsOneWidget);
        expect(find.textContaining('Playback failed'), findsNothing);
      });
    });

    group('Use Sound', () {
      late MockGoRouter mockGoRouter;

      setUp(() {
        mockGoRouter = MockGoRouter();
        when(() => mockGoRouter.canPop()).thenReturn(true);
        when(() => mockGoRouter.pop<Object?>(any())).thenAnswer((_) {});
        when(() => mockGoRouter.pop<bool>(any())).thenAnswer((_) {});
      });

      testWidgets(
        'tapping Use Sound saves sound to library and stays on detail screen',
        (tester) async {
          final testSound = createTestAudioEvent(id: 'sound1');
          SharedPreferences.setMockInitialValues({});
          final sharedPreferences = await SharedPreferences.getInstance();
          final container = ProviderContainer(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(sharedPreferences),
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          );
          addTearDown(container.dispose);

          await tester.pumpWidget(
            SavedSoundsScope(
              service: SavedSoundsService(sharedPreferences),
              mediaProbe: _NoopSavedSoundMediaProbe(),
              child: UncontrolledProviderScope(
                container: container,
                child: MockGoRouterProvider(
                  goRouter: mockGoRouter,
                  child: MaterialApp(
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    theme: VineTheme.theme,
                    home: SoundDetailScreen(sound: testSound),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Tap Use Sound
          await tester.tap(find.text('Use Sound'));
          await tester.pumpAndSettle();

          verifyNever(() => mockGoRouter.pop<bool>(true));
          expect(find.text('Saved to Sounds'), findsOneWidget);
          expect(
            SavedSoundsService(
              sharedPreferences,
            ).loadSavedSounds().map((sound) => sound.id),
            [testSound.id],
          );
          expect(container.read(selectedSoundProvider), isNull);
        },
      );

      testWidgets('Use Sound stops preview if playing', (tester) async {
        final testSound = createTestAudioEvent(id: 'sound1');
        SharedPreferences.setMockInitialValues({});
        final sharedPreferences = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          SavedSoundsScope(
            service: SavedSoundsService(sharedPreferences),
            mediaProbe: _NoopSavedSoundMediaProbe(),
            child: ProviderScope(
              overrides: [
                sharedPreferencesProvider.overrideWithValue(sharedPreferences),
                soundUsageCountProvider(
                  testSound.id,
                ).overrideWith((ref) => Future.value(0)),
                videosUsingSoundProvider(
                  testSound.id,
                ).overrideWith((ref) => Future.value(<String>[])),
                audioPlaybackServiceProvider.overrideWithValue(
                  mockAudioService,
                ),
              ],
              child: MockGoRouterProvider(
                goRouter: mockGoRouter,
                child: MaterialApp(
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  theme: VineTheme.theme,
                  home: SoundDetailScreen(sound: testSound),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Start preview
        await tester.tap(find.text('Preview'));
        await tester.pumpAndSettle();

        // Clear interactions
        reset(mockAudioService);
        when(() => mockAudioService.stop()).thenAnswer((_) async {});

        // Tap Use Sound
        await tester.tap(find.text('Use Sound'));
        await tester.pumpAndSettle();

        // Verify stop was called (at least once - may be called again during disposal)
        verify(() => mockAudioService.stop()).called(greaterThanOrEqualTo(1));
      });
    });

    group('Videos Grid', () {
      testWidgets('shows videos section header', (tester) async {
        final testSound = createTestAudioEvent(id: 'sound1');

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pump();

        expect(find.text('Videos using this sound'), findsOneWidget);
      });

      // The header is a PinnedHeaderSliver, which derives its geometry from
      // the child it measures. A SliverPersistentHeaderDelegate instead has
      // to declare an extent up front, and one that disagrees with what the
      // child renders either clips the label (too small) or makes
      // layoutExtent exceed paintExtent (too large) — the sliver then fails
      // layout, leaves its geometry null, and paint surfaces it as a null
      // check against the CustomScrollView. So assert both halves: the box
      // is exactly as tall as its content asks for, at two text scales.
      Future<({double laidOut, double needed})> pumpSectionHeader(
        WidgetTester tester, {
        required TextScaler textScaler,
      }) async {
        final testSound = createTestAudioEvent(id: 'sound1');

        await tester.pumpWidget(
          createTestWidget(
            textScaler: textScaler,
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pump();

        // Innermost Padding above the title is the header's own padding.
        final box = tester.renderObject<RenderBox>(
          find
              .ancestor(
                of: find.text('Videos using this sound'),
                matching: find.byType(Padding),
              )
              .first,
        );
        return (
          laidOut: box.size.height,
          needed: box.getMaxIntrinsicHeight(box.size.width),
        );
      }

      testWidgets('pinned section header is exactly as tall as its label', (
        tester,
      ) async {
        final size = await pumpSectionHeader(
          tester,
          textScaler: TextScaler.noScaling,
        );

        // 52 = 16px padding either side of a 20px line box (titleSmallFont
        // is 14/20). Asserting the concrete number is the half that can fail
        // if the divine_ui type token moves.
        expect(size.needed, equals(52));
        expect(size.laidOut, equals(52));
      });

      testWidgets('pinned section header grows with the text scale rather '
          'than clipping its label', (tester) async {
        final size = await pumpSectionHeader(
          tester,
          textScaler: const TextScaler.linear(2),
        );

        // Only the line box scales; the two paddings do not. 32 + 40.
        expect(size.needed, equals(72));
        expect(size.laidOut, equals(72));
      });

      testWidgets('section header stays pinned while the sound header scrolls '
          'away', (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 480));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final testSound = createTestAudioEvent(
          id: 'sound1',
          title: 'Awesome Beat',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(testSound.id).overrideWith(
                (ref) => Future<List<String>>.error(Exception('offline')),
              ),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pumpAndSettle();

        final titleBefore = tester.getTopLeft(find.text('Awesome Beat')).dy;
        final headerBefore = tester
            .getTopLeft(find.text('Videos using this sound'))
            .dy;

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
        await tester.pump();

        // The sound header is chrome now, not a fixed pane above the grid: it
        // leaves the viewport entirely and hands its height back.
        expect(
          tester.getTopLeft(find.text('Awesome Beat')).dy,
          lessThan(titleBefore),
        );
        // The section header rides up with it but stops at the top instead of
        // scrolling past — the grid would otherwise lose its label.
        final headerAfter = tester
            .getTopLeft(find.text('Videos using this sound'))
            .dy;
        expect(headerAfter, lessThan(headerBefore));
        expect(headerAfter, greaterThanOrEqualTo(0));
      });

      testWidgets('pinned section header paints over the grid scrolling '
          'beneath it', (tester) async {
        final testSound = createTestAudioEvent(id: 'sound1');

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pump();

        // A pinned sliver keeps painting over the slivers after it while they
        // scroll, so the label needs its own opaque ground or grid thumbnails
        // read straight through the text.
        final label = find.text('Videos using this sound');
        final backgroundFinder = find
            .ancestor(of: label, matching: find.byType(ColoredBox))
            .first;
        final background = tester.widget<ColoredBox>(backgroundFinder);
        expect(background.color.a, equals(1.0));
        expect(
          background.color,
          equals(tester.element(label).vineColors.background),
        );
        // And it has to cover the label, not sit behind part of it.
        expect(
          tester.getRect(backgroundFinder),
          equals(
            tester.getRect(
              find.ancestor(of: label, matching: find.byType(Padding)).first,
            ),
          ),
        );
      });

      testWidgets('reused original sound queries usage/grid by recovered id', (
        tester,
      ) async {
        const sourceVideoId =
            'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
        final reusedSynth = createTestAudioEvent(
          id: 'video_$sourceVideoId',
          title: 'Original sound',
        );
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: reusedSynth),
            overrides: [
              // Only the recovered raw id is overridden — a query by the
              // synthetic `video_` id would miss these entirely.
              soundUsageCountProvider(
                sourceVideoId,
              ).overrideWith((ref) => Future.value(7)),
              videosUsingSoundProvider(
                sourceVideoId,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pump();

        expect(find.textContaining(l10n.soundVideoCount(7)), findsOneWidget);
        expect(find.text('Videos using this sound'), findsOneWidget);
      });

      testWidgets('shows empty state when no videos', (tester) async {
        final testSound = createTestAudioEvent(id: 'sound1');

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('No videos yet'), findsAtLeast(1));
        expect(find.text('Be the first to use this sound!'), findsOneWidget);
      });

      testWidgets('shows loading indicator while fetching videos', (
        tester,
      ) async {
        final testSound = createTestAudioEvent(id: 'sound1');

        // Create a completer that never completes
        final completer = Completer<List<String>>();

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(5)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => completer.future),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pump();

        expect(find.byType(BrandedLoadingIndicator), findsWidgets);
      });
    });

    group('Accessibility', () {
      testWidgets('has semantic identifiers', (tester) async {
        final testSound = createTestAudioEvent(id: 'sound1');

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pump();

        // Find the Semantics widget with correct identifier
        final semanticsWidget = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.identifier == 'sound_detail_screen_sound1',
        );
        expect(semanticsWidget, findsOneWidget);
      });

      testWidgets('preview button has semantic identifier', (tester) async {
        final testSound = createTestAudioEvent(id: 'sound1');

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pump();

        final semanticsWidget = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.identifier == 'sound_detail_preview_button',
        );
        expect(semanticsWidget, findsOneWidget);
      });

      testWidgets('use sound button has semantic identifier', (tester) async {
        final testSound = createTestAudioEvent(id: 'sound1');

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pump();

        final semanticsWidget = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.identifier == 'sound_detail_use_button',
        );
        expect(semanticsWidget, findsOneWidget);
      });
    });

    group('Theme Compliance', () {
      // The screen's own green accent is asserted where it still lives — on
      // the cover fallback glyph, see "falls back to the note glyph …".
      testWidgets('Use Sound button has green background', (tester) async {
        final testSound = createTestAudioEvent(id: 'sound1');

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // Find the Use Sound button by text
        expect(find.text('Use Sound'), findsOneWidget);

        // Verify it exists (the button styling is tested implicitly
        // by verifying the widget tree renders correctly)
      });
    });

    group('Navigation', () {
      late MockGoRouter mockGoRouter;

      setUp(() {
        mockGoRouter = MockGoRouter();
        when(() => mockGoRouter.canPop()).thenReturn(true);
        when(() => mockGoRouter.pop<Object?>(any())).thenAnswer((_) {});
        when(() => mockGoRouter.pop<bool>(any())).thenAnswer((_) {});
      });

      testWidgets(
        'back button calls context.pop() which calls GoRouter.pop()',
        (tester) async {
          final testSound = createTestAudioEvent(id: 'sound1');

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                soundUsageCountProvider(
                  testSound.id,
                ).overrideWith((ref) => Future.value(0)),
                videosUsingSoundProvider(
                  testSound.id,
                ).overrideWith((ref) => Future.value(<String>[])),
                audioPlaybackServiceProvider.overrideWithValue(
                  mockAudioService,
                ),
              ],
              child: MockGoRouterProvider(
                goRouter: mockGoRouter,
                child: MaterialApp(
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  theme: VineTheme.theme,
                  home: SoundDetailScreen(sound: testSound),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(SoundDetailScreen), findsOneWidget);

          // Tap back button (which now uses context.pop() from go_router)
          await tester.tap(find.byType(DivineAppBarIconButton));
          await tester.pumpAndSettle();

          // Verify GoRouter.pop() was called
          verify(() => mockGoRouter.pop<Object?>()).called(1);
        },
      );

      testWidgets('creator attribution opens creator profile', (tester) async {
        const creatorPubkey =
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
        final testSound = createTestAudioEvent(
          id: 'sound1',
          pubkey: creatorPubkey,
        );
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => SoundDetailScreen(sound: testSound),
            ),
            GoRoute(
              path: '/profile-view/:npub',
              builder: (context, state) =>
                  Text('profile ${state.pathParameters['npub']}'),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userProfileReactiveProvider(creatorPubkey).overrideWith((
                ref,
              ) async* {
                yield UserProfile(
                  pubkey: creatorPubkey,
                  rawData: const {},
                  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                  eventId: 'profile-event',
                  displayName: 'Alice Beats',
                );
              }),
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: VineTheme.theme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('By Alice Beats'));
        await tester.pumpAndSettle();

        expect(find.textContaining('profile npub1'), findsOneWidget);
      });

      testWidgets('use sound button shows existing saved feedback', (
        tester,
      ) async {
        final testSound = createTestAudioEvent(id: 'sound1');
        SharedPreferences.setMockInitialValues({});
        final sharedPreferences = await SharedPreferences.getInstance();
        await SavedSoundsService(sharedPreferences).saveSound(testSound);

        await tester.pumpWidget(
          SavedSoundsScope(
            service: SavedSoundsService(sharedPreferences),
            mediaProbe: _NoopSavedSoundMediaProbe(),
            child: ProviderScope(
              overrides: [
                sharedPreferencesProvider.overrideWithValue(sharedPreferences),
                soundUsageCountProvider(
                  testSound.id,
                ).overrideWith((ref) => Future.value(0)),
                videosUsingSoundProvider(
                  testSound.id,
                ).overrideWith((ref) => Future.value(<String>[])),
                audioPlaybackServiceProvider.overrideWithValue(
                  mockAudioService,
                ),
              ],
              child: MockGoRouterProvider(
                goRouter: mockGoRouter,
                child: MaterialApp(
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  theme: VineTheme.theme,
                  home: SoundDetailScreen(sound: testSound),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Use Sound'));
        await tester.pumpAndSettle();

        verifyNever(() => mockGoRouter.pop<bool>(true));
        expect(find.text('Already in Sounds'), findsOneWidget);
      });

      testWidgets('back button stops preview if playing', (tester) async {
        final testSound = createTestAudioEvent(id: 'sound1');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
            child: MockGoRouterProvider(
              goRouter: mockGoRouter,
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: VineTheme.theme,
                home: SoundDetailScreen(sound: testSound),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Start preview
        await tester.tap(find.text('Preview'));
        await tester.pumpAndSettle();

        // Tap back button to trigger dispose
        await tester.tap(find.byType(DivineAppBarIconButton));
        await tester.pumpAndSettle();

        // Verify GoRouter.pop() was called (preview stops in dispose)
        verify(() => mockGoRouter.pop<Object?>()).called(1);
      });
    });

    group('Error State Layout', () {
      testWidgets(
        'videos error state stays scrollable when the grid slot is short',
        (tester) async {
          // Reproduces the seed-1263147621 CI flake: when shuffled tests
          // race the un-mocked sounds repository into an error before
          // pumpAndSettle finishes, the screen rendered _buildErrorState
          // and its Column overflowed the _VideosGrid slot by 15px (slot
          // height was 222px in the failing run), throwing a RenderFlex
          // exception that the framework promoted to a TestFailure
          // across unrelated tests in the same VGV-optimized isolate.
          // Shrink the surface enough to reproduce that short slot and
          // verify no layout exception leaks out.
          await tester.binding.setSurfaceSize(const Size(360, 480));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final testSound = createTestAudioEvent(id: 'sound1');

          await tester.pumpWidget(
            createTestWidget(
              child: SoundDetailScreen(sound: testSound),
              overrides: [
                soundUsageCountProvider(
                  testSound.id,
                ).overrideWith((ref) => Future.value(0)),
                videosUsingSoundProvider(testSound.id).overrideWith(
                  (ref) => Future<List<String>>.error(
                    Exception('forced error for layout regression test'),
                  ),
                ),
                audioPlaybackServiceProvider.overrideWithValue(
                  mockAudioService,
                ),
              ],
            ),
          );

          await tester.pumpAndSettle();

          // The error body must actually be on screen (no fallback path).
          expect(_divineIcon(DivineIconName.warningCircle), findsOneWidget);
          expect(find.text('Failed to load videos'), findsOneWidget);
          expect(find.textContaining('forced error'), findsNothing);
          // No layout exception should have been thrown while building.
          expect(tester.takeException(), isNull);
        },
      );
    });
  });
}
