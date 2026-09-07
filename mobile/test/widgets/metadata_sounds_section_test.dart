// ABOUTME: Tests for MetadataSoundsSection - audio info in metadata sheet.
// ABOUTME: Tests both shared audio and original sound display modes.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/screens/sound_detail_screen.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_sounds_section.dart';

import '../helpers/test_provider_overrides.dart';

Finder _divineIcon(DivineIconName name) =>
    find.byWidgetPredicate((w) => w is DivineIcon && w.icon == name);

MockAuthService _mockAuth({String? viewerPubkey}) {
  final mockAuth = createMockAuthService();
  when(() => mockAuth.currentPublicKeyHex).thenReturn(viewerPubkey);
  return mockAuth;
}

void main() {
  group(MetadataSoundsSection, () {
    const testAudioEventId =
        'audio0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab';
    const testPubkey =
        'pubkey123456789abcdef0123456789abcdef0123456789abcdef0123456789ab';
    const testVideoId =
        'video0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab';

    late AudioEvent testAudio;

    setUp(() {
      testAudio = AudioEvent(
        id: testAudioEventId,
        pubkey: testPubkey,
        createdAt: 1704067200,
        title: 'Cool Beat',
        duration: 6.2,
        url: 'https://blossom.example/audio.aac',
        mimeType: 'audio/aac',
      );
    });

    VideoEvent createVideoWithAudio() {
      final now = DateTime.now();
      return VideoEvent(
        id: testVideoId,
        pubkey: testPubkey,
        content: 'Test video with audio',
        videoUrl: 'https://example.com/video.mp4',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        title: 'Test Video',
        audioEventId: testAudioEventId,
      );
    }

    VideoEvent createVideoWithoutAudio({
      String? authorName,
      bool? allowAudioReuse,
      bool isVerifiedArchive = false,
      InspiredByInfo? inspiredBy,
    }) {
      final now = DateTime.now();
      return VideoEvent(
        id: testVideoId,
        pubkey: testPubkey,
        content: 'Test video without audio',
        videoUrl: 'https://example.com/video.mp4',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        title: 'Test Video',
        authorName: authorName,
        inspiredByVideo: inspiredBy,
        rawTags: {
          if (allowAudioReuse case final allowed?)
            'allow_audio_reuse': allowed.toString(),
        },
        isVerifiedArchive: isVerifiedArchive,
        archiveAudioReuseEnabled: isVerifiedArchive,
      );
    }

    Widget buildTestWidget({
      required VideoEvent video,
      AudioEvent? audioOverride,
      String? viewerPubkey,
    }) {
      return ProviderScope(
        overrides: [
          soundByIdProvider(testAudioEventId).overrideWith((ref) async {
            return audioOverride ?? testAudio;
          }),
          authServiceProvider.overrideWithValue(
            _mockAuth(viewerPubkey: viewerPubkey),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(
            backgroundColor: Colors.black,
            body: MetadataSoundsSection(video: video),
          ),
        ),
      );
    }

    group('Shared audio', () {
      testWidgets('shows sound title for video with audio reference', (
        tester,
      ) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        expect(find.text('Cool Beat'), findsOneWidget);
      });

      testWidgets('shows public credit and credit-only status', (tester) async {
        final creditedAudio = testAudio.copyWith(
          creatorName: 'Original Artist',
          source: 'https://example.com/original',
          licenseName: 'CC BY 4.0',
          publicTags: const ['loops'],
          allowsReuse: false,
          hasExplicitReuseConsent: true,
        );

        await tester.pumpWidget(
          buildTestWidget(
            video: createVideoWithAudio(),
            audioOverride: creditedAudio,
            viewerPubkey: testPubkey,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('By Original Artist'), findsOneWidget);
        expect(find.textContaining('Shared by'), findsOneWidget);
        expect(find.text('Credit only'), findsOneWidget);
        expect(find.text('CC BY 4.0'), findsOneWidget);
        expect(find.text('https://example.com/original'), findsOneWidget);
        expect(find.text('#loops'), findsOneWidget);
      });

      testWidgets('withholds reuse badge while legacy terms are pending', (
        tester,
      ) async {
        final pendingTerms = Completer<bool>();
        final legacyAudio = testAudio.copyWith(
          allowsReuse: false,
          hasExplicitReuseConsent: false,
          sourceVideoReference: '34236:$testPubkey:source-video',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              soundByIdProvider(testAudioEventId).overrideWith((ref) async {
                return legacyAudio;
              }),
              audioReuseTermsProvider(
                legacyAudio,
              ).overrideWith((ref) => pendingTerms.future),
              authServiceProvider.overrideWithValue(_mockAuth()),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: VineTheme.theme,
              home: Scaffold(
                backgroundColor: Colors.black,
                body: MetadataSoundsSection(video: createVideoWithAudio()),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump();

        expect(find.text('Cool Beat'), findsOneWidget);
        expect(find.text('Credit only'), findsNothing);
        expect(find.text('Remixing allowed'), findsNothing);

        pendingTerms.complete(true);
        await tester.pumpAndSettle();

        expect(find.text('Remixing allowed'), findsOneWidget);
      });

      testWidgets('shows Sounds label', (tester) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        expect(find.text('Sounds'), findsOneWidget);
      });

      testWidgets('shows chevron for tappable shared audio', (tester) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        expect(_divineIcon(DivineIconName.caretRight), findsOneWidget);
      });
    });

    group('Original sound', () {
      testWidgets('shows "Original sound" for video without audio reference', (
        tester,
      ) async {
        final video = createVideoWithoutAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        expect(find.text('Original sound'), findsOneWidget);
      });

      testWidgets('shows Sounds label', (tester) async {
        final video = createVideoWithoutAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        expect(find.text('Sounds'), findsOneWidget);
      });

      testWidgets('shows author name when available', (tester) async {
        final video = createVideoWithoutAudio(authorName: 'Jake Lara');

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        expect(find.text('Jake Lara'), findsOneWidget);
      });

      testWidgets('credits the author when inspired-by is not a reused sound', (
        tester,
      ) async {
        // Inspired-by is a general credit, not a sound reference. With no
        // audio reference the video has its own original sound, so the credit
        // must stay with its author rather than the inspired-by creator.
        const inspiredCreatorPubkey =
            'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
        final video = createVideoWithoutAudio(
          authorName: 'Jake Lara',
          inspiredBy: const InspiredByInfo(
            addressableId: '34236:$inspiredCreatorPubkey:vine-xyz',
          ),
        );

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        expect(find.text('Original sound'), findsOneWidget);
        expect(find.text('Jake Lara'), findsOneWidget);
        expect(
          find.text(UserProfile.defaultDisplayNameFor(inspiredCreatorPubkey)),
          findsNothing,
        );
      });

      testWidgets('falls back to original sound when audio event is null', (
        tester,
      ) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              soundByIdProvider(testAudioEventId).overrideWith((ref) async {
                return null;
              }),
              authServiceProvider.overrideWithValue(_mockAuth()),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: VineTheme.theme,
              home: Scaffold(
                backgroundColor: Colors.black,
                body: MetadataSoundsSection(video: video),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should fall back to original sound
        expect(find.text('Original sound'), findsOneWidget);
      });
    });

    group('Original sound reuse gating', () {
      testWidgets(
        'is display-only (no chevron) when audio reuse is unspecified',
        (tester) async {
          final video = createVideoWithoutAudio();

          await tester.pumpWidget(buildTestWidget(video: video));
          await tester.pumpAndSettle();

          expect(find.text('Original sound'), findsOneWidget);
          expect(_divineIcon(DivineIconName.caretRight), findsNothing);
        },
      );

      testWidgets('does not navigate when a display-only sound is tapped', (
        tester,
      ) async {
        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(
                body: MetadataSoundsSection(video: createVideoWithoutAudio()),
              ),
            ),
            GoRoute(
              path: SoundDetailScreen.path,
              name: SoundDetailScreen.routeName,
              builder: (_, _) => const Scaffold(body: Text('DETAIL')),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [authServiceProvider.overrideWithValue(_mockAuth())],
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: VineTheme.theme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Original sound'));
        await tester.pumpAndSettle();

        expect(find.text('DETAIL'), findsNothing);
        expect(find.text('Original sound'), findsOneWidget);
      });

      testWidgets('shows chevron when the creator enabled audio reuse', (
        tester,
      ) async {
        final video = createVideoWithoutAudio(allowAudioReuse: true);

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        expect(_divineIcon(DivineIconName.caretRight), findsOneWidget);
      });

      testWidgets('shows chevron for an enabled verified archive', (
        tester,
      ) async {
        final video = createVideoWithoutAudio(isVerifiedArchive: true);

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        expect(_divineIcon(DivineIconName.caretRight), findsOneWidget);
      });

      testWidgets('honors an explicit decline on a classic Vine', (
        tester,
      ) async {
        final video = createVideoWithoutAudio(
          allowAudioReuse: false,
          isVerifiedArchive: true,
        );

        await tester.pumpWidget(
          buildTestWidget(video: video, viewerPubkey: testPubkey),
        );
        await tester.pumpAndSettle();

        expect(_divineIcon(DivineIconName.caretRight), findsOneWidget);
      });

      testWidgets(
        'shows chevron for the creator viewing their own unmarked video',
        (tester) async {
          final video = createVideoWithoutAudio();

          await tester.pumpWidget(
            buildTestWidget(video: video, viewerPubkey: testPubkey),
          );
          await tester.pumpAndSettle();

          expect(_divineIcon(DivineIconName.caretRight), findsOneWidget);
        },
      );

      testWidgets('shows chevron for the creator despite a malformed marker', (
        tester,
      ) async {
        final video = createVideoWithoutAudio().copyWith(
          rawTags: const {'allow_audio_reuse': 'TRUE'},
        );

        await tester.pumpWidget(
          buildTestWidget(video: video, viewerPubkey: testPubkey),
        );
        await tester.pumpAndSettle();

        expect(_divineIcon(DivineIconName.caretRight), findsOneWidget);
      });
    });

    group('Reused sound fallback', () {
      const reusedCreatorPubkey =
          'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

      VideoEvent reusedVideo() {
        final now = DateTime.now();
        return VideoEvent(
          id: testVideoId,
          pubkey: testPubkey,
          content: 'Reused audio',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          title: 'Test Video',
          authorName: 'Jake Lara',
          audioEventId: testAudioEventId,
          inspiredByVideo: const InspiredByInfo(
            addressableId: '34236:$reusedCreatorPubkey:vine-xyz',
          ),
        );
      }

      testWidgets(
        'credits the source creator when the shared audio is unresolved',
        (tester) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                soundByIdProvider(
                  testAudioEventId,
                ).overrideWith((ref) async => null),
              ],
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: VineTheme.theme,
                home: Scaffold(
                  backgroundColor: Colors.black,
                  body: MetadataSoundsSection(video: reusedVideo()),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Original sound'), findsOneWidget);
          expect(
            find.text(UserProfile.defaultDisplayNameFor(reusedCreatorPubkey)),
            findsOneWidget,
          );
          // The reusing user's own author name must not be credited.
          expect(find.text('Jake Lara'), findsNothing);
        },
      );

      testWidgets('is display-only when the reused source cannot be resolved', (
        tester,
      ) async {
        // hasAudioReference + unresolved source: the referenced creator's
        // reuse consent is unconfirmable, so the row credits them but offers
        // no reuse affordance (fail closed).
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              soundByIdProvider(
                testAudioEventId,
              ).overrideWith((ref) async => null),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: VineTheme.theme,
              home: Scaffold(
                backgroundColor: Colors.black,
                body: MetadataSoundsSection(video: reusedVideo()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Original sound'), findsOneWidget);
        expect(_divineIcon(DivineIconName.caretRight), findsNothing);
      });

      testWidgets(
        'tapping a resolved reused sound opens the detail (no dead-end)',
        (tester) async {
          const sourceVideoId =
              'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
          final reusedSynth = AudioEvent(
            id: 'video_$sourceVideoId',
            pubkey: reusedCreatorPubkey,
            createdAt: 1704067200,
            title: 'Original sound - Source Creator',
            source: 'Original Sound',
          );

          final router = GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const Scaffold(body: Text('HOME')),
              ),
              GoRoute(
                path: '/sheet',
                builder: (_, _) => Scaffold(
                  body: MetadataSoundsSection(video: createVideoWithAudio()),
                ),
              ),
              GoRoute(
                path: SoundDetailScreen.path,
                name: SoundDetailScreen.routeName,
                builder: (context, state) {
                  // Mirrors the real sound route: a resolved sound arrives via
                  // `extra`; without it the loader re-fetches and dead-ends.
                  final extra = state.extra;
                  final sound = extra is Map<String, dynamic>
                      ? extra['sound'] as AudioEvent?
                      : null;
                  return Scaffold(
                    body: Text(
                      sound != null ? 'DETAIL ${sound.id}' : 'NOT FOUND',
                    ),
                  );
                },
              ),
            ],
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                soundByIdProvider(
                  testAudioEventId,
                ).overrideWith((ref) async => reusedSynth),
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

          router.push('/sheet');
          await tester.pumpAndSettle();

          expect(find.text('Original sound - Source Creator'), findsOneWidget);

          await tester.tap(find.text('Original sound - Source Creator'));
          await tester.pumpAndSettle();

          expect(find.text('DETAIL video_$sourceVideoId'), findsOneWidget);
          expect(find.text('NOT FOUND'), findsNothing);
        },
      );
    });
  });
}
