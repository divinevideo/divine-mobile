// ABOUTME: Pure Dart ports for durable sound request fulfillment.
// ABOUTME: Isolates publication, account storage and DM transport.
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

/// Durable lifecycle state of a sound request.
enum SoundRequestStatus {
  /// Awaiting the creator's decision.
  pending,

  /// The request is persisted in the DM outbox.
  queued,

  /// Audio or video publication is in progress.
  publishing,

  /// Published metadata is awaiting current policy verification.
  awaitingPolicy,

  /// The published sound is available for reuse.
  ready,

  /// The creator dismissed this request locally.
  dismissed,

  /// An operation failed and can be retried.
  failed,
}

/// An expected sound request failure, such as an unavailable source video,
/// refused or pending delivery, or an account change mid-operation.
///
/// Unlike a [StateError], it marks no programming error, so the app logs it
/// without sending a crash report.
class SoundRequestException implements Exception {
  /// Creates an exception with a diagnostic [message].
  const SoundRequestException(this.message);

  /// Diagnostic description for logs.
  final String message;

  @override
  String toString() => 'SoundRequestException: $message';
}

/// Account-scoped DM history and durable outgoing delivery.
abstract interface class SoundRequestTransport {
  /// Watches persisted application messages across conversations.
  Stream<List<DmMessage>> watchMessages();

  /// Enqueues a stable rumor and returns its full event ID.
  Future<String> enqueue(SoundRequestSendIntent intent);

  /// Reads delivery state without driving or resetting outbox retries.
  Future<bool> isDelivered(String rumorId);

  /// Drives delivery, optionally refreshing the budget for an explicit retry.
  Future<void> retry(String rumorId, {bool resetRetryBudget = false});
}

/// A send policy rejected the intent before any durable DM was queued.
///
/// Unlike a transport failure, this must not be retried in the background.
class SoundRequestSendRefused extends SoundRequestException {
  /// Creates a terminal refusal without carrying message or account data.
  const SoundRequestSendRefused() : super('Sound request delivery refused');
}

/// Persistence boundary for account-specific request checkpoints.
abstract interface class SoundRequestStore {
  /// Reads the selected account's durable request snapshot.
  Future<SoundRequestSnapshot> read(String ownerPubkey);

  /// Persists a complete snapshot before the next external side effect.
  Future<void> write(String ownerPubkey, SoundRequestSnapshot snapshot);
}

/// Publication and current-consent boundary for source videos.
abstract interface class SoundRequestPublisher {
  /// Resolves the current video and its audio-sharing eligibility.
  Future<SoundRequestSource> resolve(String videoAddress);

  /// Publishes the source video's original audio and returns its event ID.
  Future<String> publishAudio(SoundRequestSource source);

  /// Replaces the latest video metadata with public reuse enabled.
  Future<void> enableReuse(SoundRequestSource source, String audioEventId);

  /// Checks current source linkage and action-time reuse permission.
  Future<bool> verifyReady(String videoAddress, String audioEventId);

  /// Returns the linked sound only after current permission validates.
  Future<AudioEvent?> resolveReady(String videoAddress, String audioEventId);
}

/// Latest source video and its current audio-sharing eligibility.
class SoundRequestSource {
  /// Creates this immutable value.
  const SoundRequestSource({
    required this.video,
    required this.allowReuse,
    required this.requestable,
    this.audioEventId,
  });

  /// Latest signed source video.
  final VideoEvent video;

  /// Whether current policy already permits public reuse.
  final bool allowReuse;

  /// Whether this source can be requested without overriding restrictions.
  final bool requestable;

  /// Full published Kind 1063 event ID, when known.
  final String? audioEventId;
}

/// A canonical request and its locally reconciled outcome.
class SoundRequestEntry extends Equatable {
  /// Creates this immutable value.
  const SoundRequestEntry({
    required this.id,
    required this.requester,
    required this.videoAddress,
    this.status = SoundRequestStatus.pending,
    this.audioEventId,
  });

  /// Restores a persisted value; malformed data throws.
  factory SoundRequestEntry.fromJson(Map<String, dynamic> json) =>
      SoundRequestEntry(
        id: json['id'] as String,
        requester: json['requester'] as String,
        videoAddress: json['videoAddress'] as String,
        status: SoundRequestStatus.values.byName(json['status'] as String),
        audioEventId: json['audioEventId'] as String?,
      );

  /// Canonical request rumor ID.
  final String id;

  /// Full public key of the person requesting the sound.
  final String requester;

  /// Full addressable coordinate of the source video.
  final String videoAddress;

  /// Persisted progress for this request.
  final SoundRequestStatus status;

  /// Full published Kind 1063 event ID, when known.
  final String? audioEventId;

  /// Whether this request is still awaiting a terminal creator outcome.
  bool get isPending =>
      status != SoundRequestStatus.ready &&
      status != SoundRequestStatus.dismissed;

  /// Returns an updated immutable value.
  SoundRequestEntry copyWith({
    SoundRequestStatus? status,
    String? audioEventId,
  }) => SoundRequestEntry(
    id: id,
    requester: requester,
    videoAddress: videoAddress,
    status: status ?? this.status,
    audioEventId: audioEventId ?? this.audioEventId,
  );

  /// Serializes this value for durable local storage.
  Map<String, dynamic> toJson() => {
    'id': id,
    'requester': requester,
    'videoAddress': videoAddress,
    'status': status.name,
    'audioEventId': audioEventId,
  };
  @override
  List<Object?> get props => [
    id,
    requester,
    videoAddress,
    status,
    audioEventId,
  ];
}

/// Persisted message input that reproduces a stable outbox rumor.
class SoundRequestSendIntent extends Equatable {
  /// Creates this immutable value.
  const SoundRequestSendIntent({
    required this.key,
    required this.recipient,
    required this.content,
    required this.tags,
    required this.createdAt,
    required this.videoAddress,
    this.requestId,
    this.rumorId,
  });

  /// Restores a persisted value; malformed data throws.
  factory SoundRequestSendIntent.fromJson(Map<String, dynamic> json) =>
      SoundRequestSendIntent(
        key: json['key'] as String,
        recipient: json['recipient'] as String,
        content: json['content'] as String,
        tags: (json['tags'] as List)
            .map((t) => (t as List).cast<String>())
            .toList(),
        createdAt: json['createdAt'] as int,
        videoAddress: json['videoAddress'] as String,
        requestId: json['requestId'] as String?,
        rumorId: json['rumorId'] as String?,
      );

  /// Stable account-scoped idempotency key.
  final String key;

  /// Full public key to which this intent is addressed.
  final String recipient;

  /// Readable fallback text, persisted unchanged across retries.
  final String content;

  /// Versioned structured tags, persisted unchanged across retries.
  final List<List<String>> tags;

  /// Fixed rumor timestamp in Unix seconds.
  final int createdAt;

  /// Full addressable coordinate of the source video.
  final String videoAddress;

  /// Full original request rumor ID, present on fulfillment replies.
  final String? requestId;

  /// Outbox rumor ID after enqueue succeeds.
  final String? rumorId;

  /// Records the stable rumor ID without altering its original inputs.
  SoundRequestSendIntent withRumor(String id) => SoundRequestSendIntent(
    key: key,
    recipient: recipient,
    content: content,
    tags: tags,
    createdAt: createdAt,
    videoAddress: videoAddress,
    requestId: requestId,
    rumorId: id,
  );

  /// Serializes this value for durable local storage.
  Map<String, dynamic> toJson() => {
    'key': key,
    'recipient': recipient,
    'content': content,
    'tags': tags,
    'createdAt': createdAt,
    'videoAddress': videoAddress,
    'requestId': requestId,
    'rumorId': rumorId,
  };
  @override
  List<Object?> get props => [
    key,
    recipient,
    content,
    tags,
    createdAt,
    videoAddress,
    requestId,
    rumorId,
  ];
}

/// Account-specific requests, publication checkpoints, and reply jobs.
class SoundRequestSnapshot extends Equatable {
  /// Creates this immutable value.
  const SoundRequestSnapshot({
    this.requests = const {},
    this.audioByVideo = const {},
    this.jobs = const {},
    this.approvedVideos = const {},
    this.metadataPublishedVideos = const {},
    this.metadataBaselineByVideo = const {},
  });

  /// Restores a persisted value; malformed data throws.
  factory SoundRequestSnapshot.fromJson(Map<String, dynamic> json) =>
      SoundRequestSnapshot(
        requests: (json['requests'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(
            k,
            SoundRequestEntry.fromJson(v as Map<String, dynamic>),
          ),
        ),
        audioByVideo: (json['audioByVideo'] as Map).cast<String, String>(),
        jobs: (json['jobs'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(
            k,
            SoundRequestSendIntent.fromJson(v as Map<String, dynamic>),
          ),
        ),
        approvedVideos: (json['approvedVideos'] as List).cast<String>().toSet(),
        metadataBaselineByVideo: (json['metadataBaselineByVideo'] as Map? ?? {})
            .cast<String, String>(),
        metadataPublishedVideos:
            (json['metadataPublishedVideos'] as List? ?? [])
                .cast<String>()
                .toSet(),
      );

  /// Requests indexed by canonical rumor ID.
  final Map<String, SoundRequestEntry> requests;

  /// Published audio checkpoints indexed by source video coordinate.
  final Map<String, String> audioByVideo;

  /// Durable outgoing intents indexed by idempotency key.
  final Map<String, SoundRequestSendIntent> jobs;

  /// Source coordinates explicitly approved by the current creator.
  final Set<String> approvedVideos;

  /// Signed source revision observed before each metadata attempt.
  final Map<String, String> metadataBaselineByVideo;

  /// Sources whose metadata replacement was acknowledged by relays.
  final Set<String> metadataPublishedVideos;

  /// Returns an updated immutable value.
  SoundRequestSnapshot copyWith({
    Map<String, SoundRequestEntry>? requests,
    Map<String, String>? audioByVideo,
    Map<String, SoundRequestSendIntent>? jobs,
    Set<String>? approvedVideos,
    Set<String>? metadataPublishedVideos,
    Map<String, String>? metadataBaselineByVideo,
  }) => SoundRequestSnapshot(
    requests: Map.unmodifiable(requests ?? this.requests),
    audioByVideo: Map.unmodifiable(audioByVideo ?? this.audioByVideo),
    jobs: Map.unmodifiable(jobs ?? this.jobs),
    approvedVideos: Set.unmodifiable(approvedVideos ?? this.approvedVideos),
    metadataBaselineByVideo: Map.unmodifiable(
      metadataBaselineByVideo ?? this.metadataBaselineByVideo,
    ),
    metadataPublishedVideos: Set.unmodifiable(
      metadataPublishedVideos ?? this.metadataPublishedVideos,
    ),
  );

  /// Serializes this value for durable local storage.
  Map<String, dynamic> toJson() => {
    'requests': requests.map((k, v) => MapEntry(k, v.toJson())),
    'audioByVideo': audioByVideo,
    'jobs': jobs.map((k, v) => MapEntry(k, v.toJson())),
    'approvedVideos': approvedVideos.toList(),
    'metadataPublishedVideos': metadataPublishedVideos.toList(),
    'metadataBaselineByVideo': metadataBaselineByVideo,
  };
  @override
  List<Object?> get props => [
    requests,
    audioByVideo,
    jobs,
    approvedVideos,
    metadataPublishedVideos,
    metadataBaselineByVideo,
  ];
}
