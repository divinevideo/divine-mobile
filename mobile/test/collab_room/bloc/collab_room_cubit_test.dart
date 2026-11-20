import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:bloc_test/bloc_test.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show DmFileMetadata, DmMessage;
import 'package:openvine/collab_room/bloc/collab_room_cubit.dart';
import 'package:openvine/collab_room/collab_room_composer.dart';
import 'package:openvine/collab_room/collab_room_layout.dart';
import 'package:openvine/collab_room/collab_room_service.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/split_screen_layout.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

class _MockCollabRoomService extends Mock implements CollabRoomService {}

const _author =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _sam = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _kai = 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _roomId = '0123456789abcdef0123456789abcdef';

const _metadata = DmFileMetadata(
  fileType: 'video/mp4',
  encryptionAlgorithm: 'aes-gcm',
  decryptionKey: 'key',
  decryptionNonce: 'nonce',
  fileHash: '2222222222222222222222222222222222222222222222222222222222222222',
);

var _nextId = 0;
String _eventId() => (++_nextId).toRadixString(16).padLeft(64, '0');

DmMessage _message({
  required String from,
  required String to,
  required CollabRoomMessageType type,
  CollabRoomSnapshot? snapshot,
  int createdAt = 1,
}) => DmMessage(
  id: _eventId(),
  conversationId: DmRepository.computeConversationId([from, to]),
  senderPubkey: from,
  content: type == CollabRoomMessageType.part
      ? 'https://media.example/$from'
      : 'text',
  createdAt: createdAt,
  giftWrapId: _eventId(),
  messageKind: type == CollabRoomMessageType.part ? 15 : 14,
  fileMetadata: type == CollabRoomMessageType.part ? _metadata : null,
  tags: collabRoomTags(
    roomId: _roomId,
    type: type,
    recipientPubkey: to,
    snapshot: snapshot,
  ),
);

CollabRoomMember _member(
  String pubkey,
  CollabRoomMemberStatus status, [
  int? cell,
]) => CollabRoomMember(pubkey: pubkey, status: status, cell: cell);

/// The author's view of a room published as [snapshot], plus [messages]
/// members sent since.
CollabRoom _room(
  CollabRoomSnapshot snapshot, {
  List<DmMessage> messages = const [],
  String owner = _author,
}) => foldCollabRooms([
  _message(
    from: _author,
    to: owner == _author ? _sam : owner,
    type: CollabRoomMessageType.invite,
    snapshot: snapshot,
  ),
  // A member's device counts them in only once they said so.
  if (owner != _author &&
      snapshot.members.any(
        (m) => m.pubkey == owner && m.status == CollabRoomMemberStatus.joined,
      ))
    _message(
      from: owner,
      to: _author,
      type: CollabRoomMessageType.join,
    ),
  ...messages,
], ownerPubkey: owner).single;

final _lobby = CollabRoomSnapshot(
  revision: 1,
  phase: CollabRoomPhase.lobby,
  members: [
    _member(_author, .joined),
    _member(_sam, .joined),
    _member(_kai, .invited),
  ],
);

final _recording = CollabRoomSnapshot(
  revision: 2,
  phase: CollabRoomPhase.recording,
  layout: SplitScreenLayoutPreset.sideBySide.name,
  members: [
    _member(_author, .joined, 0),
    _member(_sam, .joined, 1),
    _member(_kai, .removed),
  ],
  parts: const [
    CollabRoomPart(
      pubkey: _author,
      url: 'https://media.example/author',
      metadata: DmFileMetadata(
        fileType: 'video/mp4',
        encryptionAlgorithm: 'aes-gcm',
        decryptionKey: 'key',
        decryptionNonce: 'nonce',
        fileHash:
            '3333333333333333333333333333333333333333333333333333333333333333',
      ),
    ),
    CollabRoomPart(
      pubkey: _sam,
      url: 'https://media.example/$_sam',
      metadata: _metadata,
    ),
  ],
);

void main() {
  group(CollabRoomCubit, () {
    late _MockCollabRoomService service;
    late StreamController<CollabRoom?> rooms;
    late List<CollabRoomSnapshot> published;
    late List<List<CollabRoomComposeCell>> composed;
    late List<Color> composedBackgrounds;
    late List<List<CollabRoomSeriesPart>> composedSeries;

    setUpAll(() {
      registerFallbackValue(_lobby);
      registerFallbackValue(_room(_lobby));
      registerFallbackValue(_recording.parts.first);
    });

    setUp(() {
      service = _MockCollabRoomService();
      rooms = StreamController<CollabRoom?>();
      published = [];
      composed = [];
      composedBackgrounds = [];
      composedSeries = [];
      when(() => service.watchRoom(_roomId)).thenAnswer((_) => rooms.stream);
      when(() => service.publish(any(), any())).thenAnswer((invocation) async {
        published.add(invocation.positionalArguments[1] as CollabRoomSnapshot);
      });
      when(
        () => service.partFile(_roomId, any()),
      ).thenAnswer(
        (invocation) async => File(
          '/parts/${(invocation.positionalArguments[1] as CollabRoomPart).fileHash}.mp4',
        ),
      );
      when(() => service.deleteRoomFiles(_roomId)).thenAnswer((_) async {});
      when(() => service.join(any())).thenAnswer((_) async {});
      when(() => service.decline(any())).thenAnswer((_) async {});
      when(() => service.leave(any())).thenAnswer((_) async {});
    });

    tearDown(() => rooms.close());

    /// Lets the first of two publishes finish, in a test that holds it.
    late void Function() sendFirst;

    CollabRoomCubit build({
      bool keepsRoomInSync = true,
      Duration syncRetryDelay = const Duration(seconds: 5),
    }) => CollabRoomCubit(
      service: service,
      roomId: _roomId,
      keepsRoomInSync: keepsRoomInSync,
      lobbyPublishDelay: Duration.zero,
      syncRetryDelay: syncRetryDelay,
      thumbnailer: (path) async => '$path.jpg',
      composer:
          ({
            required cells,
            required aspectRatio,
            required backgroundColor,
            required taskId,
          }) async {
            composed.add(cells);
            composedBackgrounds.add(backgroundColor);
            return DivineVideoClip(
              id: 'composed',
              video: EditorVideo.file(File('/composed.mp4')),
              duration: const Duration(seconds: 6),
              recordedAt: DateTime(2026),
              targetAspectRatio: aspectRatio,
              originalAspectRatio: aspectRatio.value,
            );
          },
      seriesComposer:
          ({required parts, required aspectRatio, required taskId}) async {
            composedSeries.add(parts);
            return DivineVideoClip(
              id: 'series',
              video: EditorVideo.file(File('/series.mp4')),
              duration: const Duration(seconds: 6),
              recordedAt: DateTime(2026),
              targetAspectRatio: aspectRatio,
              originalAspectRatio: aspectRatio.value,
            );
          },
    );

    group('watching the room', () {
      blocTest<CollabRoomCubit, CollabRoomState>(
        'shows a missing room',
        build: build,
        act: (_) => rooms.add(null),
        expect: () => [
          isA<CollabRoomState>().having(
            (s) => s.status,
            'status',
            CollabRoomStatus.missing,
          ),
        ],
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'shows a room the stream fails to read as missing',
        build: build,
        act: (_) => rooms.addError(Exception('db')),
        expect: () => [
          isA<CollabRoomState>().having(
            (s) => s.status,
            'status',
            CollabRoomStatus.missing,
          ),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'picks the first layout that fits everyone in the lobby',
        build: build,
        act: (_) => rooms.add(_room(_lobby)),
        verify: (cubit) {
          expect(cubit.state.status, CollabRoomStatus.ready);
          expect(cubit.state.layout, SplitScreenLayoutPreset.sideBySide);
          expect(cubit.state.canStart, isTrue);
          expect(published, isEmpty);
        },
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'publishes what the last snapshot does not show yet',
        build: build,
        act: (_) => rooms.add(
          _room(
            _lobby,
            messages: [
              _message(
                from: _kai,
                to: _author,
                type: CollabRoomMessageType.join,
                createdAt: 2,
              ),
            ],
          ),
        ),
        verify: (_) {
          expect(published.single.revision, 2);
          expect(
            published.single.members.last.status,
            CollabRoomMemberStatus.joined,
          );
        },
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'tries a sync that failed again, as a sync nobody has to retry',
        setUp: () {
          var calls = 0;
          when(() => service.publish(any(), any())).thenAnswer((
            invocation,
          ) async {
            if (calls++ == 0) throw const CollabRoomException('offline');
            published.add(
              invocation.positionalArguments[1] as CollabRoomSnapshot,
            );
          });
        },
        build: () => build(syncRetryDelay: const Duration(milliseconds: 1)),
        act: (_) => rooms.add(
          _room(
            _lobby,
            messages: [
              _message(
                from: _kai,
                to: _author,
                type: CollabRoomMessageType.join,
                createdAt: 2,
              ),
            ],
          ),
        ),
        wait: const Duration(milliseconds: 50),
        verify: (cubit) {
          expect(
            published.single.members.last.status,
            CollabRoomMemberStatus.joined,
          );
          expect(cubit.state.action, CollabRoomAction.sync);
          expect(cubit.state.actionStatus, CollabRoomActionStatus.idle);
        },
        errors: () => [isA<CollabRoomException>()],
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'only shows the room when it does not keep it in sync',
        build: () => build(keepsRoomInSync: false),
        act: (_) => rooms.add(
          _room(
            _recording,
            messages: [
              _message(
                from: _kai,
                to: _author,
                type: CollabRoomMessageType.leave,
                createdAt: 3,
              ),
            ],
          ),
        ),
        verify: (cubit) {
          expect(cubit.state.status, CollabRoomStatus.ready);
          expect(published, isEmpty);
          verifyNever(() => service.partFile(any(), any()));
        },
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'reads every part and a still of it',
        build: build,
        act: (_) async {
          rooms.add(_room(_recording));
          await pumpEventQueue();
        },
        verify: (cubit) {
          expect(cubit.state.partFiles[_sam], (
            fileHash: '2222222222222222222222222222222222222222222222222222222222222222',
            path: '/parts/2222222222222222222222222222222222222222222222222222222222222222.mp4',
            thumbnailPath: '/parts/2222222222222222222222222222222222222222222222222222222222222222.mp4.jpg',
          ));
          expect(cubit.state.partFiles.keys, containsAll([_author, _sam]));
          expect(cubit.state.fetchingParts, isEmpty);
          expect(cubit.state.layout, SplitScreenLayoutPreset.sideBySide);
          expect(cubit.state.layoutFits, isTrue);
          expect(cubit.state.canCompose, isTrue);
        },
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'reports a part it cannot read',
        setUp: () => when(
          () => service.partFile(_roomId, any()),
        ).thenThrow(const CollabRoomException('gone')),
        build: build,
        act: (_) async {
          rooms.add(_room(_recording));
          await pumpEventQueue();
        },
        verify: (cubit) {
          expect(cubit.state.partFiles, isEmpty);
          expect(cubit.state.fetchingParts, isEmpty);
        },
        errors: () => [
          isA<CollabRoomException>(),
          isA<CollabRoomException>(),
        ],
      );
    });

    group('start', () {
      blocTest<CollabRoomCubit, CollabRoomState>(
        'fixes the layout and cells and leaves out who has not joined',
        build: build,
        act: (cubit) async {
          rooms.add(_room(_lobby));
          await pumpEventQueue();
          await cubit.start();
        },
        verify: (cubit) {
          final snapshot = published.single;
          expect(snapshot.phase, CollabRoomPhase.recording);
          expect(snapshot.layout, 'sideBySide');
          expect(snapshot.aspectRatio, 'vertical');
          expect(snapshot.members, [
            _member(_author, .joined, 0),
            _member(_sam, .joined, 1),
            _member(_kai, .removed),
          ]);
          expect(cubit.state.actionStatus, CollabRoomActionStatus.idle);
          expect(cubit.state.action, CollabRoomAction.start);
        },
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        "fixes the host's settings and the part length in series",
        build: build,
        act: (cubit) async {
          rooms.add(_room(_lobby));
          await pumpEventQueue();
          cubit
            ..gapChanged(0.03)
            ..borderColorChanged(const Color(0xFF000000))
            ..arrangementPicked(CollabRoomArrangement.series);
          await cubit.start();
        },
        verify: (_) {
          final snapshot = published.last;
          expect(snapshot.phase, CollabRoomPhase.recording);
          expect(snapshot.gap, 0.03);
          expect(snapshot.borderColor, 0x000000);
          expect(snapshot.arrangement, CollabRoomArrangement.series);
          // Two people film: the default length fits them.
          expect(snapshot.partLength, collabRoomDefaultPartLength);
        },
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'leaves the part length open side by side',
        build: build,
        act: (cubit) async {
          rooms.add(_room(_lobby));
          await pumpEventQueue();
          await cubit.start();
        },
        verify: (_) {
          expect(
            published.single.arrangement,
            CollabRoomArrangement.sideBySide,
          );
          expect(published.single.partLength, isNull);
          expect(published.single.gap, isNull);
        },
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'does nothing for a member',
        build: build,
        act: (cubit) async {
          rooms.add(_room(_lobby, owner: _sam));
          await pumpEventQueue();
          await cubit.start();
        },
        verify: (_) => expect(published, isEmpty),
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'reports a start that reached nobody',
        setUp: () => when(
          () => service.publish(any(), any()),
        ).thenThrow(const CollabRoomException('offline')),
        build: build,
        act: (cubit) async {
          rooms.add(_room(_lobby));
          await pumpEventQueue();
          await cubit.start();
        },
        verify: (cubit) => expect(
          cubit.state.actionStatus,
          CollabRoomActionStatus.failed,
        ),
        errors: () => [isA<CollabRoomException>()],
      );
    });

    group('seatTapped', () {
      blocTest<CollabRoomCubit, CollabRoomState>(
        'swaps two seats at once and publishes the new order after',
        build: build,
        act: (cubit) async {
          rooms.add(_room(_lobby));
          await pumpEventQueue();
          cubit.seatTapped(0);
          expect(cubit.state.selectedSeat, 0);
          cubit.seatTapped(1);
          // On screen before anything is sent.
          expect(cubit.state.lobbySeatOrder, [_sam, _author]);
          expect(published, isEmpty);
          await pumpEventQueue();
        },
        verify: (cubit) {
          expect(cubit.state.selectedSeat, isNull);
          expect(published.single.members, [
            _member(_author, .joined, 1),
            _member(_sam, .joined, 0),
            _member(_kai, .invited),
          ]);
        },
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'sends a swap made while another message is on its way',
        setUp: () {
          final first = Completer<void>();
          addTearDown(() {
            if (!first.isCompleted) first.complete();
          });
          var calls = 0;
          when(() => service.publish(any(), any())).thenAnswer((
            invocation,
          ) async {
            published.add(
              invocation.positionalArguments[1] as CollabRoomSnapshot,
            );
            if (calls++ == 0) {
              // The swap lands while the layout is still being sent.
              await first.future;
            }
          });
          sendFirst = first.complete;
        },
        build: build,
        act: (cubit) async {
          rooms.add(_room(_lobby));
          await pumpEventQueue();
          await cubit.layoutPicked(SplitScreenLayoutPreset.stacked);
          await pumpEventQueue();
          expect(published, hasLength(1));
          cubit
            ..seatTapped(0)
            ..seatTapped(1);
          await pumpEventQueue();
          sendFirst();
          await pumpEventQueue();
        },
        verify: (cubit) {
          expect(published, hasLength(2));
          expect(published.last.members.first, _member(_author, .joined, 1));
          // Neither shares a revision, though the first is not back yet.
          expect(published.first.revision, 2);
          expect(published.last.revision, 3);
        },
      );

      group('when the room screen closes', () {
        CollabRoomCubit buildBatching() => CollabRoomCubit(
          service: service,
          roomId: _roomId,
          // Longer than any test: only closing can send the swap.
          lobbyPublishDelay: const Duration(minutes: 1),
        );

        test('sends a swap still waiting to be batched', () async {
          final cubit = buildBatching();
          rooms.add(_room(_lobby));
          await pumpEventQueue();
          cubit
            ..seatTapped(0)
            ..seatTapped(1);
          expect(published, isEmpty);

          await cubit.close();

          expect(published.single.members, [
            _member(_author, .joined, 1),
            _member(_sam, .joined, 0),
            _member(_kai, .invited),
          ]);
        });

        test('sends it after the message already on its way', () async {
          final first = Completer<void>();
          addTearDown(() {
            if (!first.isCompleted) first.complete();
          });
          var calls = 0;
          when(() => service.publish(any(), any())).thenAnswer((
            invocation,
          ) async {
            published.add(
              invocation.positionalArguments[1] as CollabRoomSnapshot,
            );
            if (calls++ == 0) await first.future;
          });
          final cubit = buildBatching();
          rooms.add(_room(_lobby));
          await pumpEventQueue();
          // A removal goes out at once; it stays in flight here.
          unawaited(cubit.removeMember(_kai));
          await pumpEventQueue();
          expect(published, hasLength(1));
          cubit
            ..seatTapped(0)
            ..seatTapped(1);

          final closing = cubit.close();
          await pumpEventQueue();
          expect(published, hasLength(1));
          first.complete();
          await closing;

          expect(published, hasLength(2));
          expect(
            published.last.revision,
            greaterThan(published.first.revision),
          );
          expect(
            published.last.members.where((m) => m.cell != null),
            [_member(_author, .joined, 1), _member(_sam, .joined, 0)],
          );
        });
      });

      blocTest<CollabRoomCubit, CollabRoomState>(
        'starts with a swap that is not published yet',
        build: build,
        act: (cubit) async {
          rooms.add(_room(_lobby));
          await pumpEventQueue();
          cubit
            ..seatTapped(0)
            ..seatTapped(1);
          await cubit.start();
        },
        verify: (_) => expect(published.last.members, [
          _member(_author, .joined, 1),
          _member(_sam, .joined, 0),
          _member(_kai, .removed),
        ]),
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'keeps the swap on screen until the snapshot holding it is back',
        build: build,
        act: (cubit) async {
          rooms.add(_room(_lobby));
          await pumpEventQueue();
          cubit
            ..seatTapped(0)
            ..seatTapped(1);
          // An older snapshot arriving meanwhile does not undo it.
          rooms.add(_room(_lobby));
          await pumpEventQueue();
          expect(cubit.state.pendingSeats, [_sam, _author]);
          rooms.add(_room(published.single));
          await pumpEventQueue();
        },
        verify: (cubit) {
          expect(cubit.state.pendingSeats, isNull);
          expect(cubit.state.lobbySeatOrder, [_sam, _author]);
        },
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'tapping the same seat twice only clears the pick',
        build: build,
        act: (cubit) async {
          rooms.add(_room(_lobby));
          await pumpEventQueue();
          cubit
            ..seatTapped(1)
            ..seatTapped(1);
          await pumpEventQueue();
        },
        verify: (cubit) {
          expect(cubit.state.selectedSeat, isNull);
          expect(published, isEmpty);
        },
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'keeps the chosen seats when filming starts',
        build: build,
        act: (cubit) async {
          rooms.add(
            _room(
              CollabRoomSnapshot(
                revision: 1,
                phase: CollabRoomPhase.lobby,
                members: [
                  _member(_author, .joined, 1),
                  _member(_sam, .joined, 0),
                ],
              ),
            ),
          );
          await pumpEventQueue();
          await cubit.start();
        },
        verify: (_) => expect(published.single.members, [
          _member(_author, .joined, 1),
          _member(_sam, .joined, 0),
        ]),
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'lets only the host swap seats',
        build: build,
        act: (cubit) async {
          rooms.add(_room(_lobby, owner: _sam));
          await pumpEventQueue();
          cubit.seatTapped(0);
        },
        verify: (cubit) => expect(cubit.state.selectedSeat, isNull),
      );
    });

    group('lobbyHinted', () {
      final memberLobby = CollabRoomSnapshot(
        revision: 2,
        phase: CollabRoomPhase.lobby,
        layout: SplitScreenLayoutPreset.sideBySide.name,
        members: [_member(_author, .joined), _member(_sam, .joined)],
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        "shows a member the host's lobby from the call at once",
        build: build,
        act: (cubit) async {
          rooms.add(_room(memberLobby, owner: _sam));
          await pumpEventQueue();
          cubit.lobbyHinted(
            from: _author,
            layout: SplitScreenLayoutPreset.circleTopLeft.name,
            seats: [_sam, _author],
            revision: 2,
          );
        },
        verify: (cubit) {
          expect(cubit.state.layout, SplitScreenLayoutPreset.circleTopLeft);
          expect(cubit.state.lobbySeatOrder, [_sam, _author]);
        },
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'ignores a lobby described by anyone but the host',
        build: build,
        act: (cubit) async {
          rooms.add(_room(memberLobby, owner: _sam));
          await pumpEventQueue();
          cubit.lobbyHinted(
            from: _kai,
            layout: SplitScreenLayoutPreset.stacked.name,
            seats: [_sam, _author],
            revision: 2,
          );
        },
        verify: (cubit) {
          expect(cubit.state.layout, SplitScreenLayoutPreset.sideBySide);
          expect(cubit.state.pendingSeats, isNull);
        },
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'follows the snapshot the host published after the call',
        build: build,
        act: (cubit) async {
          rooms.add(_room(memberLobby, owner: _sam));
          await pumpEventQueue();
          cubit.lobbyHinted(
            from: _author,
            layout: SplitScreenLayoutPreset.stacked.name,
            seats: [_sam, _author],
            revision: 2,
          );
          // A snapshot at the revision the call built on is older than it.
          rooms.add(_room(memberLobby, owner: _sam));
          await pumpEventQueue();
          expect(cubit.state.layout, SplitScreenLayoutPreset.stacked);
          rooms.add(
            _room(
              CollabRoomSnapshot(
                revision: 3,
                phase: CollabRoomPhase.lobby,
                layout: SplitScreenLayoutPreset.slantedStacked.name,
                members: [_member(_author, .joined), _member(_sam, .joined)],
              ),
              owner: _sam,
            ),
          );
          await pumpEventQueue();
        },
        verify: (cubit) {
          expect(cubit.state.layout, SplitScreenLayoutPreset.slantedStacked);
          expect(cubit.state.pendingSeats, isNull);
        },
      );
    });

    group('lobby settings', () {
      blocTest<CollabRoomCubit, CollabRoomState>(
        "shows the host's picks at once and publishes them together",
        build: build,
        act: (cubit) async {
          rooms.add(_room(_lobby));
          await pumpEventQueue();
          cubit
            ..gapChanged(0.0412)
            ..arrangementPicked(CollabRoomArrangement.series)
            ..partLengthChanged(const Duration(milliseconds: 2460));
          expect(cubit.state.gap, 0.041);
          expect(cubit.state.inSeries, isTrue);
          expect(cubit.state.partLength, const Duration(milliseconds: 2500));
          expect(published, isEmpty);
          await pumpEventQueue();
        },
        verify: (_) {
          final snapshot = published.single;
          expect(snapshot.phase, CollabRoomPhase.lobby);
          expect(snapshot.gap, 0.041);
          expect(snapshot.arrangement, CollabRoomArrangement.series);
          expect(snapshot.partLength, const Duration(milliseconds: 2500));
        },
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'publishes the gap colour, always opaque',
        build: build,
        act: (cubit) async {
          rooms.add(_room(_lobby));
          await pumpEventQueue();
          cubit.borderColorChanged(const Color(0x8027C58B));
          expect(cubit.state.borderColor, const Color(0xFF27C58B));
          await pumpEventQueue();
        },
        verify: (_) => expect(published.single.borderColor, 0x27C58B),
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'keeps the gap and part length within what the room can show',
        build: build,
        act: (cubit) async {
          rooms.add(_room(_lobby));
          await pumpEventQueue();
          cubit
            ..gapChanged(1)
            ..partLengthChanged(const Duration(seconds: 6));
        },
        verify: (cubit) {
          expect(cubit.state.gap, SplitScreenLayoutGeometry.maxGap);
          // Two people share the post length.
          expect(cubit.state.partLength, collabRoomMaxPartLength(2));
        },
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'publishes nothing when the host changes nothing',
        build: build,
        act: (cubit) async {
          rooms.add(
            _room(
              CollabRoomSnapshot(
                revision: 1,
                phase: CollabRoomPhase.lobby,
                layout: SplitScreenLayoutPreset.sideBySide.name,
                members: _lobby.members,
              ),
            ),
          );
          await pumpEventQueue();
          cubit.arrangementPicked(CollabRoomArrangement.sideBySide);
          await pumpEventQueue();
        },
        verify: (_) => expect(published, isEmpty),
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'takes no settings from a member',
        build: build,
        act: (cubit) async {
          rooms.add(_room(_lobby, owner: _sam));
          await pumpEventQueue();
          cubit
            ..gapChanged(0.05)
            ..arrangementPicked(CollabRoomArrangement.series)
            ..partLengthChanged(const Duration(seconds: 2));
          await pumpEventQueue();
        },
        verify: (cubit) {
          expect(published, isEmpty);
          expect(cubit.state.gap, collabRoomCellGap);
          expect(cubit.state.borderColor, collabRoomBorderColor);
          expect(cubit.state.inSeries, isFalse);
        },
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        "shows a member the host's settings",
        build: build,
        act: (cubit) async {
          rooms.add(
            _room(
              CollabRoomSnapshot(
                revision: 2,
                phase: CollabRoomPhase.lobby,
                members: [
                  _member(_author, .joined),
                  _member(_sam, .joined),
                ],
                gap: 0.06,
                borderColor: 0xF9F7F6,
                arrangement: CollabRoomArrangement.series,
                partLength: const Duration(seconds: 2),
              ),
              owner: _sam,
            ),
          );
          await pumpEventQueue();
        },
        verify: (cubit) {
          expect(cubit.state.gap, 0.06);
          expect(cubit.state.borderColor, const Color(0xFFF9F7F6));
          expect(cubit.state.inSeries, isTrue);
          expect(cubit.state.partLength, const Duration(seconds: 2));
        },
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'takes no settings once filming started',
        build: build,
        act: (cubit) async {
          rooms.add(_room(_recording));
          await pumpEventQueue();
          cubit
            ..gapChanged(0.05)
            ..arrangementPicked(CollabRoomArrangement.series);
          await pumpEventQueue();
        },
        verify: (cubit) {
          expect(published, isEmpty);
          expect(cubit.state.inSeries, isFalse);
        },
      );
    });

    group('layoutPicked', () {
      blocTest<CollabRoomCubit, CollabRoomState>(
        'publishes the last lobby pick once, after the host stops picking',
        build: build,
        act: (cubit) async {
          rooms.add(_room(_lobby));
          await pumpEventQueue();
          await cubit.layoutPicked(SplitScreenLayoutPreset.stacked);
          await cubit.layoutPicked(SplitScreenLayoutPreset.sideBySide);
          await cubit.layoutPicked(SplitScreenLayoutPreset.stacked);
          expect(published, isEmpty);
          await pumpEventQueue();
        },
        verify: (cubit) {
          expect(cubit.state.layout, SplitScreenLayoutPreset.stacked);
          expect(published.single.layout, 'stacked');
          expect(published.single.phase, CollabRoomPhase.lobby);
        },
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        "shows a member the host's lobby layout",
        build: build,
        act: (cubit) async {
          rooms.add(
            _room(
              CollabRoomSnapshot(
                revision: 2,
                phase: CollabRoomPhase.lobby,
                layout: SplitScreenLayoutPreset.stacked.name,
                members: [
                  _member(_author, .joined),
                  _member(_sam, .joined),
                ],
              ),
              owner: _sam,
            ),
          );
          await pumpEventQueue();
        },
        verify: (cubit) {
          expect(cubit.state.layout, SplitScreenLayoutPreset.stacked);
          expect(published, isEmpty);
        },
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'publishes a pick made while filming',
        build: build,
        act: (cubit) async {
          rooms.add(_room(_recording));
          await pumpEventQueue();
          await cubit.layoutPicked(SplitScreenLayoutPreset.stacked);
        },
        verify: (_) => expect(published.single.layout, 'stacked'),
      );
    });

    group('removeMember', () {
      blocTest<CollabRoomCubit, CollabRoomState>(
        'takes someone out of the lobby',
        build: build,
        act: (cubit) async {
          rooms.add(_room(_lobby));
          await pumpEventQueue();
          await cubit.removeMember(_kai);
        },
        verify: (_) => expect(
          published.single.members.last.status,
          CollabRoomMemberStatus.removed,
        ),
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'never takes the author out',
        build: build,
        act: (cubit) async {
          rooms.add(_room(_lobby));
          await pumpEventQueue();
          await cubit.removeMember(_author);
        },
        verify: (_) => expect(published, isEmpty),
      );
    });

    group('filming in series', () {
      final layoutForThree = collabRoomLayoutsFor(3).first;
      final seriesForThree = CollabRoomSnapshot(
        revision: 2,
        phase: CollabRoomPhase.recording,
        layout: layoutForThree.name,
        members: [
          _member(_author, .joined, 0),
          _member(_sam, .joined, 1),
          _member(_kai, .joined, 2),
        ],
        arrangement: CollabRoomArrangement.series,
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'closes the seat of someone who left, with no layout to pick',
        build: build,
        act: (cubit) async {
          rooms.add(
            _room(
              seriesForThree,
              messages: [
                _message(
                  from: _kai,
                  to: _author,
                  type: CollabRoomMessageType.leave,
                  createdAt: 3,
                ),
              ],
            ),
          );
          await pumpEventQueue();
        },
        verify: (_) {
          final snapshot = published.single;
          expect(snapshot.layout, collabRoomLayoutsFor(2).first.name);
          expect(snapshot.members, [
            _member(_author, .joined, 0),
            _member(_sam, .joined, 1),
            _member(_kai, .left),
          ]);
        },
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'leaves the layout to the host side by side',
        build: build,
        act: (cubit) async {
          rooms.add(
            _room(
              CollabRoomSnapshot(
                revision: 2,
                phase: CollabRoomPhase.recording,
                layout: layoutForThree.name,
                members: seriesForThree.members,
              ),
              messages: [
                _message(
                  from: _kai,
                  to: _author,
                  type: CollabRoomMessageType.leave,
                  createdAt: 3,
                ),
              ],
            ),
          );
          await pumpEventQueue();
        },
        verify: (cubit) {
          // Only the news goes out; the host picks the next layout.
          expect(published.single.layout, layoutForThree.name);
          expect(cubit.state.layoutFits, isFalse);
        },
      );
    });

    group('answers', () {
      for (final (name, action, expected) in [
        ('join', (CollabRoomCubit c) => c.join(), CollabRoomAction.join),
        (
          'decline',
          (CollabRoomCubit c) => c.decline(),
          CollabRoomAction.decline,
        ),
        ('leave', (CollabRoomCubit c) => c.leave(), CollabRoomAction.leave),
      ]) {
        blocTest<CollabRoomCubit, CollabRoomState>(
          'sends a $name',
          build: build,
          act: (cubit) async {
            rooms.add(_room(_lobby, owner: _kai));
            await pumpEventQueue();
            await action(cubit);
          },
          verify: (cubit) {
            expect(cubit.state.action, expected);
            expect(cubit.state.actionStatus, CollabRoomActionStatus.idle);
          },
        );
      }
    });

    group('cancel', () {
      blocTest<CollabRoomCubit, CollabRoomState>(
        'calls the room off and deletes its parts',
        build: build,
        act: (cubit) async {
          rooms.add(_room(_lobby));
          await pumpEventQueue();
          await cubit.cancel();
        },
        verify: (_) {
          expect(published.single.phase, CollabRoomPhase.cancelled);
          verify(() => service.deleteRoomFiles(_roomId)).called(1);
        },
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'waits for an update on its way instead of dropping the call-off',
        setUp: () {
          final first = Completer<void>();
          addTearDown(() {
            if (!first.isCompleted) first.complete();
          });
          var calls = 0;
          when(() => service.publish(any(), any())).thenAnswer((
            invocation,
          ) async {
            published.add(
              invocation.positionalArguments[1] as CollabRoomSnapshot,
            );
            if (calls++ == 0) await first.future;
          });
          sendFirst = first.complete;
        },
        build: build,
        act: (cubit) async {
          rooms.add(_room(_lobby));
          await pumpEventQueue();
          await cubit.layoutPicked(SplitScreenLayoutPreset.stacked);
          await pumpEventQueue();
          final cancelling = cubit.cancel();
          await pumpEventQueue();
          sendFirst();
          await cancelling;
        },
        verify: (_) => expect(published.last.phase, CollabRoomPhase.cancelled),
      );
    });

    group('dismiss', () {
      CollabRoomSnapshot ended(CollabRoomPhase phase) => CollabRoomSnapshot(
        revision: 3,
        phase: phase,
        layout: _recording.layout,
        members: _recording.members,
      );

      for (final phase in [CollabRoomPhase.posted, CollabRoomPhase.cancelled]) {
        blocTest<CollabRoomCubit, CollabRoomState>(
          'deletes the parts of a room that was ${phase.name}',
          build: build,
          act: (cubit) async {
            rooms.add(_room(ended(phase), owner: _sam));
            await pumpEventQueue();
            await cubit.dismiss();
          },
          verify: (_) =>
              verify(() => service.deleteRoomFiles(_roomId)).called(1),
        );
      }

      blocTest<CollabRoomCubit, CollabRoomState>(
        'keeps the parts of a room still open',
        build: build,
        act: (cubit) async {
          rooms.add(_room(_recording, owner: _sam));
          await pumpEventQueue();
          await cubit.dismiss();
        },
        verify: (_) => verifyNever(() => service.deleteRoomFiles(_roomId)),
      );
    });

    group('reinvite', () {
      blocTest<CollabRoomCubit, CollabRoomState>(
        'asks someone who declined back in',
        setUp: () => when(
          () => service.reinvite(any(), any(), any()),
        ).thenAnswer((_) async {}),
        build: build,
        act: (cubit) async {
          rooms.add(
            _room(
              CollabRoomSnapshot(
                revision: 1,
                phase: CollabRoomPhase.lobby,
                members: [
                  _member(_author, .joined),
                  _member(_sam, .joined),
                  _member(_kai, .declined),
                ],
              ),
            ),
          );
          await pumpEventQueue();
          await cubit.reinvite(_kai);
        },
        verify: (_) {
          final snapshot =
              verify(
                    () => service.reinvite(any(), _kai, captureAny()),
                  ).captured.single
                  as CollabRoomSnapshot;
          expect(snapshot.revision, 2);
          expect(
            snapshot.members.firstWhere((m) => m.pubkey == _kai).status,
            CollabRoomMemberStatus.invited,
          );
        },
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'leaves someone still in the room as they are',
        build: build,
        act: (cubit) async {
          rooms.add(_room(_lobby));
          await pumpEventQueue();
          await cubit.reinvite(_sam);
        },
        verify: (_) => verifyNever(() => service.reinvite(any(), any(), any())),
      );
    });

    group('compose', () {
      blocTest<CollabRoomCubit, CollabRoomState>(
        "spaces the parts by the host's gap, in the host's colour",
        build: build,
        act: (cubit) async {
          rooms.add(
            _room(
              CollabRoomSnapshot(
                revision: 2,
                phase: CollabRoomPhase.recording,
                layout: _recording.layout,
                members: _recording.members,
                parts: _recording.parts,
                gap: 0.05,
                borderColor: 0x27C58B,
              ),
            ),
          );
          await pumpEventQueue();
          await cubit.compose();
        },
        verify: (_) {
          expect(composedBackgrounds.single, const Color(0xFF27C58B));
          expect(
            composed.single.map((cell) => cell.rect),
            SplitScreenLayoutPreset.sideBySide.cellRects(
              aspectRatio: 9 / 16,
              gap: 0.05,
            ),
          );
          expect(composedSeries, isEmpty);
        },
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'joins the parts one after another in seat order',
        build: build,
        act: (cubit) async {
          rooms.add(
            _room(
              CollabRoomSnapshot(
                revision: 2,
                phase: CollabRoomPhase.recording,
                layout: _recording.layout,
                // Sam goes first.
                members: [
                  _member(_author, .joined, 1),
                  _member(_sam, .joined, 0),
                  _member(_kai, .removed),
                ],
                parts: _recording.parts,
                arrangement: CollabRoomArrangement.series,
                partLength: const Duration(seconds: 2),
              ),
            ),
          );
          await pumpEventQueue();
          await cubit.compose();
        },
        verify: (cubit) {
          expect(composed, isEmpty);
          expect(cubit.state.composeStatus, CollabRoomComposeStatus.done);
          expect(cubit.state.composedClip?.id, 'series');
          final parts = composedSeries.single;
          expect(parts.map((part) => part.file.path), [
            '/parts/2222222222222222222222222222222222222222222222222222222222222222.mp4',
            '/parts/3333333333333333333333333333333333333333333333333333333333333333.mp4',
          ]);
          expect(
            parts.map((part) => part.length),
            everyElement(const Duration(seconds: 2)),
          );
        },
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        "keeps every part's own sound in series",
        build: build,
        act: (cubit) async {
          rooms.add(
            _room(
              CollabRoomSnapshot(
                revision: 2,
                phase: CollabRoomPhase.recording,
                layout: _recording.layout,
                members: _recording.members,
                parts: _recording.parts,
                arrangement: CollabRoomArrangement.series,
              ),
            ),
          );
          await pumpEventQueue();
          await cubit.soundPicked(_sam);
        },
        verify: (cubit) {
          expect(published, isEmpty);
          expect(cubit.state.soundPubkey, isNull);
        },
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'puts the parts in their cells with the picked sound',
        build: build,
        act: (cubit) async {
          rooms.add(_room(_recording));
          await pumpEventQueue();
          await cubit.soundPicked(_sam);
          await cubit.compose();
        },
        verify: (cubit) {
          // The pick goes out, so guests see it and it outlives the screen.
          expect(published.single.soundPubkey, _sam);
          expect(cubit.state.composeStatus, CollabRoomComposeStatus.done);
          expect(cubit.state.composedClip?.id, 'composed');
          final cells = composed.single;
          expect(cells.map((c) => c.file.path), [
            '/parts/3333333333333333333333333333333333333333333333333333333333333333.mp4',
            '/parts/2222222222222222222222222222222222222222222222222222222222222222.mp4',
          ]);
          expect(cells.map((c) => c.withSound), [false, true]);
          expect(composedBackgrounds.single, collabRoomBorderColor);
          expect(cells.first.rect.left, lessThan(cells.last.rect.left));
          expect(cells.first.rect, isA<Rect>());
        },
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'publishes a pick made while an update and a sync are going out',
        setUp: () {
          final first = Completer<void>();
          addTearDown(() {
            if (!first.isCompleted) first.complete();
          });
          var calls = 0;
          when(() => service.publish(any(), any())).thenAnswer((
            invocation,
          ) async {
            published.add(
              invocation.positionalArguments[1] as CollabRoomSnapshot,
            );
            if (calls++ == 0) await first.future;
          });
          sendFirst = first.complete;
        },
        build: build,
        act: (cubit) async {
          rooms.add(_room(_recording));
          await pumpEventQueue();
          // A layout pick goes out and is held there.
          final busy = cubit.layoutPicked(SplitScreenLayoutPreset.stacked);
          await pumpEventQueue();
          // That snapshot comes back, and Sam's part, which it does not show
          // yet, lands with it: a sync waits for the update.
          rooms.add(
            _room(
              CollabRoomSnapshot(
                revision: 3,
                phase: CollabRoomPhase.recording,
                layout: SplitScreenLayoutPreset.stacked.name,
                members: _recording.members,
                parts: [_recording.parts.first],
              ),
              messages: [
                _message(
                  from: _sam,
                  to: _author,
                  type: CollabRoomMessageType.part,
                  createdAt: 3,
                ),
              ],
            ),
          );
          await pumpEventQueue();
          final picking = cubit.soundPicked(_sam);
          await pumpEventQueue();
          sendFirst();
          await busy;
          await picking;
        },
        verify: (_) {
          expect(published, hasLength(3));
          expect(published[1].parts.map((part) => part.pubkey), contains(_sam));
          expect(published.last.soundPubkey, _sam);
        },
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        "gives the host's part the sound once the person picked left",
        build: build,
        act: (cubit) async {
          rooms.add(_room(_recording));
          await pumpEventQueue();
          await cubit.soundPicked(_sam);
          rooms.add(
            _room(
              CollabRoomSnapshot(
                revision: 3,
                phase: CollabRoomPhase.recording,
                layout: _recording.layout,
                members: [
                  _member(_author, .joined, 0),
                  _member(_sam, .left),
                ],
                parts: _recording.parts
                    .where((part) => part.pubkey == _author)
                    .toList(),
              ),
            ),
          );
          await pumpEventQueue();
        },
        verify: (cubit) => expect(cubit.state.effectiveSoundPubkey, _author),
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'stacks the parts in cell order, whoever joined first',
        build: build,
        act: (cubit) async {
          // The host took the window, which must be drawn over the frame.
          rooms.add(
            _room(
              CollabRoomSnapshot(
                revision: 2,
                phase: CollabRoomPhase.recording,
                layout:
                    SplitScreenLayoutPreset.pictureInPictureBottomRight.name,
                members: [
                  _member(_author, .joined, 1),
                  _member(_sam, .joined, 0),
                ],
                parts: _recording.parts,
              ),
            ),
          );
          await pumpEventQueue();
          await cubit.compose();
        },
        verify: (cubit) {
          final cells = composed.single;
          // Sam's frame first, the host's window over it.
          expect(cells.map((c) => c.file.path), [
            '/parts/2222222222222222222222222222222222222222222222222222222222222222.mp4',
            '/parts/3333333333333333333333333333333333333333333333333333333333333333.mp4',
          ]);
          expect(cells.map((c) => c.rect), cubit.state.room!.cellRects);
          expect(cells.first.rect.width, greaterThan(cells.last.rect.width));
        },
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'reports a render that produced nothing',
        build: () => CollabRoomCubit(
          service: service,
          roomId: _roomId,
          thumbnailer: (_) async => null,
          composer: ({
            required cells,
            required aspectRatio,
            required backgroundColor,
            required taskId,
          }) async => null,
        ),
        act: (cubit) async {
          rooms.add(_room(_recording));
          await pumpEventQueue();
          await cubit.compose();
        },
        verify: (cubit) => expect(
          cubit.state.composeStatus,
          CollabRoomComposeStatus.failed,
        ),
        errors: () => [isA<CollabRoomException>()],
      );

      blocTest<CollabRoomCubit, CollabRoomState>(
        'waits until every part is in',
        build: build,
        act: (cubit) async {
          rooms.add(
            _room(
              CollabRoomSnapshot(
                revision: 2,
                phase: CollabRoomPhase.recording,
                layout: 'sideBySide',
                members: [
                  _member(_author, .joined, 0),
                  _member(_sam, .joined, 1),
                ],
              ),
            ),
          );
          await pumpEventQueue();
          await cubit.compose();
        },
        verify: (cubit) {
          expect(cubit.state.canCompose, isFalse);
          expect(composed, isEmpty);
        },
      );
    });

    test('plays the sound of the host until another is picked', () async {
      final cubit = build();
      addTearDown(cubit.close);
      rooms.add(_room(_lobby));
      await pumpEventQueue();
      expect(cubit.state.effectiveSoundPubkey, _author);
    });
  });

  // Outside the cubit's group: its tearDown waits on a room stream only a
  // cubit listens to.
  group(CollabRoomState, () {
    group('endedByHost', () {
      CollabRoomState seenBy(
        String owner,
        CollabRoomPhase phase, {
        CollabRoomMemberStatus samStatus = CollabRoomMemberStatus.joined,
      }) => CollabRoomState(
        status: CollabRoomStatus.ready,
        room: _room(
          CollabRoomSnapshot(
            revision: 3,
            phase: phase,
            layout: _recording.layout,
            members: [_member(_author, .joined, 0), _member(_sam, samStatus)],
          ),
          owner: owner,
        ),
      );

      test('is true for a member once the host called the room off', () {
        expect(seenBy(_sam, CollabRoomPhase.cancelled).endedByHost, isTrue);
      });

      test('is true for a member the host took out', () {
        expect(
          seenBy(
            _sam,
            CollabRoomPhase.recording,
            samStatus: CollabRoomMemberStatus.removed,
          ).endedByHost,
          isTrue,
        );
      });

      test('is false for the host, and while the room is open', () {
        expect(seenBy(_author, CollabRoomPhase.cancelled).endedByHost, isFalse);
        expect(seenBy(_sam, CollabRoomPhase.recording).endedByHost, isFalse);
        expect(seenBy(_sam, CollabRoomPhase.posted).endedByHost, isFalse);
      });
    });

    group('postedVideo', () {
      test('names the posted video by author and d tag', () {
        final state = CollabRoomState(
          status: CollabRoomStatus.ready,
          room: _room(
            CollabRoomSnapshot(
              revision: 3,
              phase: CollabRoomPhase.posted,
              layout: _recording.layout,
              members: _recording.members,
              videoAddress: '34236:$_author:take:one',
            ),
            owner: _sam,
          ),
        );

        expect(state.postedVideo?.pubkey, _author);
        expect(state.postedVideo?.dTag, 'take:one');
      });

      test('names none before the video is posted', () {
        final state = CollabRoomState(
          status: CollabRoomStatus.ready,
          room: _room(_recording, owner: _sam),
        );

        expect(state.postedVideo, isNull);
      });
    });
  });
}
