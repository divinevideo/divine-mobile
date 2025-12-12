// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'latest_videos_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for the latest videos from the network

@ProviderFor(LatestVideos)
const latestVideosProvider = LatestVideosProvider._();

/// Provider for the latest videos from the network
final class LatestVideosProvider
    extends $AsyncNotifierProvider<LatestVideos, List<VideoEvent>> {
  /// Provider for the latest videos from the network
  const LatestVideosProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'latestVideosProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$latestVideosHash();

  @$internal
  @override
  LatestVideos create() => LatestVideos();
}

String _$latestVideosHash() => r'79264776fd42eb21e2660c8cb585d72e05a649d2';

/// Provider for the latest videos from the network

abstract class _$LatestVideos extends $AsyncNotifier<List<VideoEvent>> {
  FutureOr<List<VideoEvent>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<List<VideoEvent>>, List<VideoEvent>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<VideoEvent>>, List<VideoEvent>>,
              AsyncValue<List<VideoEvent>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
