// ABOUTME: Phase-level timing for a single video publish, emitted as
// ABOUTME: greppable PUBTIME log lines and as a Firebase Performance trace.

import 'dart:async';

import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:upload_repository/upload_repository.dart' show UploadPhases;

/// Token every timing line carries, so a log export can be reduced to the
/// publish timeline with a single `grep PUBTIME`.
const String publishTimingToken = 'PUBTIME';

/// Logger name every timing line is tagged with. Exported log lines render it
/// as `[PublishTiming]`, which is the second way to filter for these entries.
const String publishTimingLogName = 'PublishTiming';

/// Firebase Performance trace name for one publish, from the first upload byte
/// to the outcome. Sits alongside the existing `video_upload` trace, which
/// covers only the Blossom call and reports it as a single number.
const String publishTraceName = 'video_publish';

/// Phase names shared by the sites that emit them and the metric mapping.
///
/// The upload and Nostr phases are timed where they happen — deep in the
/// upload manager and the event publisher — while the mapping to Firebase
/// metrics lives here, so both ends refer to the same constant.
abstract class PublishPhases {
  static const String upload = 'upload';

  // The upload leg is timed inside upload_repository, so these name the
  // package's constants rather than restating their values: a divergence
  // is then a compile error instead of something a parity test has to catch.
  static const String uploadTransfer = UploadPhases.uploadTransfer;
  static const String uploadThumbnail = UploadPhases.uploadThumbnail;
  static const String uploadThumbnailExtract =
      UploadPhases.uploadThumbnailExtract;
  static const String uploadThumbnailBlurhash =
      UploadPhases.uploadThumbnailBlurhash;
  static const String uploadThumbnailPut = UploadPhases.uploadThumbnailPut;
  static const String mentions = 'mentions';
  static const String subtitles = 'subtitles';
  static const String nostr = 'nostr';
  static const String nostrBlurhash = 'nostr.blurhash';
  static const String nostrSign = 'nostr.sign';
  static const String nostrPublish = 'nostr.publish';
  static const String invites = 'invites';

  /// Detail marker for a leg that short-circuited on work a previous attempt
  /// already finished — a thumbnail already on the CDN, or an event the
  /// signer already signed.
  static const String reusedDetail = UploadPhases.reusedDetail;

  /// Detail marker on [nostrSign] for a signature this attempt really made.
  static const String signedDetail = 'signed';
}

/// Firebase metric name per phase. A phase that never ran reports no metric,
/// so an absent metric reads as "did not happen" rather than as zero.
///
/// The metrics are *not* additive: [PublishPhases.uploadThumbnail] runs in
/// parallel with [PublishPhases.uploadTransfer], so `upload_ms` is roughly the
/// longer of the two rather than their sum. Only the summary log line's
/// top-level phases add up to the total.
///
/// `nostr_blurhash_ms` is a slice inside `nostr_ms`, beside `sign_ms` and
/// `nostr_publish_ms`. It carries the parent's prefix because the upload leg
/// derives a blurhash of its own ([PublishPhases.uploadThumbnailBlurhash]).
///
/// Its presence means the Nostr leg entered the fallback path for deriving a
/// second blurhash, not that one was successfully produced. Its absence on a
/// publish that reached the relay usually means the Nostr leg reused
/// `PendingUpload.blurhash`; it can also mean the fallback had no local video
/// path to decode. The other exception is a publish that coalesced onto another
/// chain's event and reported no `nostr.*` slice at all, which
/// [logPublishPhase] describes.
///
/// [PublishPhases.uploadThumbnailExtract],
/// [PublishPhases.uploadThumbnailBlurhash], and
/// [PublishPhases.uploadThumbnailPut] stay unmapped because
/// [PublishPhases.uploadThumbnail] already accounts for their time.
const Map<String, String> _metricByPhase = {
  PublishPhases.upload: 'upload_ms',
  PublishPhases.uploadTransfer: 'transfer_ms',
  PublishPhases.uploadThumbnail: 'thumbnail_ms',
  PublishPhases.mentions: 'mentions_ms',
  PublishPhases.subtitles: 'subtitles_ms',
  PublishPhases.nostr: 'nostr_ms',
  PublishPhases.nostrBlurhash: 'nostr_blurhash_ms',
  PublishPhases.nostrSign: 'sign_ms',
  PublishPhases.nostrPublish: 'nostr_publish_ms',
  PublishPhases.invites: 'invites_ms',
};

/// Wall-clock metric for the whole publish.
const String publishTotalMetric = 'total_ms';

/// Size of the uploaded video file, reported once.
///
/// Dividing it by `transfer_ms` gives the **effective** throughput of the
/// publish — bytes delivered per unit of wall clock the user actually waited,
/// retry overhead included. It is not the line rate, and no combination of
/// these metrics recovers one: a single transfer leg can contain a whole-file
/// OS attempt that failed, a chunked resumable fallback that re-sent the same
/// bytes, iteration across servers, and per-chunk retries, none of which the
/// publish layer can see. Measuring the line rate means instrumenting
/// `blossom_upload_service` at the transport boundary.
const String publishPayloadMetric = 'payload_bytes';

/// How many times the transfer *leg* ran for this publish.
///
/// `transfer_ms` sums the legs, so without this a publish that resumed after a
/// failure and a genuinely slow one look identical — and a leg that hit the
/// upload timeout carries minutes of dead time into the sum.
///
/// This counts the phase, not the transport: one leg is one
/// [PublishPhases.uploadTransfer] line, however many attempts the upload
/// service made inside it. `transfer_legs == 1` therefore means "the publish
/// entered the transfer once", not "the file went up in one attempt".
const String publishTransferLegsMetric = 'transfer_legs';

/// Zone key the ambient [PublishTimeline] is stored under.
const Object _timelineZoneKey = #publishTimeline;

/// One finished phase of a publish.
typedef PublishPhase = ({String name, Duration elapsed});

/// Emits a single timing line for a phase that has just finished, and folds it
/// into the ambient [PublishTimeline] when one is running.
///
/// Free function so layers that do not own the [PublishTimeline] (the upload
/// pipeline) can contribute lines to the same filterable stream.
///
/// Pass [bytes] for a transferred payload; the size and rate are appended to
/// the line and the size is carried into the publish's metrics.
///
/// The timeline is found through the zone, so the metric half of this call is
/// invisible at the call site: a phase emitted off a call chain that did not
/// start inside [PublishTimeline.run] still logs its line but reports no
/// metric. The known emitters and where they sit:
///
/// - `UploadManager._performUploadInternal` (`upload.transfer`,
///   `upload.thumbnail*`) — inside the zone when the publish started the
///   upload, because `startUpload` awaits `_performUpload` on the publish's
///   own chain. **Outside** it when the publish joins an upload another chain
///   already had in flight — a session resumed at app start, or a retry the
///   recovery sweep kicked off. Those legs belong to whichever chain started
///   them, so attributing them to the publish that happened to wait would be
///   the wrong answer, not a missing one.
/// - `VideoEventPublisher` (`nostr.sign`, `nostr.publish`, `nostr.blurhash`) —
///   inside the zone when this publish signed its own event, because
///   `VideoPublishService` awaits `publishVideoEvent` directly. Outside it
///   when `publishDirectUpload` finds an event already in flight for the same
///   video and returns that future rather than signing a duplicate (#6018).
///   The slices then run in the first chain's zone, so the publish that joined
///   reports `nostr_ms` with nothing inside it.
///
/// A `Timer`, an isolate hop, or a future scheduled outside `run` would drop
/// the metric the same silent way. There is deliberately no assert for it:
/// the joined-upload case above is legitimate and would trip on every resumed
/// publish. `upload_ms` still covers the leg, so the console shows a duration
/// with no breakdown rather than nothing at all.
void logPublishPhase(
  String phase,
  Duration elapsed, {
  String? detail,
  int? bytes,
}) {
  _logPhaseLine(
    phase,
    elapsed,
    detail ?? (bytes == null ? null : formatTransferDetail(bytes, elapsed)),
  );
  PublishTimeline.current?._absorb(
    phase,
    elapsed,
    detail: detail,
    bytes: bytes,
  );
}

void _logPhaseLine(String phase, Duration elapsed, String? detail) {
  final suffix = (detail == null || detail.isEmpty) ? '' : ' $detail';
  Log.info(
    '⏱️ $publishTimingToken $phase ${elapsed.inMilliseconds}ms$suffix',
    name: publishTimingLogName,
    category: LogCategory.video,
  );
}

/// Formats a transferred payload as `8.20MB 1.63MB/s` for a timing line.
///
/// Returns an empty string when the size is unknown or zero, and omits the
/// rate when [elapsed] rounds to zero seconds.
String formatTransferDetail(int? bytes, Duration elapsed) {
  if (bytes == null || bytes <= 0) return '';
  final megabytes = bytes / (1024 * 1024);
  final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  if (seconds <= 0) return '${megabytes.toStringAsFixed(2)}MB';
  final rate = megabytes / seconds;
  return '${megabytes.toStringAsFixed(2)}MB ${rate.toStringAsFixed(2)}MB/s';
}

/// Collects the phase durations of one publish, emits a summary line, and
/// reports the same breakdown to Firebase Performance.
///
/// Phases are logged as they finish, so a publish that hangs still leaves the
/// completed phases in the log; the summary adds the total plus an `other`
/// bucket for everything not covered by a measured phase.
class PublishTimeline {
  PublishTimeline(this.draftId, {PerformanceTraceMonitor? performanceMonitor})
    : _trace = (performanceMonitor ?? const NoOpPerformanceTraceMonitor())
          .startOperationTrace(publishTraceName);

  /// The timeline of the publish currently running on this call chain, or null
  /// outside a [run].
  static PublishTimeline? get current =>
      Zone.current[_timelineZoneKey] as PublishTimeline?;

  /// Draft this publish belongs to — the join key between the timing lines and
  /// the surrounding upload logs.
  final String draftId;

  final PerformanceTrace _trace;

  final Stopwatch _total = Stopwatch()..start();
  final List<PublishPhase> _phases = <PublishPhase>[];

  /// Every phase heard of, summed per name. Unlike [_phases] this also holds
  /// the nested phases that [logPublishPhase] emits from inside the upload and
  /// Nostr legs, and it adds a retried phase's attempts together.
  final Map<String, Duration> _elapsedByPhase = <String, Duration>{};

  int? _payloadBytes;
  int _transferLegs = 0;

  /// Null until the leg ran at all, so a publish that failed before it reports
  /// no attribute rather than claiming work it never did.
  bool? _thumbnailReused;
  bool? _signatureReused;

  /// Phases recorded so far, in completion order.
  List<PublishPhase> get phases => List.unmodifiable(_phases);

  /// Wall-clock time since this timeline was created.
  Duration get total => _total.elapsed;

  /// Runs [action] with this timeline as the ambient one, so the phases the
  /// upload and Nostr legs emit through [logPublishPhase] land in this
  /// publish's metrics without threading the timeline through every layer in
  /// between. Legs kicked off outside this call chain (a background upload
  /// resumed from a previous session) simply report no metric.
  Future<T> run<T>(Future<T> Function() action) =>
      runZoned<Future<T>>(action, zoneValues: {_timelineZoneKey: this});

  /// Runs [action], recording its duration under [phase].
  ///
  /// The phase is recorded even when [action] throws, so a failed publish is
  /// still attributable; the error propagates unchanged.
  Future<T> measure<T>(String phase, Future<T> Function() action) async {
    final watch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      watch.stop();
      record(phase, watch.elapsed);
    }
  }

  /// Records an already-measured [phase] and logs its line.
  void record(String phase, Duration elapsed) {
    _phases.add((name: phase, elapsed: elapsed));
    _absorb(phase, elapsed);
    _logPhaseLine(phase, elapsed, null);
  }

  /// Folds a phase into the metric breakdown without touching the summary's
  /// top-level phase list.
  void _absorb(String phase, Duration elapsed, {String? detail, int? bytes}) {
    _elapsedByPhase[phase] =
        (_elapsedByPhase[phase] ?? Duration.zero) + elapsed;
    switch (phase) {
      case PublishPhases.uploadTransfer:
        _transferLegs++;
        if (bytes != null && bytes > 0) _payloadBytes = bytes;
      case PublishPhases.uploadThumbnail:
        _thumbnailReused = _reuseOf(_thumbnailReused, detail);
      case PublishPhases.nostrSign:
        _signatureReused = _reuseOf(_signatureReused, detail);
    }
  }

  /// Folds one attempt's [detail] into a leg's reuse flag.
  ///
  /// A leg that did real work once is reported as such even if a later attempt
  /// short-circuited, because its metric then carries that real work.
  static bool _reuseOf(bool? current, String? detail) =>
      (current ?? true) && detail == PublishPhases.reusedDetail;

  /// Builds the one-line summary for a publish that ended with [outcome].
  String summaryLine({required String outcome}) {
    final measured = _phases.fold(
      Duration.zero,
      (sum, phase) => sum + phase.elapsed,
    );
    final elapsed = _total.elapsed;
    final buffer = StringBuffer()
      ..write('⏱️ $publishTimingToken summary draft=$draftId ')
      ..write('outcome=$outcome total=${elapsed.inMilliseconds}ms');
    for (final phase in _phases) {
      buffer.write(' ${phase.name}=${phase.elapsed.inMilliseconds}ms');
    }
    buffer.write(' other=${(elapsed - measured).inMilliseconds}ms');
    return buffer.toString();
  }

  /// Logs [summaryLine] for a publish that ended with [outcome].
  void logSummary({required String outcome}) {
    Log.info(
      summaryLine(outcome: outcome),
      name: publishTimingLogName,
      category: LogCategory.video,
    );
  }

  /// Ends the timeline: logs the summary line and reports the same breakdown
  /// to Firebase Performance, tagged with [outcome] so a failed or abandoned
  /// publish is distinguishable from one that reached the relay.
  ///
  /// The trace is stopped fire-and-forget, so a publish never waits on a
  /// platform round-trip to return its result.
  void finish({required String outcome}) {
    logSummary(outcome: outcome);

    _total.stop();
    for (final entry in _elapsedByPhase.entries) {
      final metric = _metricByPhase[entry.key];
      if (metric != null) _trace.setMetric(metric, entry.value.inMilliseconds);
    }
    _trace.setMetric(publishTotalMetric, _total.elapsed.inMilliseconds);
    final payloadBytes = _payloadBytes;
    if (payloadBytes != null) {
      _trace.setMetric(publishPayloadMetric, payloadBytes);
    }
    if (_transferLegs > 0) {
      _trace.setMetric(publishTransferLegsMetric, _transferLegs);
    }
    _trace.putAttribute('outcome', outcome);
    _putReuseAttribute('thumbnail', _thumbnailReused, freshValue: 'generated');
    _putReuseAttribute(
      'signature',
      _signatureReused,
      freshValue: PublishPhases.signedDetail,
    );
    unawaited(_trace.stop());
  }

  /// Tags a leg as reused or freshly done, and says nothing at all about a leg
  /// that never ran — a metric near zero because the work was skipped must be
  /// filterable out of the distribution for the work itself.
  void _putReuseAttribute(
    String attribute,
    bool? reused, {
    required String freshValue,
  }) {
    if (reused == null) return;
    _trace.putAttribute(
      attribute,
      reused ? PublishPhases.reusedDetail : freshValue,
    );
  }
}
