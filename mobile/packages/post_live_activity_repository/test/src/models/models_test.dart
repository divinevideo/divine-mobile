import 'package:flutter_test/flutter_test.dart';
import 'package:post_live_activity_repository/post_live_activity_repository.dart';

void main() {
  final postedAt = DateTime.utc(2026, 11, 19, 12);
  final windowEnd = postedAt.add(const Duration(minutes: 60));

  LiveActivityRegistration registration({
    String activityId = 'a1',
    String ownerPubkey = 'owner',
    String activityPushToken = 'tok',
    String postCoordinate = '34236:owner:d',
    List<String> postEventIds = const ['e1', 'e2'],
    DateTime? postedAtOverride,
    DateTime? windowEndsAt,
    bool showFirstRunNote = true,
    LiveActivityRegistrationState state = LiveActivityRegistrationState.active,
  }) => LiveActivityRegistration(
    activityId: activityId,
    ownerPubkey: ownerPubkey,
    activityPushToken: activityPushToken,
    postCoordinate: postCoordinate,
    postEventIds: postEventIds,
    postedAt: postedAtOverride ?? postedAt,
    windowEndsAt: windowEndsAt ?? windowEnd,
    showFirstRunNote: showFirstRunNote,
    state: state,
  );

  group(LiveActivityRegistration, () {
    test('forPost ends the window 60 minutes after posting', () {
      final r = LiveActivityRegistration.forPost(
        activityId: 'a1',
        ownerPubkey: 'owner',
        activityPushToken: 'tok',
        postCoordinate: '34236:owner:d',
        postEventIds: const ['e1', 'e2'],
        postedAt: postedAt,
        showFirstRunNote: true,
      );
      expect(r.windowEndsAt, equals(windowEnd));
      expect(r.state, equals(LiveActivityRegistrationState.active));
      expect(r, equals(registration()));
    });

    test('ended returns an ended copy and leaves the original', () {
      final r = registration();
      final ended = r.ended();
      expect(ended, equals(registration(state: .ended)));
      expect(r.state, equals(LiveActivityRegistrationState.active));
    });

    test('is equal when every field matches', () {
      expect(registration(), equals(registration()));
    });

    test('is unequal when any single field differs', () {
      final differing = <String, LiveActivityRegistration>{
        'activityId': registration(activityId: 'a2'),
        'ownerPubkey': registration(ownerPubkey: 'other'),
        'activityPushToken': registration(activityPushToken: 'tok2'),
        'postCoordinate': registration(postCoordinate: '34236:owner:e'),
        'postEventIds': registration(postEventIds: ['e1']),
        'postedAt': registration(postedAtOverride: windowEnd),
        'windowEndsAt': registration(windowEndsAt: postedAt),
        'showFirstRunNote': registration(showFirstRunNote: false),
        'state': registration(state: LiveActivityRegistrationState.ended),
      };
      for (final entry in differing.entries) {
        expect(registration(), isNot(equals(entry.value)), reason: entry.key);
      }
    });

    test('liveActivityWire has exactly the request keys', () {
      expect(
        registration().liveActivityWire(),
        equals({
          'activityPushToken': 'tok',
          'postCoordinate': '34236:owner:d',
          'postEventIds': ['e1', 'e2'],
          'postedAt': postedAt.millisecondsSinceEpoch ~/ 1000,
          'windowEndsAt': windowEnd.millisecondsSinceEpoch ~/ 1000,
          'showFirstRunNote': true,
          'state': 'active',
        }),
      );
      expect(registration().ended().liveActivityWire()['state'], 'ended');
    });
  });

  group(RunningLiveActivity, () {
    RunningLiveActivity running({
      String id = 'a',
      String ownerPubkey = 'o',
      DateTime? startedAt,
      String? postCoordinate,
      String? postEventId,
      LiveActivityState state = LiveActivityState.active,
    }) => RunningLiveActivity(
      id: id,
      ownerPubkey: ownerPubkey,
      startedAt: startedAt ?? postedAt,
      postCoordinate: postCoordinate,
      postEventId: postEventId,
      state: state,
    );

    test('is equal when every field matches', () {
      expect(running(), equals(running()));
    });

    test('is unequal when any single field differs', () {
      final differing = <String, RunningLiveActivity>{
        'id': running(id: 'b'),
        'ownerPubkey': running(ownerPubkey: 'p'),
        'startedAt': running(startedAt: windowEnd),
        'postCoordinate': running(postCoordinate: 'c'),
        'postEventId': running(postEventId: 'e'),
        'state': running(state: LiveActivityState.ended),
      };
      for (final entry in differing.entries) {
        expect(running(), isNot(equals(entry.value)), reason: entry.key);
      }
    });
  });

  group(LiveActivityPlatformEvent, () {
    EnablementChanged enablement({bool enabled = true}) =>
        EnablementChanged(enabled: enabled);
    PushTokenChanged token({String id = 'a', String token = 't'}) =>
        PushTokenChanged(activityId: id, token: token);
    ActivityStateChanged stateChange({
      String id = 'a',
      LiveActivityState state = LiveActivityState.stale,
    }) => ActivityStateChanged(activityId: id, state: state);

    test('equal events compare equal', () {
      expect(enablement(), equals(enablement()));
      expect(token(), equals(token()));
      expect(stateChange(), equals(stateChange()));
    });

    test('events differing in a single field compare unequal', () {
      expect(enablement(), isNot(equals(enablement(enabled: false))));
      expect(token(), isNot(equals(token(id: 'b'))));
      expect(token(), isNot(equals(token(token: 'u'))));
      expect(stateChange(), isNot(equals(stateChange(id: 'b'))));
      expect(
        stateChange(),
        isNot(equals(stateChange(state: LiveActivityState.active))),
      );
    });
  });
}
