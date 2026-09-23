// ABOUTME: State for ScheduledPostsBloc: the scheduled posts of the account
// ABOUTME: joined with their drafts, plus the outcome of the last action.

part of 'scheduled_posts_bloc.dart';

enum ScheduledPostsStatus { initial, loading, loaded }

/// What the last user action came to; the view turns it into a snackbar.
enum ScheduledPostsActionOutcome {
  none,
  cancelled,
  rescheduled,
  publishedNow,
  retryQueued,

  /// The relay had already published the post before the action landed.
  alreadyPublished,

  /// The relay could not be reached; nothing changed.
  unavailable,

  /// Signing failed or the account changed; nothing changed.
  failed,
}

/// A post the relay holds for this account that this device has no row for —
/// scheduled from another device. Only its time and id are known, so the section
/// can show it and withdraw it, nothing else.
class RemoteScheduledPost extends Equatable {
  const RemoteScheduledPost({required this.eventId, required this.publishAt});

  factory RemoteScheduledPost.fromServerEntry(
    ScheduledPostServerEntry entry,
  ) => RemoteScheduledPost(
    eventId: entry.eventId,
    publishAt: DateTime.fromMillisecondsSinceEpoch(
      entry.publishAt * 1000,
      isUtc: true,
    ),
  );

  final String eventId;
  final DateTime publishAt;

  @override
  List<Object?> get props => [eventId, publishAt];
}

/// One scheduled post as the section shows it: the outbox row plus the draft
/// copy that still holds the video (absent when the draft's local files
/// were reclaimed, in which case the event's own tags carry the display).
class ScheduledPostItem extends Equatable {
  /// Reads the signed event's display tags once, not on every build.
  factory ScheduledPostItem({
    required ScheduledPost post,
    required DivineVideoDraft? draft,
  }) {
    final tags = ScheduledPostsRepository.decodeEvent(post).tags;
    String? tag(String name) {
      for (final tag in tags) {
        if (tag.length >= 2 && tag[0] == name) return tag[1];
      }
      return null;
    }

    return ScheduledPostItem._(
      post: post,
      draft: draft,
      eventTitle: tag('title'),
      thumbnailUrl: tag('image'),
    );
  }

  const ScheduledPostItem._({
    required this.post,
    required this.draft,
    required String? eventTitle,
    required this.thumbnailUrl,
  }) : _eventTitle = eventTitle;

  final ScheduledPost post;
  final DivineVideoDraft? draft;
  final String? _eventTitle;

  /// The published thumbnail, from the event's `image` tag.
  final String? thumbnailUrl;

  String get eventId => post.eventId;
  String get draftId => post.draftId;
  DateTime get publishAt => post.publishAtUtc;
  ScheduledPostStatus get status => post.status;
  String? get failureReason => post.failureReason;

  String get title {
    final draftTitle = draft?.title;
    if (draftTitle != null && draftTitle.trim().isNotEmpty) return draftTitle;
    return _eventTitle ?? '';
  }

  @override
  List<Object?> get props => [post, draft?.id, draft?.lastModified];
}

class ScheduledPostsState extends Equatable {
  const ScheduledPostsState({
    this.status = ScheduledPostsStatus.initial,
    this.items = const [],
    this.remotePosts = const [],
    this.busyEventId,
    this.lastAction = ScheduledPostsActionOutcome.none,
    this.actionCount = 0,
  });

  final ScheduledPostsStatus status;

  /// This device's scheduled posts, soonest first.
  final List<ScheduledPostItem> items;

  /// Posts the relay holds that were scheduled from another device.
  final List<RemoteScheduledPost> remotePosts;

  /// The post an action is running on, so its row can show it.
  final String? busyEventId;

  final ScheduledPostsActionOutcome lastAction;

  /// Bumped with every action so a listener fires even when two actions in
  /// a row end the same way.
  final int actionCount;

  bool get isEmpty => items.isEmpty && remotePosts.isEmpty;

  ScheduledPostsState copyWith({
    ScheduledPostsStatus? status,
    List<ScheduledPostItem>? items,
    List<RemoteScheduledPost>? remotePosts,
    String? busyEventId,
    bool clearBusyEventId = false,
    ScheduledPostsActionOutcome? lastAction,
    int? actionCount,
  }) {
    return ScheduledPostsState(
      status: status ?? this.status,
      items: items ?? this.items,
      remotePosts: remotePosts ?? this.remotePosts,
      busyEventId: clearBusyEventId ? null : (busyEventId ?? this.busyEventId),
      lastAction: lastAction ?? this.lastAction,
      actionCount: actionCount ?? this.actionCount,
    );
  }

  @override
  List<Object?> get props => [
    status,
    items,
    remotePosts,
    busyEventId,
    lastAction,
    actionCount,
  ];
}
