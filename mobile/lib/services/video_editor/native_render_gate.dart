// ABOUTME: Serializes app-owned native pro_video_editor renders, one at a time
// ABOUTME: The plugin hands every render its effect config through one static

import 'dart:async';

/// Serializes app-owned native `pro_video_editor` renders to one at a time.
///
/// `pro_video_editor` gives its custom AVFoundation compositor the current
/// render's effect config through a **process-wide** mutable static —
/// `VideoCompositor.config`, assigned by
/// `RenderVideo.makeVideoCompositorSubclass`. The compositor subclass declared
/// there is function-local, but a local class is still a single type with a
/// single metadata record, and the property is stored on the base class, so
/// every render in the process writes that one unsynchronized slot.
///
/// Two overlapping renders then race on the config's copy-on-write arrays: one
/// job reads the static while `AVAssetExportSession.setVideoComposition:`
/// instantiates the compositor, and another releases its own copy as its task
/// finishes. The unbalanced retain/release over-releases an array element and
/// segfaults in `objc_destructInstance` — seen on iOS 27 as an
/// `EXC_BAD_ACCESS` under `destroy for VideoCompositorConfig`. Short of
/// crashing it still corrupts output, because last writer wins: a render can
/// composite another render's overlays and color filters.
///
/// Serializing costs effectively no throughput. The plugin's own
/// `ExportGate.shared` is already `ExportGate(limit: 1)`, so encodes ran one at
/// a time regardless — only the unsafe setup phase (composition build, HEVC
/// pre-transcode, export-session preparation) overlapped. Reported upstream
/// against 2.13.1; the gate stays correct either way, so a fixed plugin makes
/// it redundant rather than wrong.
///
/// Entries are admitted first-in-first-out, and the queue never wedges on a
/// failed render: the slot is released whether [run]'s operation returns or
/// throws. Re-entrancy would deadlock, so the gate deliberately wraps only the
/// leaf `ProVideoEditor.renderVideoToFile` call inside
/// `VideoEditorRenderService.renderNativeVideoToFile`, which nothing re-enters.
class NativeRenderGate {
  NativeRenderGate._();

  /// Tail of the admission chain: the future that settles once the render
  /// holding the slot releases it. Completed by the gate itself and never with
  /// an error, so one failed render cannot break the chain for the next.
  static Future<void> _tail = Future<void>.value();

  /// Runs [operation] once every render queued ahead of it has finished.
  ///
  /// Returns [operation]'s own result and rethrows its error unchanged, so a
  /// caller cannot tell the gate is there apart from when it starts.
  static Future<T> run<T>(Future<T> Function() operation) {
    final predecessor = _tail;
    final slot = Completer<void>();
    _tail = slot.future;
    return predecessor.then((_) => operation()).whenComplete(slot.complete);
  }

  /// Drops the queue without cancelling anything.
  ///
  /// Test teardown only — a render still running natively keeps running, and
  /// production has no reason to forget one.
  static void reset() {
    _tail = Future<void>.value();
  }
}
