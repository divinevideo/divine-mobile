// ABOUTME: PROTOTYPE (#8076) — the inbox prototype's screen state: settings,
// ABOUTME: what the participant did this session, expanded reasons, and the
// ABOUTME: classification they produce, worked out once per change.

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_classifier.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_fixtures.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_prototype_session.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_prototype_settings.dart';

/// Everything the prototype screen renders.
class DmInboxPrototypeState extends Equatable {
  const DmInboxPrototypeState({
    required this.settings,
    required this.session,
    required this.explained,
    required this.classification,
  });

  final DmPrototypeSettings settings;

  /// What the participant has opened, replied to, marked or removed. Until a
  /// request is opened its preview text stays concealed.
  final DmPrototypeSession session;

  /// Conversation ids whose reasons are expanded.
  final Set<String> explained;

  /// The fixtures as [session] has changed them, each bucket newest first.
  final DmInboxClassification classification;

  /// Conversations still shown: deleted, reported and blocked ones are gone.
  int get conversationCount => DmInboxBucket.values.fold(
    0,
    (count, bucket) => count + classification.bucket(bucket).length,
  );

  @override
  List<Object?> get props => [settings, session, explained, classification];
}

/// Owns the prototype screen's state. Nothing here is published or stored.
class DmInboxPrototypeCubit extends Cubit<DmInboxPrototypeState> {
  DmInboxPrototypeCubit({required this.fixtures})
    : super(
        _stateFor(
          fixtures,
          settings: const DmPrototypeSettings(),
          session: const DmPrototypeSession(),
          explained: const {},
        ),
      );

  /// The synthetic conversations, senders and identities.
  final DmInboxFixtures fixtures;

  void reveal(String id) => _update(session: state.session.reveal(id));

  void toggleReasons(String id) => _update(
    explained: state.explained.contains(id)
        ? ({...state.explained}..remove(id))
        : {...state.explained, id},
  );

  /// Records a sent reply, which counts as consent.
  void reply(String id) => _update(session: state.session.reply(id));

  void markNotSpam(String id) =>
      _update(session: state.session.markNotSpam(id));

  /// Deletes, or reports and removes, a conversation.
  void remove(String id) => _update(session: state.session.remove(id));

  void block(String pubkey) => _update(session: state.session.block(pubkey));

  /// Applies saved tuning. A new presentation condition starts from the same
  /// state as every other one, so it clears the session and expanded reasons.
  void applySettings(DmPrototypeSettings settings) {
    final newCondition = settings.presentation != state.settings.presentation;
    _update(
      settings: settings,
      session: newCondition ? const DmPrototypeSession() : null,
      explained: newCondition ? const {} : null,
    );
  }

  void _update({
    DmPrototypeSettings? settings,
    DmPrototypeSession? session,
    Set<String>? explained,
  }) {
    emit(
      _stateFor(
        fixtures,
        settings: settings ?? state.settings,
        session: session ?? state.session,
        explained: explained ?? state.explained,
      ),
    );
  }

  static DmInboxPrototypeState _stateFor(
    DmInboxFixtures fixtures, {
    required DmPrototypeSettings settings,
    required DmPrototypeSession session,
    required Set<String> explained,
  }) {
    final classification = classifyPrototype(
      fixtures: fixtures,
      settings: settings,
      session: session,
    );
    return DmInboxPrototypeState(
      settings: settings,
      session: session,
      explained: Set.unmodifiable(explained),
      classification: DmInboxClassification(
        official: _newestFirst(classification.official),
        inbox: _newestFirst(classification.inbox),
        requests: _newestFirst(classification.requests),
        likelySpam: _newestFirst(classification.likelySpam),
        verdicts: classification.verdicts,
      ),
    );
  }

  static List<DmConversation> _newestFirst(List<DmConversation> rows) {
    final sorted = [...rows]
      ..sort((a, b) => b.effectiveTimestamp.compareTo(a.effectiveTimestamp));
    return List.unmodifiable(sorted);
  }
}
