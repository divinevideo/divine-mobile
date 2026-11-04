// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'new_videos_feed_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Publication-ordered feed provider - shows newest videos first.
///
/// [PublicationFeed.latest] delegates to [VideosRepository.getNewVideos], so
/// the Explore Latest tab does not share the popular/trending source.
/// [PublicationFeed.newCreators] delegates to
/// [VideosRepository.getNewCreatorVideos], which has no relay fallback.

@ProviderFor(NewVideosFeed)
final newVideosFeedProvider = NewVideosFeedFamily._();

/// Publication-ordered feed provider - shows newest videos first.
///
/// [PublicationFeed.latest] delegates to [VideosRepository.getNewVideos], so
/// the Explore Latest tab does not share the popular/trending source.
/// [PublicationFeed.newCreators] delegates to
/// [VideosRepository.getNewCreatorVideos], which has no relay fallback.
final class NewVideosFeedProvider
    extends $AsyncNotifierProvider<NewVideosFeed, VideoFeedState> {
  /// Publication-ordered feed provider - shows newest videos first.
  ///
  /// [PublicationFeed.latest] delegates to [VideosRepository.getNewVideos], so
  /// the Explore Latest tab does not share the popular/trending source.
  /// [PublicationFeed.newCreators] delegates to
  /// [VideosRepository.getNewCreatorVideos], which has no relay fallback.
  NewVideosFeedProvider._({
    required NewVideosFeedFamily super.from,
    required PublicationFeed super.argument,
  }) : super(
         retry: null,
         name: r'newVideosFeedProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$newVideosFeedHash();

  @override
  String toString() {
    return r'newVideosFeedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  NewVideosFeed create() => NewVideosFeed();

  @override
  bool operator ==(Object other) {
    return other is NewVideosFeedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$newVideosFeedHash() => r'f9f571feb6f259f875b1ee3926ee2d31bd6f8c60';

/// Publication-ordered feed provider - shows newest videos first.
///
/// [PublicationFeed.latest] delegates to [VideosRepository.getNewVideos], so
/// the Explore Latest tab does not share the popular/trending source.
/// [PublicationFeed.newCreators] delegates to
/// [VideosRepository.getNewCreatorVideos], which has no relay fallback.

final class NewVideosFeedFamily extends $Family
    with
        $ClassFamilyOverride<
          NewVideosFeed,
          AsyncValue<VideoFeedState>,
          VideoFeedState,
          FutureOr<VideoFeedState>,
          PublicationFeed
        > {
  NewVideosFeedFamily._()
    : super(
        retry: null,
        name: r'newVideosFeedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Publication-ordered feed provider - shows newest videos first.
  ///
  /// [PublicationFeed.latest] delegates to [VideosRepository.getNewVideos], so
  /// the Explore Latest tab does not share the popular/trending source.
  /// [PublicationFeed.newCreators] delegates to
  /// [VideosRepository.getNewCreatorVideos], which has no relay fallback.

  NewVideosFeedProvider call(PublicationFeed feed) =>
      NewVideosFeedProvider._(argument: feed, from: this);

  @override
  String toString() => r'newVideosFeedProvider';
}

/// Publication-ordered feed provider - shows newest videos first.
///
/// [PublicationFeed.latest] delegates to [VideosRepository.getNewVideos], so
/// the Explore Latest tab does not share the popular/trending source.
/// [PublicationFeed.newCreators] delegates to
/// [VideosRepository.getNewCreatorVideos], which has no relay fallback.

abstract class _$NewVideosFeed extends $AsyncNotifier<VideoFeedState> {
  late final _$args = ref.$arg as PublicationFeed;
  PublicationFeed get feed => _$args;

  FutureOr<VideoFeedState> build(PublicationFeed feed);
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
    return element.handleCreate(ref, () => build(_$args));
  }
}
