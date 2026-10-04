// ABOUTME: Exercises one publication revision through forms, pickers and retries.
// ABOUTME: Uses real curated services, persisted cache and a deterministic relay.

import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/blocs/curated_list_info/curated_list_info_cubit.dart';
import 'package:openvine/blocs/select_list/select_list_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_sheet.dart';
import 'package:openvine/widgets/select_list_sheet/select_list_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/curated_list_publish_stubs.dart';
import '../helpers/test_provider_overrides.dart';

class _Client extends Mock implements NostrClient {}

CuratedListService? _visibleService;

class _SwappableServiceState extends CuratedListsState {
  @override
  CuratedListService? get service => _visibleService;
  @override
  Future<List<CuratedList>> build() async => _visibleService?.lists ?? const [];
}

const _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _other =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _collaborator =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _video =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const _secondVideo =
    'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

void main() {
  late _Client client;
  late AuthService auth;
  late SharedPreferences prefs;
  late CuratedListService service;
  late String activeOwner;
  late Map<String, Event> remote;
  late List<Event> sent;
  final instant = DateTime.utc(2026, 10, 4);

  void accept(Event event) {
    sent.add(event);
    if (event.kind == 30005) {
      final coordinate = '${event.pubkey}:${event.dTagValue}';
      final previous = remote[coordinate];
      if (previous == null ||
          event.createdAt > previous.createdAt ||
          (event.createdAt == previous.createdAt &&
              event.id.compareTo(previous.id) < 0)) {
        remote[coordinate] = event;
      }
    } else if (event.kind == 5) {
      for (final tag in event.tags) {
        if (tag.first == 'a') {
          final coordinate = tag[1].substring('30005:'.length);
          final previous = remote[coordinate];
          if (previous != null &&
              previous.pubkey == event.pubkey &&
              previous.createdAt <= event.createdAt) {
            remote.remove(coordinate);
          }
        } else if (tag.first == 'e') {
          remote.removeWhere(
            (_, value) =>
                value.id == tag[1] &&
                value.pubkey == event.pubkey &&
                value.createdAt <= event.createdAt,
          );
        }
      }
    }
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    client = _Client();
    auth = createMockAuthService(
      authState: AuthState.authenticated,
      currentPublicKeyHex: _owner,
    );
    activeOwner = _owner;
    remote = {};
    sent = [];
    stubListPublishing(client: client, auth: auth, pubkey: _owner);
    when(() => auth.currentPublicKeyHex).thenAnswer((_) => activeOwner);
    when(() => auth.isAuthenticated).thenReturn(true);
    when(
      () => auth.createAndSignEvent(
        kind: any(named: 'kind'),
        content: any(named: 'content'),
        tags: any(named: 'tags'),
        createdAt: any(named: 'createdAt'),
      ),
    ).thenAnswer(
      (i) async => Event(
        activeOwner,
        i.namedArguments[#kind] as int,
        i.namedArguments[#tags] as List<List<String>>,
        i.namedArguments[#content] as String,
        createdAt: i.namedArguments[#createdAt] as int?,
      ),
    );
    when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
      final event = i.positionalArguments.single as Event;
      accept(event);
      return acceptedOutcome(event);
    });
    when(() => client.publishEvent(any())).thenAnswer((i) async {
      final event = i.positionalArguments.single as Event;
      accept(event);
      return PublishSuccess(event: event);
    });
    when(() => client.subscribe(any(), onEose: any(named: 'onEose')))
        .thenAnswer((_) => const Stream.empty());
    service = CuratedListService(
      nostrService: client,
      authService: auth,
      prefs: prefs,
    );
    addTearDown(service.dispose);
  });

  Future<void> flip(String listId, {required bool isPublic}) async {
    final cubit = CuratedListInfoCubit(
      resolveService: () => service,
      currentOwnerPubkey: () => activeOwner,
      existingList: service.getListById(listId),
    );
    addTearDown(cubit.close);
    cubit.visibilityChanged(isPublic: isPublic);
    if (isPublic) {
      cubit.collaboratorsPicked(offered: const {}, picked: {_collaborator});
    }
    await cubit.submitted();
    expect(cubit.state.status, CuratedListInfoStatus.saved);
  }

  Future<void> toggleVideo(String listId, String video) async {
    final cubit = SelectListCubit(
      service: service,
      videoEventId: video,
      currentOwnerPubkey: () => activeOwner,
    );
    addTearDown(cubit.close);
    cubit.toggled(listId);
    expect(await cubit.submitted(), SelectListStatus.saved);
  }

  test(
    'fixed clock form rename visibility collaboration picker add remove delete '
    'advances remote and stored revisions without dropping metadata or private items',
    () async {
      await withClock(Clock.fixed(instant), () async {
        final list = (await service.createList(
          name: 'Original',
          description: 'Description',
          imageUrl: 'https://example.test/cover.jpg',
          tags: ['topic'],
          thumbnailEventId: _video,
          playOrder: PlayOrder.manual,
        ))!;
        final initialEvent = sent.last;
        final rename = CuratedListInfoCubit(
          resolveService: () => service,
          currentOwnerPubkey: () => activeOwner,
          existingList: list,
        );
        addTearDown(rename.close);
        rename.nameChanged('Renamed');
        await rename.submitted();
        expect(rename.state.status, CuratedListInfoStatus.saved);
        final coordinate = '$_owner:${list.id}';
        expect(
          CuratedListConverter.fromEvent(remote[coordinate]!)!.name,
          'Renamed',
        );
        await toggleVideo(list.id, _video);
        await flip(list.id, isPublic: false);
        final sealed = remote[coordinate]!;
        expect(unsealForTest(sealed.content), contains(_video));
        expect(sealed.tags.where((tag) => tag.first == 'e'), isEmpty);
        await toggleVideo(list.id, _secondVideo);
        expect(
          unsealForTest(remote[coordinate]!.content),
          contains(_secondVideo),
        );
        await flip(list.id, isPublic: true);
        final public = remote[coordinate]!;
        final publicList = CuratedListConverter.fromEvent(public)!;
        expect(publicList.allowedCollaborators, [_collaborator]);
        expect(publicList.videoEventIds, [_video, _secondVideo]);
        expect(publicList.tags, ['topic']);
        expect(publicList.imageUrl, 'https://example.test/cover.jpg');
        expect(publicList.description, 'Description');
        expect(publicList.thumbnailEventId, _video);
        expect(publicList.playOrder, PlayOrder.manual);
        await toggleVideo(list.id, _secondVideo);
        expect(
          CuratedListConverter.fromEvent(remote[coordinate]!)!.videoEventIds,
          [_video],
        );
        final stored = service.getListById(list.id)!;
        expect(stored.nostrEventId, remote[coordinate]!.id);
        expect(stored.updatedAt, remote[coordinate]!.createdAtDateTime);
        // A cached late public echo cannot undo the now-newer list revision.
        when(() => client.subscribe(any(), onEose: any(named: 'onEose')))
            .thenAnswer((_) => Stream.value(initialEvent));
        await service.fetchUserListsFromRelays(force: true);
        expect(service.getListById(list.id)!.name, 'Renamed');
        expect(service.getListById(list.id)!.allowedCollaborators, [
          _collaborator,
        ]);
        expect(await service.deleteOwnedList(list.id), isTrue);
        expect(remote[coordinate], isNull);
        expect(service.getListById(list.id), isNull);
        // Replayed relay copies do not resurrect a withdrawn coordinate.
        await service.fetchUserListsFromRelays(force: true);
        expect(service.getListById(list.id), isNull);
        var prior = instant.millisecondsSinceEpoch ~/ 1000 - 1;
        for (final event in sent) {
          expect(event.createdAt, greaterThan(prior));
          prior = event.createdAt;
        }
      });
    },
  );

  test(
    'queued unconfirmed send then service reload retry outranks delayed replay',
    () async {
      await withClock(Clock.fixed(instant), () async {
        final list = (await service.createList(
          name: 'Queue',
          isPublic: false,
        ))!;
        final old = remote['$_owner:${list.id}']!;
        Event? queued;
        when(() => client.publishEvent(any())).thenAnswer((i) async {
          queued = i.positionalArguments.single as Event;
          return const PublishFailed();
        });
        expect(await service.addVideoToList(list.id, _video), isFalse);
        final pending = service.getListById(list.id)!;
        expect(pending.pendingRepublish, isTrue);
        expect(pending.updatedAt, queued!.createdAtDateTime);
        when(() => client.publishEvent(any())).thenAnswer((i) async {
          final event = i.positionalArguments.single as Event;
          accept(event);
          return PublishSuccess(event: event);
        });
        when(() => client.subscribe(any(), onEose: any(named: 'onEose')))
            .thenAnswer((_) => Stream.value(old));
        final reloaded = CuratedListService(
          nostrService: client,
          authService: auth,
          prefs: prefs,
        );
        addTearDown(reloaded.dispose);
        await reloaded.fetchUserListsFromRelays(force: true);
        final retry = remote['$_owner:${list.id}']!;
        expect(retry.createdAt, greaterThan(queued!.createdAt));
        expect(
          reloaded.getListById(list.id)!.updatedAt,
          retry.createdAtDateTime,
        );
        expect(reloaded.getListById(list.id)!.pendingRepublish, isFalse);
        accept(queued!);
        expect(remote['$_owner:${list.id}']!.id, retry.id);
        expect(unsealForTest(retry.content), contains(_video));
      });
    },
  );

  test('queued rename observes prior accepted revision after blocked save completes', () async {
    await withClock(Clock.fixed(instant), () async {
      final list = (await service.createList(name: 'Original'))!;
      final gate = Completer<void>();
      Event? first;
      when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
        final event = i.positionalArguments.single as Event;
        if (first == null) {
          first = event;
          await gate.future;
        }
        accept(event);
        return acceptedOutcome(event);
      });
      final initialSave = service.updateList(
        listId: list.id,
        description: 'First',
      );
      for (var n = 0; first == null && n < 20; n++) {
        await pumpEventQueue();
      }
      final rename = service.updateList(listId: list.id, name: 'Later');
      await pumpEventQueue();
      expect(service.getListById(list.id)!.name, 'Original');
      gate.complete();
      expect(await initialSave, isTrue);
      expect(await rename, isTrue);
      final revisions = sent.where((e) => e.kind == 30005).toList();
      expect(revisions, hasLength(3));
      expect(revisions[2].createdAt, greaterThan(revisions[1].createdAt));
      final stored = service.getListById(list.id)!;
      expect(stored.updatedAt, revisions[2].createdAtDateTime);
      expect(stored.name, 'Later');
      expect(stored.description, 'First');
    });
  });

  test('signing completion after owner switch does not publish under another account', () async {
    final list = (await service.createList(name: 'Owned'))!;
    final gate = Completer<Event?>();
    Event? requested;
    when(
      () => auth.createAndSignEvent(
        kind: any(named: 'kind'),
        content: any(named: 'content'),
        tags: any(named: 'tags'),
        createdAt: any(named: 'createdAt'),
      ),
    ).thenAnswer((i) {
      requested = Event(
        _owner,
        i.namedArguments[#kind] as int,
        i.namedArguments[#tags] as List<List<String>>,
        i.namedArguments[#content] as String,
        createdAt: i.namedArguments[#createdAt] as int?,
      );
      return gate.future;
    });
    clearInteractions(client);
    final save = service.updateList(listId: list.id, name: 'Pending');
    for (var n = 0; requested == null && n < 20; n++) {
      await pumpEventQueue();
    }
    activeOwner = _other;
    gate.complete(requested);
    expect(await save, isFalse);
    verifyNever(() => client.publishEventAwaitOk(any()));
    verifyNever(() => client.publishEvent(any()));
    expect(service.myLists, isEmpty);
    expect(service.getListById(list.id)!.pubkey, _owner);
  });

  test(
    'out-of-budget source fails before signing and retains privacy and permissions',
    () async {
      await withClock(Clock.fixed(instant), () async {
        final list = (await service.createList(
          name: 'Team',
          isCollaborative: true,
          allowedCollaborators: [_collaborator],
        ))!;
        final future = list.copyWith(
          updatedAt: instant.add(const Duration(seconds: 60)),
          nostrEventId: 'f' * 64,
        );
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([future.toJson()]),
        );
        final reloaded = CuratedListService(
          nostrService: client,
          authService: auth,
          prefs: prefs,
        );
        addTearDown(reloaded.dispose);
        clearInteractions(client);
        Event? rejected;
        when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
          rejected = i.positionalArguments.single as Event;
          return rejectedOutcome(rejected!);
        });
        final cubit = CuratedListInfoCubit(
          resolveService: () => reloaded,
          currentOwnerPubkey: () => activeOwner,
          existingList: future,
        );
        addTearDown(cubit.close);
        cubit.visibilityChanged(isPublic: false);
        await cubit.submitted();
        expect(rejected, isNull);
        verifyNever(() => client.publishEventAwaitOk(any()));
        expect(cubit.state.status, CuratedListInfoStatus.failure);
        expect(reloaded.getListById(list.id)!.isPublic, isTrue);
        expect(reloaded.getListById(list.id)!.allowedCollaborators, [
          _collaborator,
        ]);
        expect(reloaded.getListById(list.id)!.pendingRepublish, isFalse);
        expect(
          reloaded.getListById(list.id)!.nostrEventId,
          future.nostrEventId,
        );
        verifyNever(() => client.publishEvent(any()));
        // A rejected privacy switch does not schedule backfill. Once clock
        // skew clears, a later explicit save and membership change still work.
        when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
          final event = i.positionalArguments.single as Event;
          accept(event);
          return acceptedOutcome(event);
        });
        await withClock(
          Clock.fixed(instant.add(const Duration(seconds: 120))),
          () async {
            await cubit.submitted();
            expect(cubit.state.status, CuratedListInfoStatus.saved);
            expect(reloaded.getListById(list.id)!.isPublic, isFalse);
            expect(
              reloaded.getListById(list.id)!.allowedCollaborators,
              isEmpty,
            );
            expect(reloaded.getListById(list.id)!.pendingRepublish, isFalse);
            expect(await reloaded.addVideoToList(list.id, _video), isTrue);
            expect(reloaded.getListById(list.id)!.videoEventIds, [_video]);
            expect(
              reloaded.getListById(list.id)!.updatedAt,
              remote['$_owner:${list.id}']!.createdAtDateTime,
            );
          },
        );
      });
    },
  );

  test('relay future rejection at the client boundary requires clock catch-up before retry', () async {
    await withClock(Clock.fixed(instant), () async {
      final list = (await service.createList(
        name: 'Team',
        isCollaborative: true,
        allowedCollaborators: [_collaborator],
      ))!;
      final source = list.copyWith(
        updatedAt: instant.add(const Duration(seconds: 59)),
        nostrEventId: 'f' * 64,
      );
      await prefs.setString(
        CuratedListService.listsStorageKey,
        jsonEncode([source.toJson()]),
      );
      final reloaded = CuratedListService(
        nostrService: client,
        authService: auth,
        prefs: prefs,
      );
      addTearDown(reloaded.dispose);
      clearInteractions(client);
      Event? rejected;
      when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
        rejected = i.positionalArguments.single as Event;
        return PublishOutcome(
          eventId: rejected!.id,
          acceptedBy: const [],
          rejectedBy: const {
            'wss://relay.test': 'invalid: timestamp too far in the future',
          },
          noResponseFrom: const [],
        );
      });
      final cubit = CuratedListInfoCubit(
        resolveService: () => reloaded,
        currentOwnerPubkey: () => activeOwner,
        existingList: source,
      );
      addTearDown(cubit.close);
      cubit.visibilityChanged(isPublic: false);
      await cubit.submitted();
      expect(rejected!.createdAt, instant.millisecondsSinceEpoch ~/ 1000 + 60);
      expect(reloaded.getListById(list.id)!.isPublic, isTrue);
      expect(reloaded.getListById(list.id)!.allowedCollaborators, [
        _collaborator,
      ]);
      clearInteractions(client);
      await withClock(
        Clock.fixed(instant.add(const Duration(seconds: 1))),
        cubit.submitted,
      );
      verifyNever(() => client.publishEventAwaitOk(any()));
      expect(cubit.state.status, CuratedListInfoStatus.failure);
      when(() => client.publishEventAwaitOk(any())).thenAnswer(
        (i) async => acceptedOutcome(i.positionalArguments.single as Event),
      );
      await withClock(
        Clock.fixed(instant.add(const Duration(seconds: 61))),
        cubit.submitted,
      );
      expect(cubit.state.status, CuratedListInfoStatus.saved);
      expect(reloaded.getListById(list.id)!.isPublic, isFalse);
      expect(reloaded.getListById(list.id)!.allowedCollaborators, isEmpty);
    });
  });

  testWidgets('UI form opened in owner A cannot rename owner B same d-tag list '
      'after current service/account replacement', (tester) async {
    late CuratedList original;
    late CuratedList other;
    late CuratedListService replacement;
    await withClock(Clock.fixed(instant), () async {
      original = (await service.createList(name: 'A title'))!;
      SharedPreferences.setMockInitialValues({});
      final otherPrefs = await SharedPreferences.getInstance();
      activeOwner = _other;
      replacement = CuratedListService(
        nostrService: client,
        authService: auth,
        prefs: otherPrefs,
      );
      addTearDown(replacement.dispose);
      other = (await replacement.createList(name: 'B title'))!;
    });
    expect(original.id, other.id);
    expect(original.pubkey, _owner);
    expect(other.pubkey, _other);
    activeOwner = _owner;
    _visibleService = service;
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testMaterialApp(
        mockAuthService: auth,
        additionalOverrides: [
          curatedListsStateProvider.overrideWith(_SwappableServiceState.new),
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  unawaited(showListInfoSheet(context, existingList: original)),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('A title'), findsOneWidget);
    activeOwner = _other;
    _visibleService = replacement;
    clearInteractions(client);
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.tap(find.bySemanticsLabel(l10n.listSave));
    await tester.pumpAndSettle();
    expect(replacement.getListById(other.id)!.name, 'B title');
    expect(service.getListById(original.id)!.name, 'A title');
    verifyNever(() => client.publishEventAwaitOk(any()));
    expect(find.text(l10n.listUpdateFailed), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(l10n.commonClose));
    await tester.pumpAndSettle();
  });

  for (final accepts in [false, true]) {
    testWidgets('late form save accepted=$accepts after account switch stays '
        'in A and does not notify or mutate B', (tester) async {
      late CuratedList original;
      late CuratedList other;
      late CuratedListService replacement;
      await withClock(Clock.fixed(instant), () async {
        original = (await service.createList(name: 'A title'))!;
        SharedPreferences.setMockInitialValues({});
        final otherPrefs = await SharedPreferences.getInstance();
        activeOwner = _other;
        replacement = CuratedListService(
          nostrService: client,
          authService: auth,
          prefs: otherPrefs,
        );
        addTearDown(replacement.dispose);
        other = (await replacement.createList(name: 'B title'))!;
      });
      expect(original.id, other.id);
      activeOwner = _owner;
      _visibleService = service;
      clearInteractions(client);
      final gate = Completer<PublishOutcome>();
      Event? pending;
      when(() => client.publishEventAwaitOk(any())).thenAnswer((i) {
        pending = i.positionalArguments.single as Event;
        return gate.future;
      });
      final outcomes = <ListInfoSheetOutcome>[];
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        testMaterialApp(
          mockAuthService: auth,
          additionalOverrides: [
            curatedListsStateProvider.overrideWith(_SwappableServiceState.new),
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => unawaited(
                  showListInfoSheet(
                    context,
                    existingList: original,
                  ).then<void>(outcomes.add),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Edited A');
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.bySemanticsLabel(l10n.listSave));
      await tester.pumpAndSettle();
      expect(pending, isNotNull);
      expect(pending!.pubkey, _owner);
      expect(find.bySemanticsLabel(l10n.listSave), findsNothing);
      activeOwner = _other;
      _visibleService = replacement;
      gate.complete(
        accepts ? acceptedOutcome(pending!) : rejectedOutcome(pending!),
      );
      await tester.pumpAndSettle();
      expect(replacement.getListById(other.id)!.name, 'B title');
      expect(service.getListById(original.id)!.pubkey, _owner);
      expect(service.getListById(original.id)!.name, 'Edited A');
      expect(find.text(l10n.listUpdateFailed), findsNothing);
      expect(outcomes, [ListInfoSheetOutcome.dismissed]);
      verify(() => client.publishEventAwaitOk(any())).called(1);
    });
  }

  testWidgets(
    'UI video picker refuses stale account picks without touching A or B',
    (tester) async {
      final original = (await service.createList(name: 'A list'))!;
      _visibleService = service;
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final video = VideoEvent(
        id: _video,
        pubkey: _owner,
        createdAt: instant.millisecondsSinceEpoch ~/ 1000,
        content: '',
        timestamp: instant,
        videoUrl: 'https://example.test/video.mp4',
      );
      await tester.pumpWidget(
        testMaterialApp(
          mockAuthService: auth,
          additionalOverrides: [
            curatedListsStateProvider.overrideWith(_SwappableServiceState.new),
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    unawaited(showSelectListSheet(context, video: video)),
                child: const Text('Open picker'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open picker'));
      await tester.pumpAndSettle();
      expect(find.text('A list'), findsOneWidget);
      await tester.tap(find.text('A list'));
      await tester.pump();
      activeOwner = _other;
      clearInteractions(client);
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.bySemanticsLabel(l10n.listDone));
      await tester.pumpAndSettle();
      expect(service.getListById(original.id)!.videoEventIds, isEmpty);
      expect(service.getListById(original.id)!.pubkey, _owner);
      verifyNever(() => client.publishEvent(any()));
      verifyNever(() => client.publishEventAwaitOk(any()));
      await tester.tap(find.bySemanticsLabel(l10n.commonClose));
      await tester.pumpAndSettle();
    },
  );
}
