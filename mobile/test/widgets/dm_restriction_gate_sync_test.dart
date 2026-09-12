// ABOUTME: Tests DmRestrictionGateSync (#176): a DM-restriction flip is pumped
// ABOUTME: into the shared inbox gate's changes stream (list + badge re-filter).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/services/official_accounts_service.dart';
import 'package:openvine/widgets/dm_restriction_gate_sync.dart';

class _MockOfficials extends Mock implements OfficialAccountsService {}

void main() {
  late _MockOfficials officials;

  setUp(() {
    officials = _MockOfficials();
    when(
      () => officials.onVerdictChanged,
    ).thenAnswer((_) => const Stream<void>.empty());
  });

  group('sync behavior', () {
    testWidgets('a restriction flip ticks the shared inbox gate', (
      tester,
    ) async {
      final restricted = StateProvider<bool>((ref) => false);
      final container = ProviderContainer(
        overrides: [
          isDmRestrictedProvider.overrideWith((ref) => ref.watch(restricted)),
          officialAccountsServiceProvider.overrideWithValue(officials),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DmRestrictionGateSync(child: SizedBox.shrink()),
        ),
      );

      final gate = container.read(protectedMinorInboxGateProvider);
      final emissions = <void>[];
      final sub = gate.changes.listen(emissions.add);
      addTearDown(sub.cancel);

      // Mid-session flip (e.g. the account-review refresh confirms the account
      // protected). The settled inbox list and unread badge must get a tick.
      container.read(restricted.notifier).state = true;
      await tester.pump();
      expect(emissions, hasLength(1));

      // The flip back (age-up / revocation of protection) ticks again.
      container.read(restricted.notifier).state = false;
      await tester.pump();
      expect(emissions, hasLength(2));
    });

    testWidgets('an unchanged recompute does not tick', (tester) async {
      final restricted = StateProvider<bool>((ref) => true);
      final container = ProviderContainer(
        overrides: [
          isDmRestrictedProvider.overrideWith((ref) => ref.watch(restricted)),
          officialAccountsServiceProvider.overrideWithValue(officials),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DmRestrictionGateSync(child: SizedBox.shrink()),
        ),
      );

      final gate = container.read(protectedMinorInboxGateProvider);
      final emissions = <void>[];
      final sub = gate.changes.listen(emissions.add);
      addTearDown(sub.cancel);

      container.read(restricted.notifier).state = true; // same value
      await tester.pump();

      expect(emissions, isEmpty);
    });
  });

  group('renders', () {
    testWidgets('renders its child unchanged', (tester) async {
      final container = ProviderContainer(
        overrides: [
          isDmRestrictedProvider.overrideWithValue(false),
          officialAccountsServiceProvider.overrideWithValue(officials),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DmRestrictionGateSync(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text('child-content'),
            ),
          ),
        ),
      );

      expect(find.text('child-content'), findsOneWidget);
    });
  });
}
