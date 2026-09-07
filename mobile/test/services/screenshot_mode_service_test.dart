// ABOUTME: Tests for ScreenshotModeService startup orchestration.
// ABOUTME: Covers throwaway auth, creator follows, and bundled fixtures.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/config/screenshot_mode.dart';
import 'package:openvine/providers/classic_vines_provider.dart'
    show ClassicViner;
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/screenshot_mode_service.dart';
import 'package:yaml/yaml.dart';

class _MockAuthService extends Mock implements AuthService {}

/// Files under [dir] that could legitimately be declared as bundled assets.
///
/// Hidden files are excluded. Finder writes `.DS_Store` into any directory a
/// developer browses — `mobile/.gitignore` carries it for that reason — and
/// nothing hidden is ever a shipped asset, so counting one only produces a
/// local failure telling the developer to declare it in `pubspec.yaml`.
Set<String> bundleCandidatesIn(Directory dir) => dir
    .listSync(recursive: true)
    .whereType<File>()
    .map((file) => file.path.replaceAll(Platform.pathSeparator, '/'))
    .where((path) => !path.split('/').last.startsWith('.'))
    .toSet();

void main() {
  group(ScreenshotModeService, () {
    late _MockAuthService authService;
    late List<String> followed;

    ScreenshotModeService buildService({
      Future<void> Function(String pubkeyHex)? follow,
    }) {
      return ScreenshotModeService(
        authService: authService,
        follow: follow ?? (pubkey) async => followed.add(pubkey),
        generatePrivateKeyHex: () => 'a' * 64,
      );
    }

    setUp(() {
      authService = _MockAuthService();
      followed = [];
      when(
        () => authService.createAnonymousAccountFromPrivateKeyHex(any()),
      ).thenAnswer((_) async {});
    });

    group('prepare', () {
      test('creates a throwaway account when unauthenticated', () async {
        when(() => authService.isAuthenticated).thenReturn(false);

        await buildService().prepare();

        verify(
          () => authService.createAnonymousAccountFromPrivateKeyHex('a' * 64),
        ).called(1);
      });

      test('reuses the persisted account when already authenticated', () async {
        when(() => authService.isAuthenticated).thenReturn(true);

        await buildService().prepare();

        verifyNever(
          () => authService.createAnonymousAccountFromPrivateKeyHex(any()),
        );
      });

      test('follows every creator when authenticated', () async {
        when(() => authService.isAuthenticated).thenReturn(true);

        await buildService().prepare();

        expect(followed, equals(ScreenshotModeService.creatorPubkeysHex));
      });

      test('skips follows when authentication never succeeds', () async {
        when(() => authService.isAuthenticated).thenReturn(false);

        await buildService().prepare();

        expect(followed, isEmpty);
      });

      test('a failing follow does not abort the remaining follows', () async {
        when(() => authService.isAuthenticated).thenReturn(true);

        await buildService(
          follow: (pubkey) async {
            if (pubkey == ScreenshotModeService.creatorPubkeysHex.first) {
              throw Exception('relay unavailable');
            }
            followed.add(pubkey);
          },
        ).prepare();

        expect(
          followed,
          equals(ScreenshotModeService.creatorPubkeysHex.skip(1).toList()),
        );
      });

      test('a failing account creation does not throw', () async {
        when(() => authService.isAuthenticated).thenReturn(false);
        when(
          () => authService.createAnonymousAccountFromPrivateKeyHex(any()),
        ).thenThrow(Exception('keychain unavailable'));

        await expectLater(buildService().prepare(), completes);
      });
    });

    group('fixtures', () {
      Set<String> screenshotMediaAssets() => {
        ScreenshotMode.viewfinderFixture,
        for (final fixture in screenshotEditorFixtures) ...[
          fixture.video,
          fixture.thumbnail,
        ],
      };

      test('OG Viner fixtures have avatars and unique pubkeys', () {
        final fixtures = screenshotOgVinersFixtures();

        expect(fixtures, isNotEmpty);
        expect(
          fixtures,
          everyElement(
            isA<ClassicViner>().having(
              (viner) => viner.authorAvatar,
              'authorAvatar',
              isNotEmpty,
            ),
          ),
        );
        expect(
          fixtures.map((viner) => viner.pubkey).toSet(),
          hasLength(fixtures.length),
        );
      });

      test('discover-list fixtures are deterministic and on-brand', () {
        final fixtures = screenshotDiscoverListsFixtures();

        expect(fixtures, hasLength(6));
        expect(fixtures.map((list) => list.id).toSet(), hasLength(6));
        expect(fixtures.map((list) => list.name), everyElement(isNotEmpty));
        expect(
          fixtures.map((list) => list.videoEventIds),
          everyElement(isNotEmpty),
        );
        expect(fixtures.map((list) => list.pubkey), everyElement(isNull));
        expect(fixtures.map((list) => list.createdAt).toSet(), hasLength(1));
      });

      test('discover-list provider override ignores live mutations', () {
        final container = ProviderContainer(
          overrides: [
            discoveredListsProvider.overrideWith(ScreenshotDiscoveredLists.new),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(discoveredListsProvider.notifier);
        final initial = container.read(discoveredListsProvider);
        expect(initial.lists, isNotEmpty);

        notifier.clear();
        notifier.setLoading(true);
        notifier.addLists([
          initial.lists.first.copyWith(
            id: 'live-relay-list',
            name: 'Live relay list',
            videoEventIds: List<String>.generate(999, (index) => 'live-$index'),
          ),
        ]);

        expect(container.read(discoveredListsProvider), initial);
      });

      group('editor fixtures', () {
        test('hidden files are not treated as bundled assets', () {
          final dir = Directory.systemTemp.createTempSync('seed_media_scan');
          addTearDown(() => dir.deleteSync(recursive: true));
          File('${dir.path}/clip.mp4').writeAsStringSync('clip');
          File('${dir.path}/.DS_Store').writeAsStringSync('finder');

          expect(bundleCandidatesIn(dir), hasLength(1));
          expect(bundleCandidatesIn(dir).single, endsWith('/clip.mp4'));
        });

        test('stays three distinct clip pairs', () {
          expect(screenshotEditorFixtures, hasLength(3));
          expect(
            screenshotEditorFixtures.map((fixture) => fixture.video).toSet(),
            hasLength(3),
          );
          expect(
            screenshotEditorFixtures
                .map((fixture) => fixture.thumbnail)
                .toSet(),
            hasLength(3),
          );
        });

        test('every referenced media asset exists on disk', () {
          for (final asset in screenshotMediaAssets()) {
            expect(
              File(asset).existsSync(),
              isTrue,
              reason: '$asset must exist for screenshot capture runs',
            );
          }
        });

        test('every seed-media file is bundled explicitly', () {
          final pubspec =
              loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
          final flutterAssets =
              (pubspec['flutter'] as YamlMap)['assets'] as YamlList;
          final declaredSeedMedia = flutterAssets
              .cast<String>()
              .where((asset) => asset.startsWith('assets/seed_media/'))
              .toSet();
          final seedMediaOnDisk = bundleCandidatesIn(
            Directory('assets/seed_media'),
          );

          expect(
            declaredSeedMedia,
            equals(seedMediaOnDisk),
            reason:
                'seed media must be declared file-by-file so additions and '
                'removals cannot silently change the app bundle',
          );
        });
      });
    });
  });
}
