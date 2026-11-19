import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:bloc_test/bloc_test.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:models/models.dart' show DmFileMetadata, DmMessage;
import 'package:openvine/collab_room/bloc/collab_room_cubit.dart';
import 'package:openvine/collab_room/collab_room_composer.dart';
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
  fileHash: 'hash-sam',
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
        fileHash: 'hash-author',
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

    CollabRoomCubit build({bool keepsRoomInSync = true}) => CollabRoomCubit(
      service: service,
      roomId: _roomId,
      keepsRoomInSync: keepsRoomInSync,
      lobbyPublishDelay: Duration.zero,
      thumbnailer: (path) async => '$path.jpg',
      composer:
          ({required cells, required aspectRatio, required taskId}) async {
            composed.add(cells);
            return DivineVideoClip(
              id: 'composed',
              video: EditorVideo.file(File('/composed.mp4')),
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
            fileHash: 'hash-sam',
            path: '/parts/hash-sam.mp4',
            thumbnailPath: '/parts/hash-sam.mp4.jpg',
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
    });

    group('compose', () {
      blocTest<CollabRoomCubit, CollabRoomState>(
        'puts the parts in their cells with the picked sound',
        build: build,
        act: (cubit) async {
          rooms.add(_room(_recording));
          await pumpEventQueue();
          cubit.soundPicked(_sam);
          await cubit.compose();
        },
        verify: (cubit) {
          expect(cubit.state.composeStatus, CollabRoomComposeStatus.done);
          expect(cubit.state.composedClip?.id, 'composed');
          final cells = composed.single;
          expect(cells.map((c) => c.file.path), [
            '/parts/hash-author.mp4',
            '/parts/hash-sam.mp4',
          ]);
          expect(cells.map((c) => c.withSound), [false, true]);
          expect(cells.first.rect.left, lessThan(cells.last.rect.left));
          expect(cells.first.rect, isA<Rect>());
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

    test('a lobby pick of the frame shape is kept until filming', () async {
      final cubit = build();
      addTearDown(cubit.close);
      rooms.add(_room(_lobby));
      await pumpEventQueue();
      cubit.aspectRatioPicked(model.AspectRatio.square);
      expect(cubit.state.aspectRatio, model.AspectRatio.square);
      expect(cubit.state.effectiveSoundPubkey, _author);
    });
  });
}
