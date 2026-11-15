// ABOUTME: Bounds one video DM attempt before publication and cancels its upload.
// ABOUTME: Publication owns its delivery result once the irreversible send starts.

import 'dart:async';

import 'package:dio/dio.dart';

/// Maximum silence between increases in the uploaded fraction.
const videoDmUploadInactivityTimeout = Duration(minutes: 2);

/// Preparation, encryption and upload may run for at most this long.
const videoDmPrePublicationTimeout = Duration(minutes: 30);

/// Maximum wait for the originating account's signer-backed session.
const videoDmSignerReadinessTimeout = Duration(minutes: 2);

/// Expected interruption of a video DM send, never a programming error.
class DmVideoSendCancelled implements Exception {
  const DmVideoSendCancelled(this.reason);

  final String reason;

  @override
  String toString() => 'DmVideoSendCancelled: $reason';
}

/// Cancellation shared by the outbox, send pipeline and Dio upload.
class DmVideoSendCancellation {
  DmVideoSendCancellation({
    this.uploadInactivityTimeout = videoDmUploadInactivityTimeout,
    Duration prePublicationTimeout = videoDmPrePublicationTimeout,
    this.signerReadinessTimeout = videoDmSignerReadinessTimeout,
    bool Function()? isAccountCurrent,
    DateTime Function()? now,
  }) : _isAccountCurrent = isAccountCurrent,
       _now = now ?? DateTime.now {
    _expiresAt = _now().add(prePublicationTimeout);
    _deadline = Timer(
      prePublicationTimeout,
      () => cancel('pre-publication deadline expired'),
    );
  }

  final Duration uploadInactivityTimeout;
  final Duration signerReadinessTimeout;
  final bool Function()? _isAccountCurrent;
  final DateTime Function() _now;
  late final DateTime _expiresAt;
  DateTime? _lastProgressAt;
  final CancelToken uploadCancelToken = CancelToken();
  final Completer<DmVideoSendCancelled> _cancelled = Completer();
  Timer? _deadline;
  Timer? _inactivity;
  double _highestProgress = 0;
  bool _publishing = false;
  bool _finished = false;

  bool get isActive => !_finished && !_cancelled.isCompleted;

  void throwIfCancelled() {
    _expireIfNeeded();
    if (!_publishing && !(_isAccountCurrent?.call() ?? true)) {
      cancel('originating account is no longer active');
    }
    if (_cancelled.isCompleted || _finished) {
      throw const DmVideoSendCancelled('attempt is no longer active');
    }
  }

  /// Releases the queue even if a native encrypt/sign operation settles late.
  /// Its pipeline still observes cancellation before upload and publication.
  Future<T> waitFor<T>(Future<T> work) => Future.any([
    work,
    _cancelled.future.then<T>((reason) => throw reason),
  ]);

  Future<void> waitForSigner(Future<void> readiness) async {
    final expiresAt = _now().add(signerReadinessTimeout);
    final timeout = Timer(
      signerReadinessTimeout,
      () => cancel('signer readiness deadline expired'),
    );
    try {
      await waitFor(readiness);
      if (!_now().isBefore(expiresAt)) {
        cancel('signer readiness deadline expired');
      }
      throwIfCancelled();
    } finally {
      timeout.cancel();
    }
  }

  void startUpload() {
    throwIfCancelled();
    if (_lastProgressAt == null) _resetInactivity();
  }

  /// Upload has settled; preview preparation is still bounded by the deadline.
  void finishUpload() {
    _inactivity?.cancel();
    _lastProgressAt = null;
  }

  void uploadProgress(double fraction) {
    _expireIfNeeded();
    if (!isActive || _publishing || !fraction.isFinite) return;
    if (fraction > _highestProgress) {
      _highestProgress = fraction;
      _resetInactivity();
    }
  }

  void _resetInactivity() {
    _lastProgressAt = _now();
    _inactivity?.cancel();
    _inactivity = Timer(
      uploadInactivityTimeout,
      () => cancel('upload stopped making progress'),
    );
  }

  // Timers can be delayed while the app is suspended. Check the same bounds
  // at progress and publication gates before accepting a resumed operation.
  void _expireIfNeeded() {
    if (!isActive || _publishing) return;
    final now = _now();
    if (!now.isBefore(_expiresAt)) {
      cancel('pre-publication deadline expired');
    } else if (_lastProgressAt case final last?) {
      if (now.difference(last) >= uploadInactivityTimeout) {
        cancel('upload stopped making progress');
      }
    }
  }

  /// Stop watchdogs before the repository starts an irreversible publish.
  void beginPublication() {
    throwIfCancelled();
    _publishing = true;
    _stopTimers();
  }

  void cancel(String reason) {
    if (!isActive || _publishing) return;
    _stopTimers();
    uploadCancelToken.cancel(reason);
    _cancelled.complete(DmVideoSendCancelled(reason));
  }

  void finish() {
    _finished = true;
    _stopTimers();
  }

  void _stopTimers() {
    _deadline?.cancel();
    _inactivity?.cancel();
  }
}
