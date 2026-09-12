// ABOUTME: Pins the app-shell wiring that keeps PeopleListsBloc pointed at a
// ABOUTME: live repository (#6480) — the bloc subscribes to a repository
// ABOUTME: stream, and a dependency flip must not remount anything below the
// ABOUTME: provider (the #4918 regression).

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/providers/provider_identity_stream.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

class _MockPeopleListsRepository extends Mock
    implements PeopleListsRepository {}

// Full-length Nostr pubkey — never truncated.
const String _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

/// Stand-in for `peopleListsRepositoryProvider`, whose real body watches
/// `nostrServiceProvider` and so returns a new instance on every identity
/// change. Tests flip `_selector` to reproduce that.
final _selector = StateProvider<PeopleListsRepository?>((_) => null);

final Provider<PeopleListsRepository> _repositoryProvider =
    Provider<PeopleListsRepository>((ref) {
      final selected = ref.watch(_selector);
      if (selected == null) throw StateError('no repository selected');
      return selected;
    });

final Provider<Stream<PeopleListsRepository>> _repositoryStreamProvider =
    identityStreamOf<PeopleListsRepository>(_repositoryProvider);

/// Stand-in for `isFeatureEnabledProvider(FeatureFlag.curatedLists)`, which the
/// app shell feeds to the bloc through `curatedListsEnabledStreamProvider`.
final _enabledSelector = StateProvider<bool>((_) => true);

final Provider<Stream<bool>> _enabledStreamProvider = identityStreamOf<bool>(
  _enabledSelector,
);

int _mountCount = 0;

/// Drains the bloc's event queue.
///
/// A swap deliberately emits no state (it must not flicker the UI) and hops
/// two event buckets — `PeopleListsRepositoryChanged` re-dispatches a
/// `PeopleListsOwnerChanged.rewire()`. Neither schedules a frame, so
/// `pumpAndSettle` returns before the handlers have run; explicit pumps flush
/// the microtasks that carry the events.
Future<void> _flipTo(
  WidgetTester tester,
  ProviderContainer container,
  PeopleListsRepository next,
) async {
  container.read(_selector.notifier).state = next;
  for (var i = 0; i < 10; i++) {
    await tester.pump();
  }
}

class _MountProbe extends StatefulWidget {
  const _MountProbe({required this.child});

  final Widget child;

  @override
  State<_MountProbe> createState() => _MountProbeState();
}

class _MountProbeState extends State<_MountProbe> {
  @override
  void initState() {
    super.initState();
    _mountCount += 1;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Mirrors `main.dart`'s app-shell wiring: the `BlocProvider` identity is
/// stable (no `ValueKey` — see #4918) and the bloc is handed the repository
/// *stream* rather than a single captured instance.
class _AppShellProbe extends ConsumerWidget {
  const _AppShellProbe({required this.ownerPubkeyStream});

  final Stream<String?> ownerPubkeyStream;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocProvider<PeopleListsBloc>(
      create: (_) => PeopleListsBloc(
        repository: ref.read(_repositoryProvider),
        repositoryStream: ref.read(_repositoryStreamProvider),
        enabledStream: ref.read(_enabledStreamProvider),
        ownerPubkeyStream: ownerPubkeyStream,
        initialOwnerPubkey: _owner,
      )..add(const PeopleListsStarted()),
      child: _MountProbe(
        child: BlocBuilder<PeopleListsBloc, PeopleListsState>(
          builder: (context, state) => Text(
            'lists=${state.lists.length}',
            textDirection: TextDirection.ltr,
          ),
        ),
      ),
    );
  }
}

void main() {
  group('app-shell repository sync', () {
    late _MockPeopleListsRepository first;
    late _MockPeopleListsRepository second;
    late StreamController<List<UserList>> firstLists;
    late StreamController<List<UserList>> secondLists;
    late StreamController<String?> ownerController;

    void stub(
      _MockPeopleListsRepository repository,
      StreamController<List<UserList>> lists,
    ) {
      when(
        () => repository.watchLists(ownerPubkey: any(named: 'ownerPubkey')),
      ).thenAnswer((_) => lists.stream);
      when(
        () => repository.syncOwner(ownerPubkey: any(named: 'ownerPubkey')),
      ).thenAnswer((_) async {});
    }

    setUp(() {
      _mountCount = 0;
      first = _MockPeopleListsRepository();
      second = _MockPeopleListsRepository();
      firstLists = StreamController<List<UserList>>.broadcast();
      secondLists = StreamController<List<UserList>>.broadcast();
      ownerController = StreamController<String?>.broadcast();
      stub(first, firstLists);
      stub(second, secondLists);
    });

    tearDown(() async {
      await firstLists.close();
      await secondLists.close();
      await ownerController.close();
    });

    testWidgets('a repository flip re-syncs without remounting descendants', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [_selector.overrideWith((_) => first)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _AppShellProbe(ownerPubkeyStream: ownerController.stream),
        ),
      );
      await tester.pumpAndSettle();

      expect(_mountCount, equals(1));
      clearInteractions(first);

      // The identity flip a sign-out -> sign-in produces.
      await _flipTo(tester, container, second);

      // Re-pointed: the new repository is driving the owner's lists.
      verify(() => second.syncOwner(ownerPubkey: _owner)).called(1);
      verifyNever(
        () => first.syncOwner(ownerPubkey: any(named: 'ownerPubkey')),
      );

      // And #4918's regression stays fixed: keying the BlocProvider on the
      // dependency would have remounted the whole subtree here.
      expect(_mountCount, equals(1));
    });

    // #6494. The flag flip has to stop the bloc's work from inside the bloc,
    // because the provider chain cannot change shape — a conditional entry
    // here is what #6477 removed.
    testWidgets('a curated-lists flag-off stops syncing', (tester) async {
      final container = ProviderContainer(
        overrides: [_selector.overrideWith((_) => first)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _AppShellProbe(ownerPubkeyStream: ownerController.stream),
        ),
      );
      await tester.pumpAndSettle();
      expect(firstLists.hasListener, isTrue);
      clearInteractions(first);

      container.read(_enabledSelector.notifier).state = false;
      for (var i = 0; i < 10; i++) {
        await tester.pump();
      }

      expect(firstLists.hasListener, isFalse);

      // A repository flip while the feature is off must not restart the sync.
      await _flipTo(tester, container, second);
      verifyNever(
        () => second.syncOwner(ownerPubkey: any(named: 'ownerPubkey')),
      );
      expect(secondLists.hasListener, isFalse);
    });

    testWidgets('renders lists from the swapped-in repository', (tester) async {
      final container = ProviderContainer(
        overrides: [_selector.overrideWith((_) => first)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _AppShellProbe(ownerPubkeyStream: ownerController.stream),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('lists=0'), findsOneWidget);

      await _flipTo(tester, container, second);

      secondLists.add([
        UserList(
          id: 'l1',
          name: 'Friends',
          pubkeys: const [],
          createdAt: DateTime.utc(2026, 7, 29),
          updatedAt: DateTime.utc(2026, 7, 29),
        ),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('lists=1'), findsOneWidget);
    });
  });
}
