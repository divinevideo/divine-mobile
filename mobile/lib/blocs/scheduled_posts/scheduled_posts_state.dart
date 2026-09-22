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
/// scheduled from another device. Only its time and id are known, so the tab
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

/// One scheduled post as the tab shows it: the outbox row plus the draft
/// copy that still holds the video (absent when the draft's local files
/// were reclaimed, in which case the event's own tags carry the display).
class ScheduledPostItem extends Equatable {
  const ScheduledPostItem({required this.post, required this.draft});

  final ScheduledPost post;
  final DivineVideoDraft? draft;

  String get eventId => post.eventId;
  String get draftId => post.draftId;
  DateTime get publishAt => post.publishAtUtc;
  ScheduledPostStatus get status => post.status;
  String? get failureReason => post.failureReason;

  Event get event => ScheduledPostsRepository.decodeEvent(post);

  String get title {
    final draftTitle = draft?.title;
    if (draftTitle != null && draftTitle.trim().isNotEmpty) return draftTitle;
    return _tag('title') ?? '';
  }

  /// The published thumbnail, from the event's `image` tag.
  String? get thumbnailUrl => _tag('image');

  String? _tag(String name) {
    for (final tag in event.tags) {
      if (tag.length >= 2 && tag[0] == name) return tag[1];
    }
    return null;
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
