// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subtitle_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Fetches subtitle cues for a video, using ordered fallback.
///
/// 1. If [textTrackContent] is present (REST API embedded the VTT) and the
///    viewer does not want a translation, parse it directly — zero network.
/// 2. When the viewer wants a translation ([sourceLang] differs from their
///    target and is not kept original), skip the embedded source track so the
///    language-specific Blossom track is fetched instead.
/// 3. For each ref in [textTrackRefs] (or [textTrackRef] for back-compat),
///    try HTTP fetch or relay query in order.
/// 4. If [sha256] is present, fetch from Blossom at
///    `https://media.divine.video/{sha256}/vtt`, translated when requested.
/// 5. Otherwise returns an empty list (no subtitles available).

@ProviderFor(subtitleCues)
final subtitleCuesProvider = SubtitleCuesFamily._();

/// Fetches subtitle cues for a video, using ordered fallback.
///
/// 1. If [textTrackContent] is present (REST API embedded the VTT) and the
///    viewer does not want a translation, parse it directly — zero network.
/// 2. When the viewer wants a translation ([sourceLang] differs from their
///    target and is not kept original), skip the embedded source track so the
///    language-specific Blossom track is fetched instead.
/// 3. For each ref in [textTrackRefs] (or [textTrackRef] for back-compat),
///    try HTTP fetch or relay query in order.
/// 4. If [sha256] is present, fetch from Blossom at
///    `https://media.divine.video/{sha256}/vtt`, translated when requested.
/// 5. Otherwise returns an empty list (no subtitles available).

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
  /// Fetches subtitle cues for a video, using ordered fallback.
  ///
  /// 1. If [textTrackContent] is present (REST API embedded the VTT) and the
  ///    viewer does not want a translation, parse it directly — zero network.
  /// 2. When the viewer wants a translation ([sourceLang] differs from their
  ///    target and is not kept original), skip the embedded source track so the
  ///    language-specific Blossom track is fetched instead.
  /// 3. For each ref in [textTrackRefs] (or [textTrackRef] for back-compat),
  ///    try HTTP fetch or relay query in order.
  /// 4. If [sha256] is present, fetch from Blossom at
  ///    `https://media.divine.video/{sha256}/vtt`, translated when requested.
  /// 5. Otherwise returns an empty list (no subtitles available).
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

String _$subtitleCuesHash() => r'fbcbc154caaa74c9791dd2c38c8b5d8eb22e5919';

/// Fetches subtitle cues for a video, using ordered fallback.
///
/// 1. If [textTrackContent] is present (REST API embedded the VTT) and the
///    viewer does not want a translation, parse it directly — zero network.
/// 2. When the viewer wants a translation ([sourceLang] differs from their
///    target and is not kept original), skip the embedded source track so the
///    language-specific Blossom track is fetched instead.
/// 3. For each ref in [textTrackRefs] (or [textTrackRef] for back-compat),
///    try HTTP fetch or relay query in order.
/// 4. If [sha256] is present, fetch from Blossom at
///    `https://media.divine.video/{sha256}/vtt`, translated when requested.
/// 5. Otherwise returns an empty list (no subtitles available).

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

  /// Fetches subtitle cues for a video, using ordered fallback.
  ///
  /// 1. If [textTrackContent] is present (REST API embedded the VTT) and the
  ///    viewer does not want a translation, parse it directly — zero network.
  /// 2. When the viewer wants a translation ([sourceLang] differs from their
  ///    target and is not kept original), skip the embedded source track so the
  ///    language-specific Blossom track is fetched instead.
  /// 3. For each ref in [textTrackRefs] (or [textTrackRef] for back-compat),
  ///    try HTTP fetch or relay query in order.
  /// 4. If [sha256] is present, fetch from Blossom at
  ///    `https://media.divine.video/{sha256}/vtt`, translated when requested.
  /// 5. Otherwise returns an empty list (no subtitles available).

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
