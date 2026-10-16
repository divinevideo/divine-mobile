// ABOUTME: Durable request, creator approval and sound-ready reply lifecycle.
// ABOUTME: Separates audio/video checkpoints from idempotent DM outbox delivery.
import 'dart:async';

import 'package:dm_repository/src/sound_request_clients.dart';
import 'package:dm_repository/src/sound_request_message.dart';
import 'package:models/models.dart';

/// Coordinates sound requests through injected account-specific clients.
class SoundRequestsRepository {
  /// Creates an account-scoped request coordinator.
  SoundRequestsRepository({
    required this.ownerPubkey,
    required SoundRequestTransport transport,
    required SoundRequestStore store,
    required SoundRequestPublisher publisher,
    required String Function(String address) requestBody,
    required String Function(String address) readyBody,
    DateTime Function()? now,
  }) : _transport = transport,
       _store = store,
       _publisher = publisher,
       _requestBody = requestBody,
       _readyBody = readyBody,
       _now = now ?? DateTime.now;

  /// The account owning this lifecycle and its durable checkpoints.
  final String ownerPubkey;
  final SoundRequestTransport _transport;
  final SoundRequestStore _store;
  final SoundRequestPublisher _publisher;
  final String Function(String) _requestBody;
  final String Function(String) _readyBody;
  final DateTime Function() _now;
  final _changes = StreamController<SoundRequestSnapshot>.broadcast(sync: true);
  final _attemptedVideos = <String>{};
  final _reconciledRequests = <String>{};
  List<DmMessage>? _queuedHistory;
  bool _historyQueued = false;
  StreamSubscription<List<DmMessage>>? _subscription;
  Future<void> _tail = Future.value();
  SoundRequestSnapshot _state = const SoundRequestSnapshot();
  bool _closed = false;
  bool _started = false;

  /// Latest successfully persisted account state.
  SoundRequestSnapshot get state => _state;

  /// Replays current state, then follows committed updates and errors.
  Stream<SoundRequestSnapshot> watchState() => Stream.multi((listener) {
    listener.add(_state);
    final sub = _changes.stream.listen(
      listener.add,
      onError: listener.addError,
      onDone: listener.close,
    );
    listener.onCancel = sub.cancel;
  });

  Future<T> _run<T>(Future<T> Function() action) {
    final result = _tail.then((_) {
      _checkOpen();
      return action();
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _checkOpen() {
    if (_closed) throw const SoundRequestException('Sound requests closed');
  }

  void _report(Object error, StackTrace stack) {
    if (!_closed) _changes.addError(error, stack);
  }

  Future<void> _save(SoundRequestSnapshot value) async {
    _checkOpen();
    await _store.write(ownerPubkey, value);
    _checkOpen();
    _state = value;
    _changes.add(value);
  }

  /// Restores state and observes history without requiring an open DM screen.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _state = await _store.read(ownerPubkey);
    _checkOpen();
    _changes.add(_state);
    final first = Completer<void>();
    _subscription = _transport.watchMessages().listen(
      (messages) {
        // Every emission is the full history, so a pass already queued only
        // needs the newest one; a burst of DM writes must not stack passes
        // ahead of the user's own actions.
        _queuedHistory = messages;
        if (_historyQueued) return;
        _historyQueued = true;
        unawaited(
          _run(() async {
            _historyQueued = false;
            final history = _queuedHistory;
            _queuedHistory = null;
            if (history != null) await _ingest(history);
            if (!first.isCompleted) first.complete();
          }).catchError((Object error, StackTrace stack) {
            _report(error, stack);
            if (!first.isCompleted) first.complete();
          }),
        );
      },
      onError: (Object error, StackTrace stack) {
        _report(error, stack);
        if (!first.isCompleted) first.complete();
      },
      onDone: () {
        if (!first.isCompleted) first.complete();
      },
    );
    await first.future;
    await _tail;
  }

  /// Stops account work before the next external side effect.
  Future<void> close() async {
    _closed = true;
    await _subscription?.cancel();
    await _changes.close();
  }

  Future<void> _ingest(List<DmMessage> messages) async {
    final parsed = messages
        .map(
          (m) => parseSoundRequestMessage(
            m,
            ownerPubkey: ownerPubkey,
            isGroup: false,
          ),
        )
        .whereType<SoundRequestMessage>()
        .toList();
    final requests = Map<String, SoundRequestEntry>.of(_state.requests);
    for (final m in parsed.where(
      (m) => m.kind == SoundRequestMessageKind.request,
    )) {
      if (requests.containsKey(m.messageId)) continue;
      // Keep distinct signed requests: a later request can belong to a new
      // consent cycle even when its earlier ready reply arrives out of order.
      requests[m.messageId] = SoundRequestEntry(
        id: m.messageId,
        requester: m.senderPubkey,
        videoAddress: m.videoAddress,
      );
    }
    for (final m in parsed.where(
      (m) => m.kind == SoundRequestMessageKind.ready,
    )) {
      final request = requests[m.requestId];
      if (request != null &&
          request.videoAddress == m.videoAddress &&
          request.requester == m.recipientPubkey &&
          request.status != SoundRequestStatus.dismissed) {
        requests[request.id] = request.copyWith(
          status: SoundRequestStatus.ready,
          audioEventId: m.audioEventId,
        );
      }
    }
    if (!_sameRequests(requests)) {
      await _save(_state.copyWith(requests: requests));
    }
    try {
      await _drain();
    } on Object catch (e, s) {
      _report(e, s);
    }
    final pendingByAddress = <String, List<String>>{};
    for (final r in _state.requests.values) {
      if (r.requester != ownerPubkey &&
          r.status != SoundRequestStatus.dismissed &&
          r.status != SoundRequestStatus.ready) {
        (pendingByAddress[r.videoAddress] ??= []).add(r.id);
      }
    }
    for (final MapEntry(key: address, value: ids) in pendingByAddress.entries) {
      final approved = _state.approvedVideos.contains(address);
      // History re-emits on every DM write. An unapproved request is checked
      // against current reuse once per session; only the creator's own
      // approvals keep polling while policy indexing catches up.
      final unchecked = ids.where((id) => !_reconciledRequests.contains(id));
      try {
        if (approved && !_attemptedVideos.contains(address)) {
          await _publishFor(address);
        } else if (approved || unchecked.isNotEmpty) {
          final source = await _publisher.resolve(address);
          _checkOpen();
          _reconciledRequests.addAll(ids);
          if (source.allowReuse && source.audioEventId != null) {
            await _fulfill(address, source.audioEventId!);
            await _drain();
          }
        }
      } on Object catch (e, s) {
        _report(e, s);
      }
    }
  }

  bool _sameRequests(Map<String, SoundRequestEntry> requests) =>
      requests.length == _state.requests.length &&
      requests.entries.every((e) => _state.requests[e.key] == e.value);

  /// Resolves the source preview through the owning publication boundary.
  Future<VideoEvent> sourceVideo(String videoAddress) async {
    _checkOpen();
    final source = await _publisher.resolve(videoAddress);
    _checkOpen();
    return source.video;
  }

  /// Checks fresh eligibility without sending a message.
  Future<bool> canRequest(String videoAddress) async {
    _checkOpen();
    final creator = soundRequestCreator(videoAddress);
    if (creator == null || creator == ownerPubkey) return false;
    final source = await _publisher.resolve(videoAddress);
    _checkOpen();
    return source.requestable && !source.allowReuse;
  }

  /// Sends one request per source, joining an existing pending request.
  Future<String> request(String videoAddress) => _run(() async {
    final creator = soundRequestCreator(videoAddress);
    if (creator == null || creator == ownerPubkey) {
      throw StateError('Invalid sound request target');
    }
    final existing = _state.requests.values
        .where(
          (r) =>
              r.videoAddress == videoAddress &&
              r.requester == ownerPubkey &&
              r.isPending,
        )
        .firstOrNull;
    final pendingJob = _state.jobs.values
        .where((j) => j.videoAddress == videoAddress && j.requestId == null)
        .firstOrNull;
    if (pendingJob != null) {
      await _drain();
      return _state.requests.values
          .firstWhere(
            (r) =>
                r.videoAddress == videoAddress &&
                r.requester == ownerPubkey &&
                r.isPending,
          )
          .id;
    }
    if (existing != null) return existing.id;
    final source = await _publisher.resolve(videoAddress);
    _checkOpen();
    if (!source.requestable || source.allowReuse) {
      throw const SoundRequestException('Sound is not requestable');
    }
    final generation = _state.requests.values
        .where(
          (r) => r.videoAddress == videoAddress && r.requester == ownerPubkey,
        )
        .length;
    final intent = SoundRequestSendIntent(
      key: 'sound-request:$ownerPubkey:$videoAddress:$generation',
      recipient: creator,
      content: _requestBody(videoAddress),
      tags: soundRequestTags(videoAddress: videoAddress),
      createdAt: _now().millisecondsSinceEpoch ~/ 1000,
      videoAddress: videoAddress,
    );
    await _save(_state.copyWith(jobs: {..._state.jobs, intent.key: intent}));
    await _drain();
    return _state.requests.values
        .firstWhere(
          (r) =>
              r.videoAddress == videoAddress &&
              r.requester == ownerPubkey &&
              r.isPending,
        )
        .id;
  });

  /// Explicitly enables public sound reuse for the request's source video.
  Future<void> approve(String requestId) => _run(() async {
    final request = _state.requests[requestId];
    if (request == null ||
        soundRequestCreator(request.videoAddress) != ownerPubkey ||
        request.requester == ownerPubkey) {
      throw StateError('This account cannot approve the request');
    }
    if (request.status == SoundRequestStatus.ready) {
      await _drain();
      return;
    }
    await _save(
      _state.copyWith(
        approvedVideos: {..._state.approvedVideos, request.videoAddress},
        metadataPublishedVideos: {..._state.metadataPublishedVideos}
          ..remove(request.videoAddress),
        metadataBaselineByVideo: {..._state.metadataBaselineByVideo}
          ..remove(request.videoAddress),
        requests: {
          ..._state.requests,
          request.id: request.copyWith(status: SoundRequestStatus.publishing),
        },
      ),
    );
    await _publishFor(request.videoAddress);
  });

  Future<void> _publishFor(String address) async {
    _attemptedVideos.add(address);
    try {
      final source = await _publisher.resolve(address);
      _checkOpen();
      final checkpoint = _state.audioByVideo[address];
      final baseline = _state.metadataBaselineByVideo[address];
      if (baseline != null &&
          source.video.id != baseline &&
          !source.allowReuse &&
          !source.video.allowAudioReuse) {
        // A creator edit after the attempted publication invalidates its old
        // approval, including a crash between relay ACK and local checkpoint.
        // Require a new explicit approval against the current signed revision.
        await _save(
          _state.copyWith(
            approvedVideos: {..._state.approvedVideos}..remove(address),
            requests: {
              for (final entry in _state.requests.entries)
                entry.key:
                    entry.value.videoAddress == address && entry.value.isPending
                    ? entry.value.copyWith(status: SoundRequestStatus.pending)
                    : entry.value,
            },
          ),
        );
        return;
      }
      if (soundRequestCreator(address) == ownerPubkey &&
          checkpoint != null &&
          (_state.metadataPublishedVideos.contains(address) ||
              (source.audioEventId == checkpoint &&
                  (source.allowReuse || source.video.allowAudioReuse)))) {
        await _fulfill(address, checkpoint);
        await _drain();
        return;
      }
      if (soundRequestCreator(address) != ownerPubkey || !source.requestable) {
        throw const SoundRequestException('Video cannot enable sound reuse');
      }
      var audio = source.allowReuse
          ? source.audioEventId
          : _state.audioByVideo[address];
      if (audio == null) {
        audio = await _publisher.publishAudio(source);
        _checkOpen();
        await _save(
          _state.copyWith(
            audioByVideo: {..._state.audioByVideo, address: audio},
          ),
        );
      }
      if (!source.allowReuse || source.audioEventId != audio) {
        await _save(
          _state.copyWith(
            metadataBaselineByVideo: {
              ..._state.metadataBaselineByVideo,
              address: source.video.id,
            },
          ),
        );
        await _publisher.enableReuse(source, audio);
        _checkOpen();
        // An acknowledged replacement must never be replayed after a later
        // revocation, even while policy indexing has not caught up.
        await _save(
          _state.copyWith(
            metadataPublishedVideos: {
              ..._state.metadataPublishedVideos,
              address,
            },
          ),
        );
      }
      await _fulfill(address, audio);
      await _drain();
    } on Object {
      if (!_closed) {
        final requests = {
          for (final e in _state.requests.entries)
            e.key:
                e.value.videoAddress == address &&
                    e.value.status != SoundRequestStatus.dismissed &&
                    e.value.status != SoundRequestStatus.ready
                ? e.value.copyWith(status: SoundRequestStatus.failed)
                : e.value,
        };
        await _save(_state.copyWith(requests: requests));
      }
      rethrow;
    }
  }

  Future<void> _fulfill(String address, String audio) async {
    final valid = await _publisher.verifyReady(address, audio);
    _checkOpen();
    final requests = Map<String, SoundRequestEntry>.of(_state.requests);
    final jobs = Map<String, SoundRequestSendIntent>.of(_state.jobs);
    for (final request in requests.values.toList()) {
      if (request.videoAddress != address ||
          request.requester == ownerPubkey ||
          request.status == SoundRequestStatus.dismissed ||
          request.status == SoundRequestStatus.ready) {
        continue;
      }
      requests[request.id] = request.copyWith(
        status: valid
            ? SoundRequestStatus.ready
            : SoundRequestStatus.awaitingPolicy,
        audioEventId: audio,
      );
      if (valid) {
        final key = 'sound-ready:$ownerPubkey:${request.id}';
        jobs.putIfAbsent(
          key,
          () => SoundRequestSendIntent(
            key: key,
            recipient: request.requester,
            content: _readyBody(address),
            tags: soundReadyTags(
              videoAddress: address,
              requestId: request.id,
              audioEventId: audio,
            ),
            createdAt: _now().millisecondsSinceEpoch ~/ 1000,
            videoAddress: address,
            requestId: request.id,
          ),
        );
      }
    }
    final approvals = Set<String>.of(_state.approvedVideos);
    final checkpoints = Map<String, String>.of(_state.audioByVideo);
    final published = Set<String>.of(_state.metadataPublishedVideos);
    final baselines = Map<String, String>.of(_state.metadataBaselineByVideo);
    if (valid) {
      approvals.remove(address);
      checkpoints.remove(address);
      published.remove(address);
      baselines.remove(address);
    }
    await _save(
      _state.copyWith(
        requests: requests,
        jobs: jobs,
        approvedVideos: approvals,
        audioByVideo: checkpoints,
        metadataPublishedVideos: published,
        metadataBaselineByVideo: baselines,
      ),
    );
  }

  Future<void> _drain() async {
    Object? failure;
    StackTrace? failureStack;
    for (final original in _state.jobs.values.toList()) {
      try {
        _checkOpen();
        var intent = original;
        final id = intent.rumorId ?? await _transport.enqueue(intent);
        _checkOpen();
        if (intent.rumorId == null) {
          intent = intent.withRumor(id);
          final requests = Map<String, SoundRequestEntry>.of(_state.requests);
          if (intent.requestId == null) {
            requests[id] = SoundRequestEntry(
              id: id,
              requester: ownerPubkey,
              videoAddress: intent.videoAddress,
              status: SoundRequestStatus.queued,
            );
          }
          await _save(
            _state.copyWith(
              jobs: {..._state.jobs, intent.key: intent},
              requests: requests,
            ),
          );
        }
        await _transport.retry(id);
        _checkOpen();
        final jobs = Map<String, SoundRequestSendIntent>.of(_state.jobs)
          ..remove(intent.key);
        final requests = Map<String, SoundRequestEntry>.of(_state.requests);
        if (intent.requestId == null) {
          requests[id] = requests[id]!.copyWith(
            status: SoundRequestStatus.pending,
          );
        }
        await _save(_state.copyWith(jobs: jobs, requests: requests));
      } on Object catch (e, s) {
        failure = e;
        failureStack = s;
      }
    }
    if (failure != null) Error.throwWithStackTrace(failure, failureStack!);
  }

  /// Locally dismisses an incoming request without changing public permission.
  Future<void> dismiss(String requestId) => _run(() async {
    final request = _state.requests[requestId];
    if (request == null ||
        soundRequestCreator(request.videoAddress) != ownerPubkey) {
      throw StateError('Invalid dismissal');
    }
    final requests = {
      ..._state.requests,
      requestId: request.copyWith(status: SoundRequestStatus.dismissed),
    };
    final approvals = Set<String>.of(_state.approvedVideos);
    if (!requests.values.any(
      (r) =>
          r.videoAddress == request.videoAddress &&
          r.requester != ownerPubkey &&
          r.isPending,
    )) {
      approvals.remove(request.videoAddress);
    }
    await _save(_state.copyWith(requests: requests, approvedVideos: approvals));
  });

  /// Resumes the relevant publication or previously enqueued outgoing job.
  Future<void> retry(String requestId) => _run(() async {
    final request = _state.requests[requestId];
    if (request == null) throw StateError('Unknown sound request');
    if (request.requester == ownerPubkey) {
      await _drain();
      return;
    }
    if (request.status == SoundRequestStatus.ready) {
      await _drain();
      return;
    }
    if (!_state.approvedVideos.contains(request.videoAddress)) {
      throw StateError('Request has not been approved');
    }
    await _publishFor(request.videoAddress);
  });

  /// Resolves a fulfilled sound only when source and current permission agree.
  Future<AudioEvent?> resolveReady(SoundRequestMessage message) async {
    _checkOpen();
    final request = _state.requests[message.requestId];
    if (message.kind != SoundRequestMessageKind.ready ||
        request == null ||
        request.requester != ownerPubkey ||
        request.videoAddress != message.videoAddress ||
        message.senderPubkey != soundRequestCreator(request.videoAddress) ||
        message.audioEventId == null) {
      return null;
    }
    final audio = await _publisher.resolveReady(
      message.videoAddress,
      message.audioEventId!,
    );
    _checkOpen();
    return audio;
  }
}
