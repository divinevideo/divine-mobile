import 'dart:convert';

import 'package:challenge_protocol/challenge_protocol.dart';
import 'package:challenges_repository/challenges_repository.dart';
import 'package:db_client/db_client.dart' show ChallengeOwnerRevoked;
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/models/challenge_recording_context.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/challenges/challenge_nostr_adapter.dart';
import 'package:openvine/services/challenges/sqlite_challenge_store.dart';

/// App-owned composition for a single owner session. Reads stay explicitly
/// known-relay-only. UI must review the successful exact video before submit.
class ChallengeAppSession {
  ChallengeAppSession({
    required this.store,
    required this.auth,
    required this.nostr,
    required bool Function(NostrEvent) isVisible,
    required bool Function(SubmissionReview) canPublish,
    required String? Function(NostrEvent) currentVideoId,
    Future<void> Function(NostrEvent)? refreshVideo,
  }) {
    adapter = ChallengeNostrAdapter(
      client: nostr,
      knownRelays: () => nostr.configuredRelays,
      challengeRelays: (coordinate) => _challengeRelays[coordinate] ?? const [],
      checkOwner: store.checkLive,
    );
    reads = ChallengesRepository(
      source: adapter.read,
      store: store,
      clock: () => DateTime.now().millisecondsSinceEpoch ~/ 1000,
      isVisible: isVisible,
      work: isolatedChallengeWork,
    );
    submissions = ChallengeSubmissionRepository(
      reads: reads,
      store: store,
      transport: adapter.publish,
      currentOwner: () {
        try {
          store.checkCurrent();
          return store.owner;
        } on ChallengeOwnerRevoked {
          return null;
        }
      },
      currentVideoId: currentVideoId,
      canPublish: canPublish,
      refreshVideo: refreshVideo,
      useReadDefinitions: (definitions) {
        final coordinate = definitions.first.coordinate;
        _challengeRelays[coordinate] = {
          for (final definition in definitions) ...definition.relays,
        }.toList();
      },
      writableRelays: () => nostr.writableRelays,
      sign: (fields) async {
        await store.checkLive();
        final wantsClient = await Nip89ClientTag.wantsClientTag(fields.kind);
        await store.checkLive();
        if (wantsClient != Nip89ClientTag.hasClientTag(fields.tags)) {
          throw const SubmissionException(SubmissionStatus.reviewRequired);
        }
        final event = await auth.createAndSignEvent(
          kind: fields.kind,
          content: fields.content,
          createdAt: fields.createdAt,
          tags: fields.tags.map((tag) => tag.toList()).toList(),
        );
        await store.checkLive();
        if (event == null) throw StateError('Challenge signer unavailable');
        // Choose the SDK's exact wire serialization once, before the durable
        // outbox insert. Delivery never normalizes an already-persisted body.
        return jsonEncode(event.toJson());
      },
    );
  }
  final _challengeRelays = <String, List<String>>{};
  final SqliteChallengeStore store;
  final AuthService auth;
  final NostrClient nostr;
  late final ChallengeNostrAdapter adapter;
  late final ChallengesRepository reads;
  late final ChallengeSubmissionRepository submissions;

  Future<ChallengeRecordingContext> prepareRecording({
    required String recordingId,
    required NostrEvent definition,
  }) async {
    await store.checkLive();
    final parsed = parseChallengeEvent(definition).value;
    if (parsed is! ChallengeDefinition) {
      throw const SubmissionException(SubmissionStatus.reviewRequired);
    }
    _challengeRelays[parsed.coordinate] = parsed.relays;
    final current = await reads.refresh(parsed.coordinate);
    await store.checkLive();
    if (!current.observation.revisionsComplete ||
        current.view.state != 'open' ||
        current.view.definition?.event.id != definition.id ||
        !reads.isVisible(definition)) {
      throw const SubmissionException(SubmissionStatus.reviewRequired);
    }
    final tags = await Nip89ClientTag.wantsClientTag(1111)
        ? [Nip89ClientTag.tag]
        : <List<String>>[];
    await store.checkLive();
    final context = ChallengeRecordingContext(
      owner: store.owner,
      generation: store.generation,
      definition: definition,
      recordingId: recordingId,
      clientTags: tags,
    );
    await store.writeRecord(
      'context',
      recordingId,
      jsonEncode(context.toJson()),
    );
    return context;
  }

  Future<ChallengeRecordingContext?> recording(String id) async {
    final body = await store.readRecord('context', id);
    if (body == null) return null;
    final context = ChallengeRecordingContext.fromJson(
      jsonDecode(body) as Map<String, dynamic>,
    );
    if (context.owner != store.owner ||
        context.generation != store.generation ||
        context.recordingId != id) {
      throw const ChallengeOwnerRevoked();
    }
    final parsed = parseChallengeEvent(context.definition).value;
    if (parsed is ChallengeDefinition) {
      _challengeRelays[parsed.coordinate] = parsed.relays;
    }
    return context;
  }

  /// Called only on PublishSuccess, before either source/publish draft cleanup.
  /// Failure leaves the video successful and the draft as recovery evidence.
  Future<void> recordPublished(
    DivineVideoDraft draft,
    String signedVideo,
  ) async {
    await store.checkLive();
    final context = draft.challengeContext;
    if (context == null) return;
    if (context.owner != store.owner ||
        context.generation != store.generation) {
      throw const ChallengeOwnerRevoked();
    }
    final persisted = await recording(context.recordingId);
    if (persisted == null ||
        jsonEncode(persisted.toJson()) != jsonEncode(context.toJson())) {
      throw const SubmissionException(SubmissionStatus.reviewRequired);
    }
    final video = NostrEvent.fromJson(
      jsonDecode(signedVideo) as Map<String, dynamic>,
    );
    if (video.pubkey != store.owner ||
        !const [21, 22, 34235, 34236].contains(video.kind)) {
      throw const SubmissionException(SubmissionStatus.ownerChanged);
    }
    await store.writeRecord(
      'handoff',
      context.recordingId,
      jsonEncode({
        'version': 1,
        'context': context.toJson(),
        'signedVideo': signedVideo,
        'draftId': draft.id,
        'sourceDraftId': draft.sourceDraftId,
      }),
    );
  }

  /// Recovery offers entry review/retry using the exact successful video. It
  /// cannot reach the video upload/signing pipeline or a scheduled event.
  Future<SubmissionReview> reviewPublished(String recordingId) async {
    final body = await store.readRecord('handoff', recordingId);
    if (body == null) {
      throw const SubmissionException(SubmissionStatus.reviewRequired);
    }
    final handoff = jsonDecode(body) as Map<String, dynamic>;
    final context = ChallengeRecordingContext.fromJson(
      handoff['context'] as Map<String, dynamic>,
    );
    if (context.owner != store.owner ||
        context.generation != store.generation) {
      throw const ChallengeOwnerRevoked();
    }
    final parsed = parseChallengeEvent(context.definition).value;
    if (parsed is ChallengeDefinition) {
      _challengeRelays[parsed.coordinate] = parsed.relays;
    }
    return submissions.prepareEntry(
      definition: context.definition,
      video: NostrEvent.fromJson(
        jsonDecode(handoff['signedVideo'] as String) as Map<String, dynamic>,
      ),
      clientTags: context.clientTags,
    );
  }
}
