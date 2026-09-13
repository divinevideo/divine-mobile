// ABOUTME: Tests for the in-app review coordinator Cubit.
// ABOUTME: Verifies prompt ordering, cooldown writes, mount checks, and guard.

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:app_update_repository/app_update_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/app_review/app_review_coordinator_cubit.dart';
import 'package:openvine/services/app_review_prompt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingSink implements AnalyticsEventSink {
  final List<({String name, Map<String, Object> parameters})> events = [];

  @override
  Future<void> setUserId(String? userId) async {}

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    events.add((name: name, parameters: parameters));
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {}
}

class _FakeReviewPlatform implements AppReviewPlatform {
  bool available = true;
  Completer<bool>? availabilityCompleter;
  Completer<void>? availabilityStarted;
  Object? requestError;
  int availabilityChecks = 0;
  int requests = 0;
  VoidCallback? onRequest;

  @override
  Future<bool> isAvailable() async {
    availabilityChecks++;
    availabilityStarted?.complete();
    final pendingAvailability = availabilityCompleter;
    if (pendingAvailability != null) return pendingAvailability.future;
    return available;
  }

  @override
  Future<void> requestReview() async {
    requests++;
    onRequest?.call();
    final error = requestError;
    if (error != null) throw error;
  }
}

class _FakeFrameScheduler implements AppReviewFrameScheduler {
  bool result = true;
  final completer = Completer<bool>();
  int waits = 0;

  @override
  Future<bool> waitForStableFrame() {
    waits++;
    if (completer.isCompleted) return Future.value(result);
    return completer.future;
  }

  void complete([bool? value]) {
    completer.complete(value ?? result);
  }
}

typedef VoidCallback = void Function();

void main() {
  const pubkey = 'pubkey-a';

  ReviewEligibilityInputs inputs({
    int videoCount = 50,
    InstallSource installSource = InstallSource.playStore,
    int sessionCount = 20,
    int daysSinceFirstLaunch = 30,
  }) {
    return ReviewEligibilityInputs(
      pubkey: pubkey,
      videoCount: videoCount,
      installSource: installSource,
      sessionCount: sessionCount,
      daysSinceFirstLaunch: daysSinceFirstLaunch,
    );
  }

  group(AppReviewCoordinatorCubit, () {
    late SharedPreferences prefs;
    late AppReviewPromptService service;
    late _RecordingSink analytics;
    late _FakeReviewPlatform platform;
    late _FakeFrameScheduler frameScheduler;
    late AppReviewCoordinatorCubit cubit;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      service = AppReviewPromptService(sharedPreferences: prefs);
      analytics = _RecordingSink();
      platform = _FakeReviewPlatform();
      frameScheduler = _FakeFrameScheduler();
      cubit = AppReviewCoordinatorCubit(
        service: service,
        analytics: analytics,
        reviewPlatform: platform,
        frameScheduler: frameScheduler,
      );
    });

    tearDown(() => cubit.close());

    test('does not burn cooldown when native review is unavailable', () async {
      platform.available = false;

      final evaluation = cubit.evaluate(inputs: inputs(), isActive: () => true);
      frameScheduler.complete();
      await evaluation;

      expect(platform.availabilityChecks, 1);
      expect(platform.requests, 0);
      expect(prefs.getInt('review_prompt_attempted_at_$pubkey'), isNull);
      expect(analytics.events, isEmpty);
    });

    test('does not burn cooldown when the frame wait fails', () async {
      final evaluation = cubit.evaluate(inputs: inputs(), isActive: () => true);
      frameScheduler.complete(false);
      await evaluation;

      expect(platform.availabilityChecks, 0);
      expect(platform.requests, 0);
      expect(prefs.getInt('review_prompt_attempted_at_$pubkey'), isNull);
    });

    test('does not burn cooldown when unmounted after frame wait', () async {
      var mounted = true;
      var mountChecks = 0;

      final evaluation = cubit.evaluate(
        inputs: inputs(),
        isActive: () {
          mountChecks++;
          if (mountChecks > 1) mounted = false;
          return mounted;
        },
      );
      frameScheduler.complete();
      await evaluation;

      expect(platform.availabilityChecks, 0);
      expect(platform.requests, 0);
      expect(prefs.getInt('review_prompt_attempted_at_$pubkey'), isNull);
    });

    test(
      'does not burn cooldown when account changes during availability check',
      () async {
        final availabilityCompleter = Completer<bool>();
        final availabilityStarted = Completer<void>();
        platform.availabilityCompleter = availabilityCompleter;
        platform.availabilityStarted = availabilityStarted;
        var isActive = true;

        final evaluation = cubit.evaluate(
          inputs: inputs(),
          isActive: () => isActive,
        );
        frameScheduler.complete();
        await availabilityStarted.future;

        isActive = false;
        availabilityCompleter.complete(true);
        await evaluation;

        expect(platform.requests, 0);
        expect(prefs.getInt('review_prompt_attempted_at_$pubkey'), isNull);
        expect(analytics.events, isEmpty);
      },
    );

    test('records cooldown immediately before requesting review', () async {
      final order = <String>[];
      platform.onRequest = () {
        order.add('requestReview');
        expect(prefs.getInt('review_prompt_attempted_at_$pubkey'), isNotNull);
      };

      final evaluation = cubit.evaluate(inputs: inputs(), isActive: () => true);
      frameScheduler.complete();
      await evaluation;

      expect(order, ['requestReview']);
      expect(platform.requests, 1);
      expect(analytics.events.map((event) => event.name), [
        'in_app_review_eligible',
        'in_app_review_prompted',
      ]);
    });

    test(
      'keeps cooldown when requestReview throws and tracks failure',
      () async {
        platform.requestError = StateError('platform failed');

        final evaluation = cubit.evaluate(
          inputs: inputs(),
          isActive: () => true,
        );
        frameScheduler.complete();
        await evaluation;

        expect(platform.requests, 1);
        expect(prefs.getInt('review_prompt_attempted_at_$pubkey'), isNotNull);
        expect(analytics.events.map((event) => event.name), [
          'in_app_review_eligible',
          'in_app_review_request_failed',
        ]);
      },
    );

    test('ignores a second evaluation while one is in flight', () async {
      final first = cubit.evaluate(inputs: inputs(), isActive: () => true);
      await cubit.evaluate(inputs: inputs(), isActive: () => true);

      expect(frameScheduler.waits, 1);
      frameScheduler.complete();
      await first;

      expect(platform.requests, 1);
    });

    test('stops cleanly when closed during frame wait', () async {
      final evaluation = cubit.evaluate(inputs: inputs(), isActive: () => true);

      await cubit.close();
      frameScheduler.complete();

      await expectLater(evaluation, completes);
      expect(platform.availabilityChecks, 0);
      expect(platform.requests, 0);
      expect(prefs.getInt('review_prompt_attempted_at_$pubkey'), isNull);
    });
  });
}
