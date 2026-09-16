// ABOUTME: Tests the real ProtectedMinorInboxGate (#176): pass-through when not
// ABOUTME: restricted, all-approved filtering when restricted, receive-time
// ABOUTME: revalidation kick, and the changes stream forwarding.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation_list/protected_minor_inbox_gate_impl.dart';
import 'package:openvine/services/official_accounts_service.dart';

class _MockOfficials extends Mock implements OfficialAccountsService {}

void main() {
  final self = 'aa' * 32;
  final approved = 'bb' * 32;
  final blocked = 'cc' * 32;

  late _MockOfficials officials;

  setUp(() {
    officials = _MockOfficials();
    when(
      () => officials.isApprovedMinorDmRecipient(any()),
    ).thenAnswer((_) async => true);
    when(
      () => officials.isReadableByProtectedMinor(approved),
    ).thenReturn(true);
    when(
      () => officials.isReadableByProtectedMinor(blocked),
    ).thenReturn(false);
    when(
      () => officials.onVerdictChanged,
    ).thenAnswer((_) => const Stream<void>.empty());
  });

  DmConversation conv(String id, List<String> participants) => DmConversation(
    id: id,
    participantPubkeys: participants,
    isGroup: participants.length > 2,
    createdAt: 1700000000,
  );

  ProtectedMinorInboxGateImpl build({required bool restricted}) =>
      ProtectedMinorInboxGateImpl(
        isRestricted: () => restricted,
        officials: officials,
      );

  group('filter', () {
    test('not restricted -> pass-through, no revalidation', () {
      final gate = build(restricted: false);
      final input = [
        conv('a', [self, approved]),
        conv('b', [self, blocked]),
      ];

      final out = gate.filter(input, userPubkey: self);

      expect(out, equals(input));
      verifyNever(() => officials.isApprovedMinorDmRecipient(any()));
    });

    test('restricted -> keeps only all-approved conversations', () {
      final gate = build(restricted: true);
      final out = gate.filter([
        conv('a', [self, approved]),
        conv('b', [self, blocked]),
      ], userPubkey: self);

      expect(out.map((c) => c.id).toList(), ['a']);
    });

    test(
      'restricted group hidden unless every non-self participant approved',
      () {
        final gate = build(restricted: true);
        final out = gate.filter([
          conv('g', [self, approved, blocked]),
        ], userPubkey: self);

        expect(out, isEmpty);
      },
    );

    test(
      'restricted -> a conversation with no non-self counterparty is hidden '
      '(fail-closed on the empty set, matching the route guard)',
      () {
        // `every`-style approval is vacuously true on an empty counterparty set,
        // so a self-only / degenerate row would otherwise stay visible while the
        // conversation_page route guard bounces entry to it. Fail closed.
        final gate = build(restricted: true);
        final out = gate.filter([
          conv('selfonly', [self]),
          conv('empty', <String>[]),
          conv('ok', [self, approved]),
        ], userPubkey: self);

        expect(out.map((c) => c.id).toList(), ['ok']);
      },
    );

    test(
      'restricted -> kicks receive-time revalidation for counterparties',
      () async {
        final gate = build(restricted: true);
        gate.filter([
          conv('a', [self, approved]),
        ], userPubkey: self);

        await Future<void>.delayed(Duration.zero);
        verify(() => officials.isApprovedMinorDmRecipient(approved)).called(1);
        // self is never revalidated
        verifyNever(() => officials.isApprovedMinorDmRecipient(self));
      },
    );
  });

  group('changes', () {
    test('changes forwards the service verdict-change stream', () async {
      final controller = StreamController<void>.broadcast();
      addTearDown(controller.close);
      when(
        () => officials.onVerdictChanged,
      ).thenAnswer((_) => controller.stream);

      final gate = build(restricted: true);

      final expectation = expectLater(gate.changes, emits(null));
      controller.add(null);
      await expectation;
    });

    test(
      'changes also emits on notifyRestrictionChanged, so a settled list '
      're-filters without waiting for the next DM event',
      () async {
        final gate = build(restricted: true);
        addTearDown(gate.dispose);

        final emissions = <void>[];
        final sub = gate.changes.listen(emissions.add);
        addTearDown(sub.cancel);

        gate.notifyRestrictionChanged();
        await Future<void>.delayed(Duration.zero);

        expect(emissions, hasLength(1));
      },
    );

    test(
      'changes merges both sources (verdict flips AND restriction flips)',
      () async {
        final verdicts = StreamController<void>.broadcast();
        addTearDown(verdicts.close);
        when(
          () => officials.onVerdictChanged,
        ).thenAnswer((_) => verdicts.stream);
        final gate = build(restricted: true);
        addTearDown(gate.dispose);

        final emissions = <void>[];
        final sub = gate.changes.listen(emissions.add);
        addTearDown(sub.cancel);

        verdicts.add(null);
        gate.notifyRestrictionChanged();
        await Future<void>.delayed(Duration.zero);

        expect(emissions, hasLength(2));
      },
    );
  });

  group('notifyRestrictionChanged', () {
    test('notifyRestrictionChanged after dispose is a safe no-op', () {
      final gate = build(restricted: true);
      gate.dispose();

      expect(gate.notifyRestrictionChanged, returnsNormally);
    });
  });
}
