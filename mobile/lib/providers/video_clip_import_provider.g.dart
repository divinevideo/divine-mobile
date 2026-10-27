// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_clip_import_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(videoClipImportService)
final videoClipImportServiceProvider = VideoClipImportServiceProvider._();

final class VideoClipImportServiceProvider
    extends
        $FunctionalProvider<
          VideoClipImportService,
          VideoClipImportService,
          VideoClipImportService
        >
    with $Provider<VideoClipImportService> {
  VideoClipImportServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoClipImportServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoClipImportServiceHash();

  @$internal
  @override
  $ProviderElement<VideoClipImportService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoClipImportService create(Ref ref) {
    return videoClipImportService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoClipImportService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoClipImportService>(value),
    );
  }
}

String _$videoClipImportServiceHash() =>
    r'7bc255e732e92d62a8b10c01f760e83ec6aacb58';
