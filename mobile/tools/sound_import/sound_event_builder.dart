// ABOUTME: Builds the unsigned Kind 1063 event for a prepared sound, in the tag
// ABOUTME: shape AudioEvent reads, plus the credit text in its content.

import 'audio_pipeline.dart';
import 'import_state.dart';
import 'sound_candidate.dart';

/// NIP-94 file metadata, the kind the app's sounds are.
const soundEventKind = 1063;

/// The unsigned event for [candidate], prepared as [record], whose file a
/// Blossom server at [blossomBase] serves by its hash.
///
/// The tags follow `AudioEvent.toTags` in the models package, which the
/// tool cannot import: models pulls in Flutter through nostr_sdk, and the
/// tool runs on the plain Dart VM. A test parses the result with
/// `AudioEvent.fromNostrEvent` so the two cannot drift apart.
///
/// [pubkey] may be empty: the signer fills it in. The event never carries an
/// `a` tag, which would make it a video's sound, nor `divine_sound`, which
/// only the app's shipped sounds have.
Map<String, Object?> buildUnsignedSoundEvent({
  required SoundCandidate candidate,
  required ImportRecord record,
  required String blossomBase,
  required int createdAt,
  String pubkey = '',
}) {
  final sha256 = record.outputSha256;
  if (record.status != ImportStatus.prepared || sha256 == null) {
    throw StateError('${candidate.id} is not prepared');
  }
  final base = blossomBase.endsWith('/')
      ? blossomBase.substring(0, blossomBase.length - 1)
      : blossomBase;
  final duration = record.durationSeconds;
  final isrc = candidate.isrc;
  final summary = candidate.summary;

  return {
    'kind': soundEventKind,
    'pubkey': pubkey,
    'created_at': createdAt,
    'tags': [
      ['url', '$base/$sha256'],
      ['m', preparedMimeType],
      ['x', sha256],
      if (record.outputBytes case final bytes?) ['size', '$bytes'],
      if (duration != null) ['duration', '${(duration * 1000).round() / 1000}'],
      ['title', candidate.title],
      ['source', candidate.sourcePage],
      ['allow_audio_reuse', 'true'],
      ['creator', candidate.creatorName],
      ['creator_url', candidate.creatorUrl],
      ['license', candidate.license.name],
      ['license_url', candidate.license.url],
      for (final tag in normalizeSearchTags([
        ?candidate.kind.kindTag,
        ...candidate.tags,
      ]))
        ['t', tag],
      // NIP-73's external content id, in the shape it gives ISBNs and
      // ISANs; ISRC is not in its table yet.
      if (isrc != null) ...[
        ['i', 'isrc:$isrc'],
        ['k', 'isrc'],
      ],
      if (summary != null) ['summary', summary],
      ['alt', 'Sound: ${candidate.title}'],
    ],
    'content': soundCreditContent(candidate, changes: record.changes),
  };
}

/// The readable credit in the event's `content`, in English like the app's
/// own (`audioEventCreditContent`): the published text must not depend on
/// who runs the import.
///
/// Says what preparing changed, as CC BY 4.0 §3(a)(1)(B) asks for an
/// adapted file.
String soundCreditContent(
  SoundCandidate candidate, {
  required List<String> changes,
}) {
  final credit = candidate.creditLines.isNotEmpty
      ? candidate.creditLines
      : [
          candidate.title,
          'Created by ${candidate.creatorName}',
          'License: ${candidate.license.name} (${candidate.license.url})',
        ];
  return [
    ...credit,
    'Source: ${candidate.sourcePage}',
    if (changes.isNotEmpty) 'Edited: ${changes.join(', ')}',
  ].join('\n');
}
