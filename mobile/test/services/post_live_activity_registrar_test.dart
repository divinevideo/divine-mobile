// ABOUTME: Tests the registrar's account binding rules and its mapping of
// ABOUTME: push service results to Live Activity registrar results.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/post_live_activity_registrar.dart';
import 'package:openvine/services/push_notification_service.dart';
import 'package:post_live_activity_repository/post_live_activity_repository.dart';

class _MockPushService extends Mock implements PushNotificationService {}

class _FakeRegistration extends Fake implements LiveActivityRegistration {}

void main() {
  final owner = 'a' * 64;
  final other = 'b' * 64;
  final registration = LiveActivityRegistration.forPost(
    activityId: 'activity-1',
    ownerPubkey: owner,
    activityPushToken: 'ab12',
    postCoordinate: '34236:$owner:d',
    postEventIds: ['c' * 64],
    postedAt: DateTime.utc(2026, 11, 19),
    showFirstRunNote: false,
  );

  setUpAll(() => registerFallbackValue(_FakeRegistration()));

  late PostLiveActivityRegistrar registrar;
  late _MockPushService push;
  late bool active;
  late bool authorized;

  LiveActivityAccountBinding binding({
    String? ownerPubkey,
    PushNotificationService? Function()? readPush,
    bool Function()? isActive,
  }) => LiveActivityAccountBinding(
    ownerPubkey: ownerPubkey ?? owner,
    readPushService: readPush ?? () => push,
    readNotificationsAuthorized: () async => authorized,
    isActiveAccount: isActive ?? () => active,
  );

  void stubResult(PushRegistrationResult result) {
    when(
      () => push.registerLiveActivity(
        any(),
        any(),
        notificationsAuthorized: any(named: 'notificationsAuthorized'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    registrar = PostLiveActivityRegistrar();
    push = _MockPushService();
    active = true;
    authorized = true;
  });

  group(PostLiveActivityRegistrar, () {
    group('register', () {
      test('retries later when no binding exists yet', () async {
        expect(
          await registrar.register(registration),
          LiveActivityRegistrarResult.retryLater,
        );
      });

      test('retries later when the push service is not ready', () async {
        registrar.attach(binding(readPush: () => null));

        expect(
          await registrar.register(registration),
          LiveActivityRegistrarResult.retryLater,
        );
      });

      test('skips when the account is no longer active', () async {
        registrar.attach(binding());
        active = false;

        expect(
          await registrar.register(registration),
          LiveActivityRegistrarResult.skipped,
        );
        verifyNever(
          () => push.registerLiveActivity(
            any(),
            any(),
            notificationsAuthorized: any(named: 'notificationsAuthorized'),
          ),
        );
      });

      test('ignores bindings for another owner', () async {
        registrar.attach(binding(ownerPubkey: other));

        expect(
          await registrar.register(registration),
          LiveActivityRegistrarResult.retryLater,
        );
      });

      test('passes the owner and notification authorization along', () async {
        authorized = false;
        stubResult(PushRegistrationResult.published);
        registrar.attach(binding());

        await registrar.register(registration);

        verify(
          () => push.registerLiveActivity(
            owner,
            registration,
            notificationsAuthorized: false,
          ),
        ).called(1);
      });

      for (final (pushResult, expected) in [
        (
          PushRegistrationResult.published,
          LiveActivityRegistrarResult.published,
        ),
        (
          PushRegistrationResult.retryableFailure,
          LiveActivityRegistrarResult.retryLater,
        ),
        (
          PushRegistrationResult.uncertainFailure,
          LiveActivityRegistrarResult.uncertain,
        ),
        (
          PushRegistrationResult.terminalFailure,
          LiveActivityRegistrarResult.failed,
        ),
      ]) {
        test('maps $pushResult to $expected', () async {
          stubResult(pushResult);
          registrar.attach(binding());

          expect(await registrar.register(registration), expected);
        });
      }

      test('a terminal failure after the account changed is skipped', () async {
        when(
          () => push.registerLiveActivity(
            any(),
            any(),
            notificationsAuthorized: any(named: 'notificationsAuthorized'),
          ),
        ).thenAnswer((_) async {
          active = false;
          return PushRegistrationResult.terminalFailure;
        });
        registrar.attach(binding());

        expect(
          await registrar.register(registration),
          LiveActivityRegistrarResult.skipped,
        );
      });

      test('a terminal failure after detach is skipped', () async {
        late Object handle;
        when(
          () => push.registerLiveActivity(
            any(),
            any(),
            notificationsAuthorized: any(named: 'notificationsAuthorized'),
          ),
        ).thenAnswer((_) async {
          registrar.detach(handle);
          return PushRegistrationResult.terminalFailure;
        });
        handle = registrar.attach(binding());

        expect(
          await registrar.register(registration),
          LiveActivityRegistrarResult.skipped,
        );
      });
    });

    group('attach and detach', () {
      test('detaching a first binding leaves a later one for the same owner '
          '(A to B to A)', () async {
        stubResult(PushRegistrationResult.published);
        final firstA = registrar.attach(binding());
        final b = registrar.attach(binding(ownerPubkey: other));
        final secondA = registrar.attach(binding());

        registrar.detach(firstA);

        expect(
          await registrar.register(registration),
          LiveActivityRegistrarResult.published,
        );

        registrar
          ..detach(secondA)
          ..detach(b);
        expect(
          await registrar.register(registration),
          LiveActivityRegistrarResult.retryLater,
        );
      });

      test('detaching the same handle twice is harmless', () async {
        final handle = registrar.attach(binding());

        registrar
          ..detach(handle)
          ..detach(handle);

        expect(
          await registrar.register(registration),
          LiveActivityRegistrarResult.retryLater,
        );
      });
    });
  });
}
