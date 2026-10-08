// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subtitle_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Fetches the track and its verified machine-translation attribution.

@ProviderFor(subtitleTrack)
final subtitleTrackProvider = SubtitleTrackFamily._();

/// Fetches the track and its verified machine-translation attribution.

final class SubtitleTrackProvider
    extends
        $FunctionalProvider<
          AsyncValue<SubtitleFetchResult>,
          SubtitleFetchResult,
          FutureOr<SubtitleFetchResult>
        >
    with
        $FutureModifier<SubtitleFetchResult>,
        $FutureProvider<SubtitleFetchResult> {
  /// Fetches the track and its verified machine-translation attribution.
  SubtitleTrackProvider._({
    required SubtitleTrackFamily super.from,
    required ({
      String videoId,
      String? textTrackRef,
      List<String> textTrackRefs,
      String? textTrackContent,
      String? sha256,
      String? sourceLang,
      String? appLocaleCode,
    })
    super.argument,
  }) : super(
         retry: null,
         name: r'subtitleTrackProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$subtitleTrackHash();

  @override
  String toString() {
    return r'subtitleTrackProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<SubtitleFetchResult> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SubtitleFetchResult> create(Ref ref) {
    final argument =
        this.argument
            as ({
              String videoId,
              String? textTrackRef,
              List<String> textTrackRefs,
              String? textTrackContent,
              String? sha256,
              String? sourceLang,
              String? appLocaleCode,
            });
    return subtitleTrack(
      ref,
      videoId: argument.videoId,
      textTrackRef: argument.textTrackRef,
      textTrackRefs: argument.textTrackRefs,
      textTrackContent: argument.textTrackContent,
      sha256: argument.sha256,
      sourceLang: argument.sourceLang,
      appLocaleCode: argument.appLocaleCode,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SubtitleTrackProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$subtitleTrackHash() => r'181c9981c48e772d640f75c748f0d76595fe2a8f';

/// Fetches the track and its verified machine-translation attribution.

final class SubtitleTrackFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<SubtitleFetchResult>,
          ({
            String videoId,
            String? textTrackRef,
            List<String> textTrackRefs,
            String? textTrackContent,
            String? sha256,
            String? sourceLang,
            String? appLocaleCode,
          })
        > {
  SubtitleTrackFamily._()
    : super(
        retry: null,
        name: r'subtitleTrackProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Fetches the track and its verified machine-translation attribution.

  SubtitleTrackProvider call({
    required String videoId,
    String? textTrackRef,
    List<String> textTrackRefs = const [],
    String? textTrackContent,
    String? sha256,
    String? sourceLang,
    String? appLocaleCode,
  }) => SubtitleTrackProvider._(
    argument: (
      videoId: videoId,
      textTrackRef: textTrackRef,
      textTrackRefs: textTrackRefs,
      textTrackContent: textTrackContent,
      sha256: sha256,
      sourceLang: sourceLang,
      appLocaleCode: appLocaleCode,
    ),
    from: this,
  );

  @override
  String toString() => r'subtitleTrackProvider';
}

/// Cue-only view for callers that do not render track attribution.

@ProviderFor(subtitleCues)
final subtitleCuesProvider = SubtitleCuesFamily._();

/// Cue-only view for callers that do not render track attribution.

final class SubtitleCuesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SubtitleCue>>,
          List<SubtitleCue>,
          FutureOr<List<SubtitleCue>>
        >
    with
        $FutureModifier<List<SubtitleCue>>,
        $FutureProvider<List<SubtitleCue>> {
  /// Cue-only view for callers that do not render track attribution.
  SubtitleCuesProvider._({
    required SubtitleCuesFamily super.from,
    required ({
      String videoId,
      String? textTrackRef,
      List<String> textTrackRefs,
      String? textTrackContent,
      String? sha256,
      String? sourceLang,
    })
    super.argument,
  }) : super(
         retry: null,
         name: r'subtitleCuesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$subtitleCuesHash();

  @override
  String toString() {
    return r'subtitleCuesProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<SubtitleCue>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<SubtitleCue>> create(Ref ref) {
    final argument =
        this.argument
            as ({
              String videoId,
              String? textTrackRef,
              List<String> textTrackRefs,
              String? textTrackContent,
              String? sha256,
              String? sourceLang,
            });
    return subtitleCues(
      ref,
      videoId: argument.videoId,
      textTrackRef: argument.textTrackRef,
      textTrackRefs: argument.textTrackRefs,
      textTrackContent: argument.textTrackContent,
      sha256: argument.sha256,
      sourceLang: argument.sourceLang,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SubtitleCuesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$subtitleCuesHash() => r'05bea12efc01630f894f1a103b2bb2e6787f5898';

/// Cue-only view for callers that do not render track attribution.

final class SubtitleCuesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<SubtitleCue>>,
          ({
            String videoId,
            String? textTrackRef,
            List<String> textTrackRefs,
            String? textTrackContent,
            String? sha256,
            String? sourceLang,
          })
        > {
  SubtitleCuesFamily._()
    : super(
        retry: null,
        name: r'subtitleCuesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Cue-only view for callers that do not render track attribution.

  SubtitleCuesProvider call({
    required String videoId,
    String? textTrackRef,
    List<String> textTrackRefs = const [],
    String? textTrackContent,
    String? sha256,
    String? sourceLang,
  }) => SubtitleCuesProvider._(
    argument: (
      videoId: videoId,
      textTrackRef: textTrackRef,
      textTrackRefs: textTrackRefs,
      textTrackContent: textTrackContent,
      sha256: sha256,
      sourceLang: sourceLang,
    ),
    from: this,
  );

  @override
  String toString() => r'subtitleCuesProvider';
}

/// Tracks global subtitle visibility (CC on/off).
///
/// When enabled, subtitles are shown on all videos that have them.
/// This acts as an app-wide preference - toggling on one video
/// applies to all videos.

@ProviderFor(SubtitleVisibility)
final subtitleVisibilityProvider = SubtitleVisibilityProvider._();

/// Tracks global subtitle visibility (CC on/off).
///
/// When enabled, subtitles are shown on all videos that have them.
/// This acts as an app-wide preference - toggling on one video
/// applies to all videos.
final class SubtitleVisibilityProvider
    extends $NotifierProvider<SubtitleVisibility, bool> {
  /// Tracks global subtitle visibility (CC on/off).
  ///
  /// When enabled, subtitles are shown on all videos that have them.
  /// This acts as an app-wide preference - toggling on one video
  /// applies to all videos.
  SubtitleVisibilityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subtitleVisibilityProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subtitleVisibilityHash();

  @$internal
  @override
  SubtitleVisibility create() => SubtitleVisibility();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$subtitleVisibilityHash() =>
    r'0252e5d29e864a6abd314f6e42d42a9d0cfc76b1';

/// Tracks global subtitle visibility (CC on/off).
///
/// When enabled, subtitles are shown on all videos that have them.
/// This acts as an app-wide preference - toggling on one video
/// applies to all videos.

abstract class _$SubtitleVisibility extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
