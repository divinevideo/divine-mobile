// ABOUTME: Startup orchestration for the App Store screenshot pipeline.
// ABOUTME: Seeds a throwaway account, creator follows, and editor clips.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' as model show AspectRatio, CuratedList;
import 'package:nostr_sdk/nostr_sdk.dart' show generatePrivateKey;
import 'package:openvine/config/screenshot_mode.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/classic_vines_provider.dart'
    show ClassicViner;
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Publishes a follow for a single hex pubkey.
typedef ScreenshotFollowAction = Future<void> Function(String pubkeyHex);

/// Warms creator profiles (kind-0) so their avatars have URLs to load.
typedef ScreenshotProfileWarmer = Future<void> Function(List<String> pubkeys);

/// Generates a throwaway Nostr private key (hex).
typedef ScreenshotKeyGenerator = String Function();

/// Prepares deterministic app state for the App Store screenshot pipeline.
///
/// Only ever constructed when [ScreenshotMode.enabled] is true, which is
/// itself compile-time false outside debug builds. Every step is
/// best-effort: a failure is logged and the remaining steps still run, so
/// a flaky network never blocks the capture run outright.
class ScreenshotModeService {
  ScreenshotModeService({
    required AuthService authService,
    required ScreenshotFollowAction follow,
    ScreenshotProfileWarmer? warmProfiles,
    ScreenshotKeyGenerator generatePrivateKeyHex = generatePrivateKey,
  }) : _authService = authService,
       _follow = follow,
       _warmProfiles = warmProfiles,
       _generatePrivateKeyHex = generatePrivateKeyHex;

  final AuthService _authService;
  final ScreenshotFollowAction _follow;
  final ScreenshotProfileWarmer? _warmProfiles;
  final ScreenshotKeyGenerator _generatePrivateKeyHex;

  /// Divine creators the throwaway account follows (and whose profiles are
  /// warmed) so the share sheet's "Share with" row, the home feed, and the
  /// captured profile/verification/share screens all have real content and
  /// loaded avatars. Includes the creators featured on individual screens
  /// (Lele Pons, andrinG, Travis & Sallie Mae) plus top classic Viners from
  /// the funnelcake popular-classics feed.
  static const List<String> creatorPubkeysHex = [
    '6e0f5188eac64e8e00166c1b285bfc27af8ddd873c540942d656405c46dd5ed8',
    '3d8a667b6defd4906700a55f64fb26b004f8681fde6d8f2f7501903bac0d4a58',
    '352198449c5ff6e7e74a66a55d17ba4fc4a0a018a2d756ee589b655d823f6c27',
    '1482f9cbf1f2918c961329ea4f6ef1aac7151b0c758f0555b3255d30d62d4e9d',
    '86c5313d94c26f149734606922df4b14eadf863904cc6d054ee48757a5731500',
    '9e00b0acaee85a26b5581153b38a0fd92cbd5c1bbd1c6300c34e4686735e34ac',
    'e41ede9c1de373f4e2282deada8b57a7dc9672ad9ac1470f24db9ba83413e1ec',
    '2338dd3cf958723782f85c22fddd863ef3ae49ea5277c076450281f5e66f4b4e',
    'b4fb4f14f51cc40f4cc4d2fc1d39482bd74ce5180131c48730e808009c963e0f',
    '4094997591f4b48432902be6e1fd4e633ba6874dc3bea1293c74be64e82ffa04',
  ];

  /// Runs all screenshot-state preparation steps.
  ///
  /// Editor fixture clips are seeded separately (before `runApp`, see
  /// `main.dart`) because the editor reads the clip manager exactly once
  /// on mount — seeding here would race that read.
  Future<void> prepare() async {
    await _ensureAuthenticated();
    await _followCreators();
    if (_warmProfiles != null) {
      await _runStep(
        'warm creator profiles',
        () => _warmProfiles(creatorPubkeysHex),
      );
    }
  }

  Future<void> _ensureAuthenticated() async {
    if (_authService.isAuthenticated) {
      Log.info(
        'Screenshot mode: reusing persisted throwaway account',
        name: 'ScreenshotModeService',
        category: LogCategory.auth,
      );
      return;
    }
    await _runStep('create throwaway account', () async {
      await _authService.createAnonymousAccountFromPrivateKeyHex(
        _generatePrivateKeyHex(),
      );
    });
  }

  Future<void> _followCreators() async {
    if (!_authService.isAuthenticated) return;
    for (final pubkey in creatorPubkeysHex) {
      await _runStep('follow $pubkey', () => _follow(pubkey));
    }
  }

  Future<void> _runStep(String label, Future<void> Function() step) async {
    try {
      await step();
    } catch (e, stackTrace) {
      Log.error(
        'Screenshot mode step failed ($label): $e',
        name: 'ScreenshotModeService',
        category: LogCategory.system,
        stackTrace: stackTrace,
      );
    }
  }
}

/// Wires a [ScreenshotModeService] against the app's live providers.
ScreenshotModeService buildScreenshotModeService(ProviderContainer container) {
  return ScreenshotModeService(
    authService: container.read(authServiceProvider),
    follow: (pubkeyHex) async {
      final followRepository = container.read(followRepositoryProvider);
      if (followRepository.followingPubkeys.contains(pubkeyHex)) return;
      await followRepository.follow(pubkeyHex);
    },
    warmProfiles: (pubkeys) async {
      final profileRepository = container.read(profileRepositoryProvider);
      if (profileRepository == null) return;
      await profileRepository.fetchBatchProfiles(pubkeys: pubkeys);
    },
  );
}

/// Curated OG-Viner row for the `01_classics` capture.
///
/// The live top-viners row mixes in creators whose profile has no picture
/// (e.g. Lele), which render as placeholder circles. Screenshot mode instead
/// leads with returning Vine OGs who all have avatars — Reggie Couz first —
/// so the marketing shot has zero placeholder avatars in the row.
List<ClassicViner> screenshotOgVinersFixtures() => const [
  ClassicViner(
    pubkey: '29738587f765b2a3fce2f31a52dece47705598cff6f3b0683503a03829c4029d',
    totalLoops: 2600000,
    videoCount: 118,
    authorName: 'Reggie Couz',
    authorAvatar:
        'https://media.divine.video/'
        '41b7c440d9df2fd4e684fe6a0748e6e25b9c4f8cf97751c1e3530b07de952ec9',
  ),
  ClassicViner(
    pubkey: '86c5313d94c26f149734606922df4b14eadf863904cc6d054ee48757a5731500',
    totalLoops: 2100000,
    videoCount: 240,
    authorName: 'Thomas Sanders',
    authorAvatar:
        'https://storage.googleapis.com/divine-vine-archive/avatars/'
        '93/50/935043086076256256.jpg',
  ),
  ClassicViner(
    pubkey: '3d8a667b6defd4906700a55f64fb26b004f8681fde6d8f2f7501903bac0d4a58',
    totalLoops: 1400000,
    videoCount: 96,
    authorName: 'Cptn. Backfire',
    authorAvatar:
        'https://media.divine.video/'
        '9c6c5e0a1d9cbaabf049887f3b62147c2a879857ed03302f3a9c7dba8d3be708',
  ),
  ClassicViner(
    pubkey: '352198449c5ff6e7e74a66a55d17ba4fc4a0a018a2d756ee589b655d823f6c27',
    totalLoops: 900000,
    videoCount: 72,
    authorName: 'imrtravis',
    authorAvatar:
        'https://media.divine.video/'
        '365e3398cda8ffefbb5fd3cabb8077a1f000b4267228d3899f0750b02d473a8f',
  ),
];

/// Clean, on-brand discovered-list fixtures for the `06_lists` capture.
///
/// The live `/discover-lists` feed surfaces real public kind-30005 lists,
/// some with off-brand or misspelled names; screenshot mode seeds these
/// deterministic lists instead so the marketing shot is always clean.
/// `pubkey` is left null so no author by-line can surface an off-brand name.
List<model.CuratedList> screenshotDiscoverListsFixtures() {
  final now = DateTime.utc(2026);
  model.CuratedList list(String id, String name, String desc, int count) =>
      model.CuratedList(
        id: id,
        name: name,
        description: desc,
        videoEventIds: List<String>.generate(count, (i) => '$id-$i'),
        createdAt: now,
        updatedAt: now,
      );
  return [
    list(
      'favorite-classic-vines',
      'Favorite Classic Vines',
      'The loops that started it all',
      152,
    ),
    list('cat-chaos', 'Cat Chaos', 'Certified feline nonsense', 223),
    list('art-lives-here', 'Art Lives Here', 'Animators, painters, makers', 96),
    list('comedy-gold', 'Comedy Gold', 'Loops that never miss', 287),
    list('nature-loops', 'Nature Loops', 'Six seconds of calm', 61),
    list('music-vault', 'Music Vault', 'Beats, covers, originals', 81),
  ];
}

/// Screenshot-mode discovered-list provider override.
///
/// Keeps the `06_lists` capture isolated from live relay refresh/pagination:
/// the screen can read the same provider as production, but stream mutations
/// are no-ops while screenshot mode is active.
class ScreenshotDiscoveredLists extends DiscoveredLists {
  @override
  DiscoveredListsState build() {
    return DiscoveredListsState(lists: screenshotDiscoverListsFixtures());
  }

  @override
  void setLists(List<model.CuratedList> lists) {}

  @override
  void addLists(List<model.CuratedList> newLists) {}

  @override
  void setLoading(bool loading) {}

  @override
  void updateOldestTimestamp(DateTime timestamp) {}

  @override
  void clear() {}
}

/// Hand-curated classic-Vine fixtures used only as editor timeline clips by
/// the App Store screenshot pipeline.
const List<({String video, String thumbnail})> screenshotEditorFixtures = [
  (
    video:
        'assets/seed_media/videos/'
        '606486ed7079b4b2614e9ca3e0f46c1c9a4a39d52c90dd25a9e51d1b7cf96b33.mp4',
    thumbnail:
        'assets/seed_media/thumbnails/'
        '606486ed7079b4b2614e9ca3e0f46c1c9a4a39d52c90dd25a9e51d1b7cf96b33.jpg',
  ),
  (
    video:
        'assets/seed_media/videos/'
        '6c7bf42367895238e3bd20b12e95a171e9a37a41e2b9b18b89f228de38e9f827.mp4',
    thumbnail:
        'assets/seed_media/thumbnails/'
        '6c7bf42367895238e3bd20b12e95a171e9a37a41e2b9b18b89f228de38e9f827.jpg',
  ),
  (
    video:
        'assets/seed_media/videos/'
        '0cfc8ec503ae05856ec43165bebb7d0d2a3759b2900e38f509b8d08154ef6dc2.mp4',
    thumbnail:
        'assets/seed_media/thumbnails/'
        '0cfc8ec503ae05856ec43165bebb7d0d2a3759b2900e38f509b8d08154ef6dc2.jpg',
  ),
];

/// Copies the bundled fixture clips into temp files and adds them to the
/// clip manager so the multi-clip editor opens with a populated timeline.
Future<void> seedScreenshotEditorClips(ProviderContainer container) async {
  final tempDir = await getTemporaryDirectory();
  final clipManager = container.read(clipManagerProvider.notifier);
  for (final fixture in screenshotEditorFixtures) {
    final videoFile = await _materializeAsset(fixture.video, tempDir.path);
    final thumbnailFile = await _materializeAsset(
      fixture.thumbnail,
      tempDir.path,
    );
    clipManager.addClip(
      video: EditorVideo.file(videoFile),
      originalAspectRatio: 1,
      targetAspectRatio: model.AspectRatio.square,
      limitClipDuration: false,
      duration: const Duration(seconds: 2),
      thumbnailPath: thumbnailFile.path,
    );
  }
}

Future<File> _materializeAsset(String assetPath, String targetDir) async {
  final data = await rootBundle.load(assetPath);
  final file = File('$targetDir/screenshot_${assetPath.split('/').last}');
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  if (file.existsSync() && file.lengthSync() == bytes.length) {
    return file;
  }
  final tempFile = File('${file.path}.tmp');
  await tempFile.writeAsBytes(bytes, flush: true);
  if (file.existsSync()) {
    await file.delete();
  }
  await tempFile.rename(file.path);
  return file;
}
