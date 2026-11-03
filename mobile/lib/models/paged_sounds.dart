// ABOUTME: A sound list as far as it has been loaded, for the sound picker's
// ABOUTME: lists that load their next page when scrolled to the end.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart' show AudioEvent;

/// One load of a [PagedSounds] list: the sounds it added, their reuse counts
/// keyed by event id where the list has them, and whether a load after it
/// may add more.
typedef SoundPage = ({
  List<AudioEvent> sounds,
  Map<String, int> usageCounts,
  bool hasMore,
});

/// A sound list as far as it has been loaded, page by page.
class PagedSounds extends Equatable {
  const PagedSounds({
    required this.pages,
    this.usageCounts = const {},
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  /// A list holding just its first [page].
  PagedSounds.first(SoundPage page)
    : this(
        pages: [page.sounds],
        usageCounts: page.usageCounts,
        hasMore: page.hasMore,
      );

  /// The sounds each load added, in the order they came. A page is empty
  /// when the list left out everything it fetched.
  final List<List<AudioEvent>> pages;

  /// Reuse counts keyed by event id, for lists that come with them.
  final Map<String, int> usageCounts;

  /// Whether another page may add more sounds.
  final bool hasMore;

  /// Whether the next page is being loaded.
  final bool isLoadingMore;

  /// Every sound loaded so far, in page order.
  List<AudioEvent> get sounds => [for (final page in pages) ...page];

  /// Whether asking for the next page would load one now.
  bool get canLoadMore => hasMore && !isLoadingMore;

  /// This list with [page] after its pages.
  PagedSounds withPage(SoundPage page) => PagedSounds(
    pages: [...pages, page.sounds],
    usageCounts: {...usageCounts, ...page.usageCounts},
    hasMore: page.hasMore,
  );

  /// This list with each page passed through [narrow].
  PagedSounds narrowed(List<AudioEvent> Function(List<AudioEvent>) narrow) =>
      PagedSounds(
        pages: [for (final page in pages) narrow(page)],
        usageCounts: usageCounts,
        hasMore: hasMore,
        isLoadingMore: isLoadingMore,
      );

  PagedSounds copyWith({bool? hasMore, bool? isLoadingMore}) => PagedSounds(
    pages: pages,
    usageCounts: usageCounts,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );

  @override
  List<Object?> get props => [pages, usageCounts, hasMore, isLoadingMore];
}
