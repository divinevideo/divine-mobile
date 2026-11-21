// ABOUTME: Builds personal creator highlights from existing, bounded Funnelcake data.
// ABOUTME: Keeps missing metrics unknown and presentation markers account-scoped.

import 'dart:math' as math;

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';
import 'package:openvine/features/creator_highlights/creator_highlight.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videos_repository/videos_repository.dart';

abstract interface class CreatorHighlightsRepository {
  Future<CreatorHighlight?> load(String owner);

  /// Saves the daily presentation marker and the next spotlight to show.
  ///
  /// Throws [CreatorHighlightPresentationException] when storage rejects it.
  Future<void> markPresented(
    String owner,
    String localDate, {
    required int nextRotation,
  });

  /// Records that the invite to bring friends was seen on [localDate].
  ///
  /// A day counts once toward the weekly limit, however often it is shown.
  ///
  /// Throws [CreatorHighlightPresentationException] when storage rejects it.
  Future<void> markInviteShown(String owner, String localDate);
}

/// The device could not persist a highlight record (presentation or invite).
class CreatorHighlightPresentationException implements Exception {
  const CreatorHighlightPresentationException();

  @override
  String toString() => 'Could not save highlight presentation';
}

class FunnelcakeCreatorHighlightsRepository
    implements CreatorHighlightsRepository {
  FunnelcakeCreatorHighlightsRepository({
    required FunnelcakeApiClient client,
    required SharedPreferences preferences,
    DateTime Function()? now,
    Set<String> Function()? locallyDeletedEventIds,
    Map<String, int> Function()? locallyDeletedAddresses,
  }) : _client = client,
       _preferences = preferences,
       _now = now ?? DateTime.now,
       _deleted = locallyDeletedEventIds ?? _none,
       _deletedAddresses = locallyDeletedAddresses ?? _noAddresses;

  static const presentationPrefix = 'creator_highlight_presented_';
  static String presentationKey(String owner) => '$presentationPrefix$owner';

  static const invitePrefix = 'creator_highlight_invite_';
  static String inviteKey(String owner) => '$invitePrefix$owner';

  /// Posting days per week on which the invite may appear.
  static const maxInviteDaysPerWeek = 3;

  /// Stored as sorted, comma-separated `yyyy-MM-dd` dates from about the last
  /// two weeks, so a local date that steps back across a Monday (a westward
  /// time change) still sees the previous week's count.
  static const _inviteDateSeparator = ',';
  static const _inviteRetentionDays = 13;

  /// Stored as `<localDate>|<nextRotation>`; a bare date predates rotation.
  static const _markerSeparator = '|';
  static const pageSize = 100;
  static const maxPages = 4;
  final FunnelcakeApiClient _client;
  final SharedPreferences _preferences;
  final DateTime Function() _now;
  final Set<String> Function() _deleted;
  final Map<String, int> Function() _deletedAddresses;
  static Set<String> _none() => const {};
  static Map<String, int> _noAddresses() => const {};

  @override
  Future<CreatorHighlight?> load(String owner) async {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(owner)) return null;
    final now = _now().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = _weekStart(today);
    final date = _dateKey(today);
    final collected = <VideoEvent>[];
    int? offset;
    var complete = false;
    for (var page = 0; page < maxPages; page++) {
      final result = await _client.getVideosByAuthor(
        pubkey: owner,
        limit: pageSize,
        offset: offset,
      );
      for (final raw in result.videos) {
        if (raw.pubkey != owner ||
            raw.eventCreatedAt == null ||
            raw.eventCreatedAt! <= 0 ||
            raw.eventCreatedAt! > now.millisecondsSinceEpoch ~/ 1000 ||
            raw.isVerifiedArchive) {
          continue;
        }
        final video = raw.toVideoEvent();
        if (video.isRepost ||
            video.isOriginalVine ||
            video.isExpired ||
            video.timestamp.isAfter(now)) {
          continue;
        }
        collected.add(video);
      }
      final hasMore = result.hasMore ?? result.videos.length >= pageSize;
      if (!hasMore) {
        complete = true;
        break;
      }
      // An empty filtered page may still have unseen results behind it.
      if (result.videos.isEmpty) break;
      // The author endpoint is ordered by event timestamp. A complete
      // page older than this week bounds the scan without counting all history.
      if (result.videos.every((video) => video.createdAt.isBefore(weekStart))) {
        complete = true;
        break;
      }
      final next = result.nextOffset ?? (offset ?? 0) + result.videos.length;
      if (offset != null && next <= offset) break;
      offset = next;
    }
    if (collected.isEmpty) return null;
    // A deleted sibling remains evidence of when this work was first published,
    // but cannot supply the watch target, metadata, or engagement counts.
    final publicationEvidence = <String, VideoEvent>{};
    for (final video in collected) {
      final key = canonicalProfileFeedVideoKey(video);
      final previous = publicationEvidence[key];
      if (previous == null || video.timestamp.isBefore(previous.timestamp)) {
        publicationEvidence[key] = video;
      }
    }
    bool isEligible(
      VideoEvent video,
      Set<String> deletedIds,
      Map<String, int> deletedAddresses,
    ) {
      // Older deletions name a Kind 34235 video by its 34236 key (#10776).
      final deletedAt =
          deletedAddresses[video.addressableId] ??
          deletedAddresses[video.divineAddress];
      return !deletedIds.contains(video.id) &&
          (deletedAt == null ||
              (video.eventCreatedAt ?? video.createdAt) > deletedAt);
    }

    final deletedBeforeHydration = _deleted();
    final addressesBeforeHydration = _deletedAddresses();
    final eligible = collected
        .where(
          (video) => isEligible(
            video,
            deletedBeforeHydration,
            addressesBeforeHydration,
          ),
        )
        .toList();
    final hydrated = <VideoEvent>[];
    // Edit siblings carry separate engagement; keep each work's highest count,
    // as the profile merge does for views.
    final likesByWork = <String, int>{};
    final commentsByWork = <String, int>{};
    for (var start = 0; start < eligible.length; start += pageSize) {
      final chunk = eligible.sublist(
        start,
        (start + pageSize).clamp(0, eligible.length),
      );
      Map<String, BulkVideoStatsEntry> stats = const {};
      try {
        stats = (await _client.getBulkVideoStats(
          chunk.map((video) => video.id).toList(),
        )).stats;
      } on Exception {
        /* Publication evidence remains useful without engagement metrics. */
      }
      for (final video in chunk) {
        final entry = stats[video.id];
        if (entry != null) {
          final work = canonicalProfileFeedVideoKey(video);
          likesByWork[work] = math.max(
            likesByWork[work] ?? 0,
            math.max(entry.reactions, 0),
          );
          commentsByWork[work] = math.max(
            commentsByWork[work] ?? 0,
            math.max(entry.comments, 0),
          );
        }
        final views = entry?.views;
        // Event tags are creator-authored metadata, not measured engagement.
        // Only the bulk statistics response can establish a view claim here.
        final tags = {...video.rawTags}
          ..remove('views')
          ..remove('view_count')
          ..remove('total_views');
        if (views != null && views >= 0) tags['views'] = '$views';
        hydrated.add(video.copyWith(rawTags: tags));
      }
    }
    // Match the profile's edit-sibling identity and count merging rules.
    final deletedIds = _deleted();
    final deletedAddresses = _deletedAddresses();
    final videos =
        mergeProfileFeedVideoLists(
              const [],
              hydrated
                  .where(
                    (video) => isEligible(video, deletedIds, deletedAddresses),
                  )
                  .toList(),
            )
            .map((video) {
              final original =
                  publicationEvidence[canonicalProfileFeedVideoKey(video)]!;
              return video.copyWith(
                createdAt: original.createdAt,
                timestamp: original.timestamp,
                publishedAt: original.publishedAt ?? '${original.createdAt}',
              );
            })
            .where((video) {
              return !video.timestamp.isBefore(weekStart) &&
                  !video.timestamp.isAfter(now);
            })
            .toList();
    if (videos.isEmpty) return null;
    int? viewsOf(VideoEvent video) {
      for (final key in const ['views', 'view_count', 'total_views']) {
        final value = int.tryParse(video.rawTags[key] ?? '');
        if (value != null && value >= 0) return value;
      }
      return null;
    }

    final counts = videos.map(viewsOf).toList();
    final known = complete && counts.every((count) => count != null);
    final ranked = [...videos]
      ..sort((a, b) {
        final byViews = (viewsOf(b) ?? -1).compareTo(viewsOf(a) ?? -1);
        return byViews != 0 ? byViews : a.id.compareTo(b.id);
      });
    final days = videos.map((video) {
      final local = video.timestamp.toLocal();
      return DateTime(local.year, local.month, local.day);
    }).toSet();
    int? totalOf(Map<String, int> byWork) {
      final works = videos.map(canonicalProfileFeedVideoKey).toList();
      if (!complete || !works.every(byWork.containsKey)) return null;
      return works.fold<int>(0, (total, work) => total + byWork[work]!);
    }

    final marker = _preferences
        .getString(presentationKey(owner))
        ?.split(_markerSeparator);
    final rotation = marker != null && marker.length > 1
        ? int.tryParse(marker[1])
        : null;
    final topVideo = known ? ranked.first : null;
    final createdToday = videos
        .where((video) => !video.timestamp.isBefore(today))
        .length;
    final invitedDays = _invitedDays(owner, weekStart);
    return CreatorHighlight(
      owner: owner,
      localDate: date,
      createdToday: createdToday,
      creationDaysThisWeek: days.length,
      views: known
          ? counts.fold<int>(0, (total, count) => total + count!)
          : null,
      topVideo: topVideo,
      topVideoViews: topVideo == null ? null : viewsOf(topVideo),
      likes: totalOf(likesByWork),
      comments: totalOf(commentsByWork),
      celebrate: marker?.first != date,
      rotation: rotation != null && rotation >= 0 ? rotation : 0,
      showInvite:
          createdToday > 0 &&
          (invitedDays.contains(date) ||
              invitedDays.length < maxInviteDaysPerWeek),
    );
  }

  static String _dateKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  static DateTime _weekStart(DateTime day) =>
      DateTime(day.year, day.month, day.day - day.weekday + 1);

  /// Every retained date (about two weeks) the invite was shown to [owner].
  Set<String> _inviteRecord(String owner) {
    final raw = _preferences.getString(inviteKey(owner));
    if (raw == null || raw.isEmpty) return {};
    return raw.split(_inviteDateSeparator).toSet();
  }

  /// Days in the week starting [weekStart] the invite was already shown.
  Set<String> _invitedDays(String owner, DateTime weekStart) {
    final week = {
      for (var offset = 0; offset < DateTime.daysPerWeek; offset++)
        _dateKey(
          DateTime(weekStart.year, weekStart.month, weekStart.day + offset),
        ),
    };
    return _inviteRecord(owner).where(week.contains).toSet();
  }

  @override
  Future<void> markPresented(
    String owner,
    String localDate, {
    required int nextRotation,
  }) async {
    final saved = await _preferences.setString(
      presentationKey(owner),
      '$localDate$_markerSeparator$nextRotation',
    );
    if (!saved) throw const CreatorHighlightPresentationException();
  }

  @override
  Future<void> markInviteShown(String owner, String localDate) async {
    final record = _inviteRecord(owner);
    if (record.contains(localDate)) return;
    final day = DateTime.parse(localDate);
    // ISO dates sort as text; later dates stay in case the clock went back.
    final oldest = _dateKey(
      DateTime(day.year, day.month, day.day - _inviteRetentionDays),
    );
    final kept =
        (record..add(localDate)).where((d) => d.compareTo(oldest) >= 0).toList()
          ..sort();
    final saved = await _preferences.setString(
      inviteKey(owner),
      kept.join(_inviteDateSeparator),
    );
    if (!saved) throw const CreatorHighlightPresentationException();
  }
}
