import 'package:flutter_test/flutter_test.dart';
import 'package:post_live_activity_repository/post_live_activity_repository.dart';

void main() {
  final postedAt = DateTime.utc(2026, 11, 19, 12);
  final windowEnd = postedAt.add(const Duration(minutes: 60));

  LiveActivityRegistration registration() => LiveActivityRegistration.forPost(
    activityId: 'a1',
    ownerPubkey: 'owner',
    activityPushToken: 'tok',
    postCoordinate: '34236:owner:d',
    postEventIds: const ['e1', 'e2'],
    postedAt: postedAt,
    showFirstRunNote: true,
  );

  group(LiveActivityRegistration, () {
    test('forPost ends the window 60 minutes after posting', () {
      final r = registration();
      expect(r.windowEndsAt, equals(postedAt.add(const Duration(minutes: 60))));
      expect(r.state, equals(LiveActivityRegistrationState.active));
    });

    test('ended returns an ended copy and leaves the original', () {
      final r = registration();
      final ended = r.ended();
      expect(ended.state, equals(LiveActivityRegistrationState.ended));
      expect(r.state, equals(LiveActivityRegistrationState.active));
      expect(ended, isNot(equals(r)));
      expect(ended.activityId, equals(r.activityId));
      expect(ended.windowEndsAt, equals(r.windowEndsAt));
    });

    test('is equal when every field matches', () {
      expect(registration(), equals(registration()));
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
    test('is equal when every field matches', () {
      RunningLiveActivity make() => RunningLiveActivity(
        id: 'a',
        ownerPubkey: 'o',
        startedAt: postedAt,
        state: LiveActivityState.active,
      );
      expect(make(), equals(make()));
      expect(
        make(),
        isNot(
          equals(
            RunningLiveActivity(
              id: 'a',
              ownerPubkey: 'o',
              startedAt: postedAt,
              state: LiveActivityState.ended,
              postEventId: 'e',
            ),
          ),
        ),
      );
    });
  });

  group(LiveActivityPlatformEvent, () {
    // Built at runtime so == compares props rather than a const identity.
    var enabled = true;
    var activityId = 'a';
    var token = 't';
    var state = LiveActivityState.stale;

    test('events compare by value', () {
      expect(
        EnablementChanged(enabled: enabled),
        equals(EnablementChanged(enabled: enabled)),
      );
      expect(
        PushTokenChanged(activityId: activityId, token: token),
        equals(PushTokenChanged(activityId: activityId, token: token)),
      );
      expect(
        ActivityStateChanged(activityId: activityId, state: state),
        equals(ActivityStateChanged(activityId: activityId, state: state)),
      );
      enabled = false;
      activityId = 'b';
      token = 'u';
      state = LiveActivityState.active;
    });
  });
}
