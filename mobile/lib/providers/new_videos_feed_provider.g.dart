// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'new_videos_feed_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// New Videos feed provider - shows newest videos first.
///
/// Delegates video fetching to [VideosRepository.getNewVideos] so the Explore
/// New Videos tab does not share the popular/trending source.

@ProviderFor(NewVideosFeed)
final newVideosFeedProvider = NewVideosFeedProvider._();

/// New Videos feed provider - shows newest videos first.
///
/// Delegates video fetching to [VideosRepository.getNewVideos] so the Explore
/// New Videos tab does not share the popular/trending source.
final class NewVideosFeedProvider
    extends $AsyncNotifierProvider<NewVideosFeed, VideoFeedState> {
  /// New Videos feed provider - shows newest videos first.
  ///
  /// Delegates video fetching to [VideosRepository.getNewVideos] so the Explore
  /// New Videos tab does not share the popular/trending source.
  NewVideosFeedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'newVideosFeedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$newVideosFeedHash();

  @$internal
  @override
  NewVideosFeed create() => NewVideosFeed();
}

String _$newVideosFeedHash() => r'd9721ec519083a62aa876987b7b602915507b56a';

/// New Videos feed provider - shows newest videos first.
///
/// Delegates video fetching to [VideosRepository.getNewVideos] so the Explore
/// New Videos tab does not share the popular/trending source.

abstract class _$NewVideosFeed extends $AsyncNotifier<VideoFeedState> {
  FutureOr<VideoFeedState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<VideoFeedState>, VideoFeedState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<VideoFeedState>, VideoFeedState>,
              AsyncValue<VideoFeedState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
