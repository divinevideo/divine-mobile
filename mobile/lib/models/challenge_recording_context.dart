import 'package:challenge_protocol/challenge_protocol.dart';

/// Reviewed rules carried through recording, autosave and publish copies.
/// This is not consent to sign an entry: its exact video is reviewed only
/// after publication. Unrelated duplication deliberately retires this context.
class ChallengeRecordingContext {
  ChallengeRecordingContext({
    required this.owner,
    required this.generation,
    required this.definition,
    required this.recordingId,
    required List<List<String>> clientTags,
  }) : clientTags = List.unmodifiable(
         clientTags.map(List<String>.unmodifiable),
       );
  final String owner;
  final String generation;
  final NostrEvent definition;
  final String recordingId;
  final List<List<String>> clientTags;

  factory ChallengeRecordingContext.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unknown challenge recording version');
    }
    return ChallengeRecordingContext(
      owner: json['owner'] as String,
      generation: json['generation'] as String,
      definition: NostrEvent.fromJson(
        json['definition'] as Map<String, dynamic>,
      ),
      recordingId: json['recordingId'] as String,
      clientTags: (json['clientTags'] as List<dynamic>)
          .map((tag) => (tag as List<dynamic>).cast<String>())
          .toList(),
    );
  }
  Map<String, Object?> toJson() => {
    'version': 1,
    'owner': owner,
    'generation': generation,
    'definition': definition.toJson(),
    'recordingId': recordingId,
    'clientTags': clientTags,
  };
}
