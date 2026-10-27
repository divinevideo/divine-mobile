import 'dart:convert';

import 'package:challenge_protocol/challenge_protocol.dart';
import 'package:challenges_repository/challenges_repository.dart';

/// Versioned local storage only; not a backend API DTO.
abstract final class ChallengeRecordCodec {
  static Map<String, Object?> review(SubmissionReview review) => {
    'version': 1,
    'owner': review.owner,
    'definition': review.definition.toJson(),
    'video': review.video.toJson(),
    'fields': review.fields.toJson(),
    if (review.withdrawalEntry != null)
      'withdrawalEntry': review.withdrawalEntry!.toJson(),
  };

  static SubmissionReview readReview(Map<String, dynamic> value) {
    if (value['version'] != 1) {
      throw const FormatException('Unknown challenge journal version');
    }
    final fields = value['fields'] as Map<String, dynamic>;
    return SubmissionReview(
      owner: value['owner'] as String,
      definition: NostrEvent.fromJson(
        value['definition'] as Map<String, dynamic>,
      ),
      video: NostrEvent.fromJson(value['video'] as Map<String, dynamic>),
      fields: UnsignedChallengeAction(
        kind: fields['kind'] as int,
        createdAt: fields['created_at'] as int,
        content: fields['content'] as String,
        tags: (fields['tags'] as List<dynamic>)
            .map((tag) => (tag as List<dynamic>).cast<String>())
            .toList(),
      ),
      withdrawalEntry: value['withdrawalEntry'] == null
          ? null
          : NostrEvent.fromJson(
              value['withdrawalEntry'] as Map<String, dynamic>,
            ),
    );
  }

  static String action(PendingChallengeAction action) => jsonEncode({
    'version': 1,
    'review': review(action.review),
    'signedBody': action.signedBody,
    'challengeRelays': action.challengeRelays,
    'targets': action.targets,
    if (action.deliveryDefinition != null)
      'deliveryDefinition': action.deliveryDefinition!.toJson(),
    'outcomes': action.outcomes.map((key, value) => MapEntry(key, value.name)),
    'echoed': action.echoed,
    'indexed': action.indexed,
  });

  static PendingChallengeAction readAction(String body) {
    final value = jsonDecode(body) as Map<String, dynamic>;
    if (value['version'] != 1) {
      throw const FormatException('Unknown challenge journal version');
    }
    final restoredReview = readReview(value['review'] as Map<String, dynamic>);
    final definition = parseChallengeEvent(restoredReview.definition).value;
    final delivery = value['deliveryDefinition'] == null
        ? null
        : NostrEvent.fromJson(
            value['deliveryDefinition'] as Map<String, dynamic>,
          );
    final parsedDelivery = delivery == null
        ? null
        : parseChallengeEvent(delivery).value;
    if (definition is! ChallengeDefinition ||
        (delivery != null &&
            (parsedDelivery is! ChallengeDefinition ||
                parsedDelivery.coordinate != definition.coordinate))) {
      throw const FormatException('Invalid delivery definition');
    }
    final advertised = {
      ...definition.relays,
      if (parsedDelivery is ChallengeDefinition) ...parsedDelivery.relays,
    }.toList();
    if (jsonEncode(value['challengeRelays']) != jsonEncode(advertised)) {
      throw const FormatException('Invalid signed challenge relay authority');
    }
    return PendingChallengeAction(
      review: restoredReview,
      signedBody: value['signedBody'] as String,
      challengeRelays: advertised,
      deliveryDefinition: delivery,
      targets: (value['targets'] as List<dynamic>).cast<String>(),
      outcomes: (value['outcomes'] as Map<String, dynamic>).map(
        (key, value) =>
            MapEntry(key, RelayOutcome.values.byName(value as String)),
      ),
      echoed: value['echoed'] == true,
      indexed: value['indexed'] == true,
    );
  }
}
