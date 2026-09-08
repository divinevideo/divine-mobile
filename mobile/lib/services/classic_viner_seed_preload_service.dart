import 'dart:convert';
import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:models/models.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:unified_logger/unified_logger.dart';

typedef ClassicVinerAvatarCacheWriter = Future<void> Function({
  required String cacheKey,
  required Uint8List bytes,
  required String fileExtension,
});

class ClassicVinerSeedPreloadService {
  ClassicVinerSeedPreloadService({
    AssetBundle? assetBundle,
    Future<Directory> Function()? markerDirectoryProvider,
  }) : _assetBundle = assetBundle ?? rootBundle,
       _markerDirectoryProvider =
           markerDirectoryProvider ?? getApplicationSupportDirectory;

  static const manifestAssetPath =
      'assets/seed_data/classic_viner_profiles.json';
  static const _profileMarkerPrefix = '.classic_viner_profiles_';
  static const _avatarMarkerPrefix = '.classic_viner_avatars_';

  final AssetBundle _assetBundle;
  final Future<Directory> Function() _markerDirectoryProvider;
  _ClassicVinerSeedManifest? _cachedManifest;

  Future<void> importProfilesIfNeeded({
    required UserProfilesDao userProfilesDao,
    required ProfileStatsDao profileStatsDao,
  }) async {
    if (kIsWeb) return;
    try {
      final manifest = await _loadManifest();
      final markerFile = await _markerFile(
        prefix: _profileMarkerPrefix,
        version: manifest.version,
      );
      if (markerFile.existsSync()) {
        return;
      }

      await userProfilesDao.upsertProfiles(
        manifest.profiles.map((p) => p.toUserProfile()).toList(),
      );

      for (final profileSeed in manifest.profiles) {
        await profileStatsDao.upsertStats(
          pubkey: profileSeed.pubkey,
          videoCount: profileSeed.archivedStats.videoCount,
          totalViews: profileSeed.archivedStats.totalViews,
          totalLikes: profileSeed.archivedStats.totalLikes,
        );
      }

      await _writeMarker(
        markerFile,
        'version=${manifest.version}\nprofiles=${manifest.profiles.length}\n',
      );
    } catch (e, stack) {
      Log.error(
        '[SEED] Failed to import classic-viner profiles: $e',
        name: 'ClassicVinerSeedPreload',
        category: LogCategory.system,
      );
      Log.verbose(
        '[SEED] Stack trace: $stack',
        name: 'ClassicVinerSeedPreload',
        category: LogCategory.system,
      );
    }
  }

  Future<void> preloadAvatarImagesIfNeeded({
    required ClassicVinerAvatarCacheWriter cacheWriter,
  }) async {
    if (kIsWeb) return;
    try {
      final manifest = await _loadManifest();
      final markerFile = await _markerFile(
        prefix: _avatarMarkerPrefix,
        version: manifest.version,
      );
      if (markerFile.existsSync()) {
        return;
      }

      for (final profileSeed in manifest.profiles) {
        if (profileSeed.pictureUrl == null ||
            profileSeed.pictureUrl!.isEmpty ||
            profileSeed.avatarAsset == null ||
            profileSeed.avatarAsset!.isEmpty) {
          continue;
        }

        final avatarBytes = await _assetBundle.load(profileSeed.avatarAsset!);
        final extension = path
            .extension(profileSeed.avatarAsset!)
            .replaceFirst('.', '');

        await cacheWriter(
          cacheKey: profileSeed.pictureUrl!,
          bytes: avatarBytes.buffer.asUint8List(),
          fileExtension: extension.isEmpty ? 'png' : extension,
        );
      }

      await _writeMarker(
        markerFile,
        'version=${manifest.version}\navatars=${manifest.profiles.length}\n',
      );
    } catch (e, stack) {
      Log.error(
        '[SEED] Failed to preload classic-viner avatars: $e',
        name: 'ClassicVinerSeedPreload',
        category: LogCategory.system,
      );
      Log.verbose(
        '[SEED] Stack trace: $stack',
        name: 'ClassicVinerSeedPreload',
        category: LogCategory.system,
      );
    }
  }

  Future<_ClassicVinerSeedManifest> _loadManifest() async {
    final cached = _cachedManifest;
    if (cached != null) return cached;
    final manifestJson = await _assetBundle.loadString(manifestAssetPath);
    final decoded = jsonDecode(manifestJson) as Map<String, dynamic>;
    final manifest = _ClassicVinerSeedManifest.fromJson(decoded);
    _cachedManifest = manifest;
    return manifest;
  }

  Future<File> _markerFile({
    required String prefix,
    required String version,
  }) async {
    final markerDirectory = await _markerDirectoryProvider();
    await markerDirectory.create(recursive: true);
    final safeVersion = version.replaceAll(RegExp('[^a-zA-Z0-9._-]'), '_');
    return File(path.join(markerDirectory.path, '$prefix$safeVersion'));
  }

  Future<void> _writeMarker(File markerFile, String contents) async {
    await markerFile.parent.create(recursive: true);
    await markerFile.writeAsString(contents);
  }
}

class _ClassicVinerSeedManifest {
  const _ClassicVinerSeedManifest({
    required this.version,
    required this.profiles,
  });

  factory _ClassicVinerSeedManifest.fromJson(Map<String, dynamic> json) {
    final profilesJson = json['profiles'] as List<dynamic>? ?? const [];
    return _ClassicVinerSeedManifest(
      version: json['version'] as String? ?? 'v1',
      profiles: profilesJson
          .map(
            (profile) => _ClassicVinerSeedProfile.fromJson(
              profile as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  final String version;
  final List<_ClassicVinerSeedProfile> profiles;
}

class _ClassicVinerSeedProfile {
  const _ClassicVinerSeedProfile({
    required this.pubkey,
    required this.displayName,
    required this.eventId,
    required this.createdAt,
    required this.archivedStats,
    this.name,
    this.about,
    this.pictureUrl,
    this.bannerUrl,
    this.avatarAsset,
  });

  factory _ClassicVinerSeedProfile.fromJson(Map<String, dynamic> json) {
    return _ClassicVinerSeedProfile(
      pubkey: json['pubkey'] as String,
      displayName: json['displayName'] as String,
      name: json['name'] as String?,
      about: json['about'] as String?,
      pictureUrl: json['pictureUrl'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
      avatarAsset: json['avatarAsset'] as String?,
      eventId:
          json['eventId'] as String? ??
          'classic-viner-seed-${json['pubkey'] as String}',
      createdAt: DateTime.parse(json['createdAt'] as String),
      archivedStats: _ArchivedStats.fromJson(
        json['archivedStats'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  final String pubkey;
  final String displayName;
  final String? name;
  final String? about;
  final String? pictureUrl;
  final String? bannerUrl;
  final String? avatarAsset;
  final String eventId;
  final DateTime createdAt;
  final _ArchivedStats archivedStats;

  UserProfile toUserProfile() {
    return UserProfile(
      pubkey: pubkey,
      name: name,
      displayName: displayName,
      about: about,
      picture: pictureUrl,
      banner: bannerUrl,
      rawData: {
        if (name != null) 'name': name,
        'display_name': displayName,
        if (about != null) 'about': about,
        if (pictureUrl != null) 'picture': pictureUrl,
        if (bannerUrl != null) 'banner': bannerUrl,
      },
      createdAt: createdAt,
      eventId: eventId,
    );
  }
}

class _ArchivedStats {
  const _ArchivedStats({this.videoCount, this.totalViews, this.totalLikes});

  factory _ArchivedStats.fromJson(Map<String, dynamic> json) {
    return _ArchivedStats(
      videoCount: json['videoCount'] as int?,
      totalViews: json['totalViews'] as int?,
      totalLikes: json['totalLikes'] as int?,
    );
  }

  final int? videoCount;
  final int? totalViews;
  final int? totalLikes;
}
