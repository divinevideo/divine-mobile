import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/video_publish/publish_error_kind.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';
import 'package:post_live_activity_repository/post_live_activity_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDraft extends Mock implements DivineVideoDraft {}

class _MockDraftStorageService extends Mock implements DraftStorageService {}

class _MockVideoPublishService extends Mock implements VideoPublishService {}

/// Records calls in order; optionally throws to prove a failure never
/// reaches the publish.
class _FakeRepository extends Fake implements PostLiveActivityRepository {
  final calls = <String>[];
  final starts = <({String key, String owner, Future<Uint8List?> thumb})>[];
  final lives = <({String key, String coordinate, String eventId})>[];
  Object? error;

  @override
  void startPosting({
    required String key,
    required String ownerPubkey,
    required Future<Uint8List?> thumbnail,
  }) {
    calls.add('start $key');
    starts.add((key: key, owner: ownerPubkey, thumb: thumbnail));
    if (error != null) throw error!;
  }

  @override
  Future<void> markLive({
    required String key,
    required String postCoordinate,
    required String postEventId,
  }) async {
    calls.add('live $key');
    lives.add((key: key, coordinate: postCoordinate, eventId: postEventId));
    if (error != null) throw error!;
  }

  @override
  Future<void> end({required String key}) async {
    calls.add('end $key');
    if (error != null) throw error!;
  }
}

class _SlowPlatform implements LiveActivityPlatform {
  final startGate = Completer<String>();
  final updates = <({String id, LiveActivityPhase phase, String? coord})>[];

  @override
  Stream<LiveActivityPlatformEvent> get events => const Stream.empty();

  @override
  Future<bool> isEnabled() async => true;

  @override
  Future<String> writeThumbnail(Uint8List bytes) async => 'thumb.jpg';

  @override
  Future<String> start({
    required String ownerPubkey,
    required bool showFirstRunNote,
    String? thumbnailFileName,
  }) => startGate.future;

  @override
  Future<void> update(
    String id, {
    required LiveActivityPhase phase,
    required bool showFirstRunNote,
    String? postCoordinate,
    String? postEventId,
  }) async {
    updates.add((id: id, phase: phase, coord: postCoordinate));
  }

  @override
  Future<void> end(String id, {required bool immediate}) async {}

  @override
  Future<List<RunningLiveActivity>> list() async => const [];
}

class _SilentRegistrar implements LiveActivityRegistrar {
  @override
  Future<LiveActivityRegistrarResult> register(
    LiveActivityRegistration registration,
  ) async => LiveActivityRegistrarResult.published;
}

final String _owner = 'a' * 64;
final String _eventId = 'e' * 64;
const _failure = PublishError(PublishErrorKind.generic);

DivineVideoDraft _draft(String id) {
  final draft = _MockDraft();
  when(() => draft.id).thenReturn(id);
  when(() => draft.sourceDraftId).thenReturn(null);
  return draft;
}

String _signedBody({int kind = 34236, String d = 'dtag'}) => jsonEncode({
  'id': _eventId,
  'kind': kind,
  'pubkey': _owner,
  'created_at': 1,
  'tags': [
    ['d', d],
  ],
});

void main() {
  late _MockDraftStorageService storage;
  late _FakeRepository repo;

  Future<_MockVideoPublishService> factory({
    required OnProgressChanged onProgress,
  }) async {
    final service = _MockVideoPublishService();
    when(() => service.publishVideo(draft: any(named: 'draft'))).thenAnswer(
      (_) async => const PublishError(PublishErrorKind.generic),
    );
    return service;
  }

  BackgroundPublishBloc build({
    PostLiveActivityRepository? liveActivity,
    bool Function(DivineVideoDraft)? scheduled,
    String? Function()? owner,
  }) => BackgroundPublishBloc(
    videoPublishServiceFactory: factory,
    draftStorageService: storage,
    liveActivity: liveActivity ?? repo,
    currentOwnerPubkey: owner ?? () => _owner,
    isScheduledDraft: scheduled ?? (_) => false,
  );

  Future<void> settle() => pumpEventQueue(times: 50);

  setUpAll(() {
    registerFallbackValue(PublishStatus.draft);
    registerFallbackValue(_MockDraft());
  });

  setUp(() {
    storage = _MockDraftStorageService();
    repo = _FakeRepository();
    when(
      () => storage.updatePublishStatus(
        draftId: any(named: 'draftId'),
        status: any(named: 'status'),
        publishError: any(named: 'publishError'),
      ),
    ).thenAnswer((_) async => true);
    when(() => storage.deleteDraft(any())).thenAnswer((_) async {});
    when(() => storage.draftExists(any())).thenAnswer((_) async => true);
  });

  group('BackgroundPublishBloc live activity', () {
    test('starts an activity keyed by draft id', () async {
      final bloc = build();
      addTearDown(bloc.close);
      final completer = Completer<PublishResult>();
      addTearDown(() => completer.complete(_failure));

      bloc.add(
        BackgroundPublishRequested(
          draft: _draft('d1'),
          publishmentProcess: completer.future,
        ),
      );
      await settle();

      expect(repo.starts, hasLength(1));
      expect(repo.starts.single.key, equals('d1'));
      expect(repo.starts.single.owner, equals(_owner));
    });

    test(
      'a duplicate request for a draft already uploading starts nothing',
      () async {
        final bloc = build();
        addTearDown(bloc.close);
        final draft = _draft('d1');
        final completer = Completer<PublishResult>();
        addTearDown(() => completer.complete(_failure));

        bloc
          ..add(
            BackgroundPublishRequested(
              draft: draft,
              publishmentProcess: completer.future,
            ),
          )
          ..add(
            BackgroundPublishRequested(
              draft: draft,
              publishmentProcess: completer.future,
            ),
          );
        await settle();

        expect(repo.starts, hasLength(1));
      },
    );

    test('does not start one for a draft still scheduled, including on '
        'retry before its time; a retry after its time does', () async {
      var scheduled = true;
      final bloc = build(scheduled: (_) => scheduled);
      addTearDown(bloc.close);
      final draft = _draft('d1');

      bloc.add(
        BackgroundPublishRequested(
          draft: draft,
          publishmentProcess: Future.value(
            const PublishError(PublishErrorKind.generic),
          ),
        ),
      );
      await settle();
      expect(repo.starts, isEmpty);

      bloc.add(BackgroundPublishRetryRequested(draftId: 'd1'));
      await settle();
      expect(repo.starts, isEmpty);

      scheduled = false;
      bloc.add(BackgroundPublishRetryRequested(draftId: 'd1'));
      await settle();
      expect(repo.starts, hasLength(1));
    });

    test('ends it on PublishScheduled, PublishError and '
        'BackgroundPublishVanished', () async {
      final bloc = build();
      addTearDown(bloc.close);

      bloc
        ..add(
          BackgroundPublishRequested(
            draft: _draft('s'),
            publishmentProcess: Future.value(
              PublishScheduled(
                eventId: _eventId,
                publishAt: DateTime.utc(2026, 12),
                submitted: true,
              ),
            ),
          ),
        )
        ..add(
          BackgroundPublishRequested(
            draft: _draft('f'),
            publishmentProcess: Future.value(
              const PublishError(PublishErrorKind.generic),
            ),
          ),
        );
      await settle();
      final pending = Completer<PublishResult>();
      addTearDown(() => pending.complete(_failure));
      bloc.add(
        BackgroundPublishRequested(
          draft: _draft('v'),
          publishmentProcess: pending.future,
        ),
      );
      await settle();
      bloc.add(BackgroundPublishVanished(draftId: 'v'));
      await settle();

      expect(repo.calls, containsAll(['end s', 'end f', 'end v']));
    });

    test('marks it live from the signed event', () async {
      final bloc = build();
      addTearDown(bloc.close);

      bloc.add(
        BackgroundPublishRequested(
          draft: _draft('d1'),
          publishmentProcess: Future.value(
            PublishSuccess(
              stableId: 'ignored',
              eventId: 'ignored',
              signedEventBody: _signedBody(),
            ),
          ),
        ),
      );
      await settle();

      expect(repo.lives, hasLength(1));
      expect(repo.lives.single.key, equals('d1'));
      expect(repo.lives.single.coordinate, equals('34236:$_owner:dtag'));
      expect(repo.lives.single.eventId, equals(_eventId));
    });

    test('falls back to stableId and eventId when the body is null', () async {
      final bloc = build();
      addTearDown(bloc.close);

      bloc.add(
        BackgroundPublishRequested(
          draft: _draft('d1'),
          publishmentProcess: Future.value(
            PublishSuccess(stableId: 'stable', eventId: _eventId),
          ),
        ),
      );
      await settle();

      expect(repo.lives.single.coordinate, equals('34236:$_owner:stable'));
      expect(repo.lives.single.eventId, equals(_eventId));
    });

    test('ends it when a success carries nothing to address', () async {
      final bloc = build();
      addTearDown(bloc.close);

      bloc.add(
        BackgroundPublishRequested(
          draft: _draft('d1'),
          publishmentProcess: Future.value(const PublishSuccess()),
        ),
      );
      await settle();

      expect(repo.lives, isEmpty);
      expect(repo.calls, contains('end d1'));
    });

    test('ends it when the signed event cannot be addressed', () async {
      final bloc = build();
      addTearDown(bloc.close);

      bloc.add(
        BackgroundPublishRequested(
          draft: _draft('d1'),
          publishmentProcess: Future.value(
            PublishSuccess(
              stableId: 'stable',
              eventId: _eventId,
              signedEventBody: jsonEncode({
                'id': _eventId,
                'kind': 34236,
                'pubkey': _owner,
                'tags': [
                  ['d', 42],
                ],
              }),
            ),
          ),
        ),
      );
      await settle();

      expect(repo.lives, isEmpty);
      expect(repo.calls, contains('end d1'));
    });

    test(
      'a publish that settles before the start returns still goes live',
      () async {
        SharedPreferences.setMockInitialValues({});
        final platform = _SlowPlatform();
        final real = PostLiveActivityRepository(
          platform: platform,
          registrar: _SilentRegistrar(),
          sharedPreferences: await SharedPreferences.getInstance(),
        );
        final bloc = build(liveActivity: real);
        addTearDown(bloc.close);

        bloc.add(
          BackgroundPublishRequested(
            draft: _draft('d1'),
            publishmentProcess: Future.value(
              PublishSuccess(stableId: 'stable', eventId: _eventId),
            ),
          ),
        );
        await settle();
        expect(platform.updates, isEmpty);

        platform.startGate.complete('act-1');
        await settle();

        expect(
          platform.updates.map((u) => (u.id, u.phase, u.coord)),
          contains(('act-1', LiveActivityPhase.live, '34236:$_owner:stable')),
        );
      },
    );

    test('with no repository injected, behaves as before', () async {
      final bloc = BackgroundPublishBloc(
        videoPublishServiceFactory: factory,
        draftStorageService: storage,
      );
      addTearDown(bloc.close);

      bloc.add(
        BackgroundPublishRequested(
          draft: _draft('d1'),
          publishmentProcess: Future.value(
            PublishSuccess(stableId: 'stable', eventId: _eventId),
          ),
        ),
      );
      await settle();

      expect(bloc.state.uploads, isEmpty);
      expect(bloc.state.recentlyPublished, hasLength(1));
    });

    test('a Live Activity failure never fails a publish', () async {
      repo.error = StateError('boom');
      final bloc = build();
      addTearDown(bloc.close);

      bloc.add(
        BackgroundPublishRequested(
          draft: _draft('d1'),
          publishmentProcess: Future.value(
            PublishSuccess(stableId: 'stable', eventId: _eventId),
          ),
        ),
      );
      await settle();

      expect(repo.calls, containsAll(['start d1', 'live d1']));
      expect(bloc.state.uploads, isEmpty);
      expect(bloc.state.recentlyPublished, hasLength(1));
    });

    test('a throwing owner lookup never fails a publish', () async {
      final bloc = build(owner: () => throw StateError('no owner'));
      addTearDown(bloc.close);

      bloc.add(
        BackgroundPublishRequested(
          draft: _draft('d1'),
          publishmentProcess: Future.value(
            PublishSuccess(stableId: 'stable', eventId: _eventId),
          ),
        ),
      );
      await settle();

      expect(repo.starts, isEmpty);
      expect(bloc.state.recentlyPublished, hasLength(1));
    });
  });
}
