import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A single unchanged clip is handed to `AVPlayerItem` directly instead of
/// being copied into an `AVMutableComposition`, for two separate reasons. An
/// HLS `AVURLAsset` exposes no tracks — `loadTracks(withMediaType:)` returns an
/// empty array — so a composition built from one always ends in
/// `CompositionError.noPlayableVideoTracks` and can never play. A local file
/// has nothing to compose, and `AVPlayerLooper` closes the loop seam over an
/// asset while it does not over a composition of the same file.
///
/// None of this has a Dart runtime surface, and the package has no Swift test
/// harness, so the invariants are pinned as a source contract the same way the
/// composition guards are: a refactor that routes these sources back through
/// `buildComposition` keeps every runtime test green while restoring
/// "No playable video tracks found." for every HLS source and the loop seam
/// for every local one.
void main() {
  group('Apple native direct-item contract', () {
    test('a single unchanged clip is diverted away from the composition', () {
      final source = _appleSourceFile().readAsStringSync();

      expect(
        source,
        contains('soleDirectItemClip'),
        reason:
            'The eligibility helper is what keeps a divertable source out of '
            'buildComposition.',
      );
      expect(
        source,
        contains('pathExtension.lowercased() == "m3u8"'),
        reason:
            'Every app-constructed HLS URL ends in .m3u8, so the path '
            'extension is the cheap deterministic signal that admits one - no '
            'extra load to discover the asset has no tracks.',
      );
      expect(
        source,
        contains('return !uri.hasPrefix("http")'),
        reason:
            'A remote non-HLS URL keeps taking the composition, which owns the '
            'buffering and header handling for it; only a local file joins HLS '
            'on the direct path.',
      );
      expect(
        source,
        contains('clipsRaw.count == 1'),
        reason:
            'Only a whole-timeline source may skip the composition — a '
            'multi-clip timeline still needs one to stitch.',
      );
      expect(
        source,
        contains('(clip["startMs"] as? NSNumber)?.int64Value ?? 0 == 0'),
        reason:
            'An AVPlayerItem carries the whole asset from zero, so a non-zero '
            'startMs has no exact representation on this path and must not be '
            'diverted here — it would report a timeline that does not match '
            'what plays.',
      );
      expect(
        source,
        contains(
          '(clip["playbackSpeed"] as? NSNumber)?.doubleValue ?? 1.0 == 1.0',
        ),
        reason:
            'Only the composition can rescale a clip, so an off-speed clip '
            'must keep taking that path.',
      );
      expect(
        source,
        contains('(clip["volume"] as? NSNumber)?.doubleValue ?? 1.0 == 1.0'),
        reason:
            'Only the composition can apply per-clip volume with an audio mix, '
            'so a clip with custom volume must keep taking that path.',
      );

      final dispatch = source.indexOf('Self.soleDirectItemClip(in: clipsRaw)');
      final compositionCall = source.indexOf(
        'makeCompositionPlayerItem(from: clipsRaw)',
      );
      expect(dispatch, greaterThanOrEqualTo(0));
      expect(compositionCall, greaterThanOrEqualTo(0));
      expect(
        dispatch,
        lessThan(compositionCall),
        reason:
            'The eligibility check must gate the composition call, not follow '
            'it — otherwise the composition is built first and throws.',
      );
    });

    test('the direct builder never demands tracks an HLS asset lacks', () {
      final body = _functionBody(
        _appleSourceFile().readAsStringSync(),
        'private func makeDirectPlayerItem(',
      );

      // The path is not HLS-only: a single unchanged local file takes it too,
      // and that one does need its tracks, both to decide rotation and to
      // clamp the loop to the shorter track. HLS must survive that unchanged,
      // and it can only do so if every track read is optional — loadTracks
      // hands back an empty array for it.
      expect(
        body,
        isNot(
          contains('let videoTrack = try await asset.loadTracks'),
        ),
        reason:
            'A non-optional track read would crash or throw for HLS, which '
            'exposes none.',
      );
      expect(
        body,
        contains(
          'if let videoTrack = videoTracks.first, '
          'let audioTrack = audioTracks.first {',
        ),
        reason:
            'The clamp may only run when both tracks are really there, so an '
            'HLS source falls through it untouched.',
      );
      expect(
        _functionBody(
          _appleSourceFile().readAsStringSync(),
          'private static func directItemSuitsRotation(',
        ),
        contains('if isHls { return true }'),
        reason:
            'The rotation check must short-circuit before it asks an HLS '
            'asset for tracks it does not have.',
      );
      expect(
        body,
        contains('AVPlayerItem(asset: asset)'),
        reason: 'The item must come straight from the AVURLAsset.',
      );
      expect(
        body,
        contains('loopTimeRange'),
        reason:
            'AVPlayerLooper ignores forwardPlaybackEndTime when it wraps, so '
            'a clip whose container outlives its picture needs the trim as the '
            'looper range instead.',
      );
      expect(
        body,
        contains('forwardPlaybackEndTime'),
        reason:
            'Trimming has no composition time range to live in, so the feed '
            'cap has to be applied as a forward playback end time.',
      );
      expect(
        body,
        contains('avURLAssetHTTPHeaderFieldsKey'),
        reason:
            'Gated HLS playback authenticates with a viewer-auth header, which '
            'is lost if the asset is built without the header options.',
      );
      expect(
        body,
        contains('loopAudioMix = nil'),
        reason:
            'A direct item has no audio mix, so a mix left behind by an '
            'earlier composition would be re-applied to every item the looper '
            'builds - with input parameters addressing another asset.',
      );
    });
  });
}

/// Source text of the function opening at [signature], up to the next
/// declaration at the same indentation.
String _functionBody(String source, String signature) {
  final start = source.indexOf(signature);
  expect(
    start,
    greaterThanOrEqualTo(0),
    reason: 'Expected to find `$signature` in the Apple player source.',
  );
  final next = source.indexOf('\n    private ', start + signature.length);
  return source.substring(start, next == -1 ? source.length : next);
}

/// The iOS and macOS players share a single Darwin source tree
/// (`darwin/divine_video_player/Sources/`), so the contract is asserted once.
File _appleSourceFile() {
  final packageRelative = File(
    'darwin/divine_video_player/Sources/divine_video_player/'
    'DivineVideoPlayerInstance.swift',
  );
  if (packageRelative.existsSync()) {
    return packageRelative;
  }

  return File(
    'packages/divine_video_player/'
    'darwin/divine_video_player/Sources/divine_video_player/'
    'DivineVideoPlayerInstance.swift',
  );
}
