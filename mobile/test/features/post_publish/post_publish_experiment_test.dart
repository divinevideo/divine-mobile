// ABOUTME: Tests the post-publish confirmation experiment's bucketing and
// ABOUTME: the analytics it emits when View or Share is tapped.

import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/post_publish/post_publish_experiment.dart';

class _RecordingAnalytics implements AnalyticsEventSink {
  final List<({String name, Map<String, Object> parameters})> events = [];

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

  @override
  Future<void> setUserId(String? userId) async {}
}

/// A deterministic 64-hex pubkey for sample [i].
String _syntheticPubkey(int i) => i.toRadixString(16).padLeft(64, '0');

/// A pubkey whose sha256 lands in [variant]'s bucket.
///
/// Only a fixture — it asks the function under test, so it cannot pin the
/// split. `splits the population close to evenly` does that.
String _pubkeyForVariant(PostPublishVariant variant) {
  final experiment = PostPublishExperiment(analytics: _RecordingAnalytics());
  for (var i = 0; i < 1000; i++) {
    final candidate = _syntheticPubkey(i);
    if (experiment.variantForUser(candidate) == variant) return candidate;
  }
  throw StateError('No pubkey found for $variant');
}

void main() {
  group(PostPublishExperiment, () {
    late _RecordingAnalytics analytics;
    late PostPublishExperiment experiment;

    setUp(() {
      analytics = _RecordingAnalytics();
      experiment = PostPublishExperiment(analytics: analytics);
    });

    group('variantForUser', () {
      test('buckets a signed-out user into control', () {
        expect(
          experiment.variantForUser(null),
          equals(PostPublishVariant.control),
        );
      });

      test('is case-insensitive so one account cannot change buckets', () {
        // A signer that returns uppercase hex must not move the account
        // between arms mid-experiment.
        final pubkey = _pubkeyForVariant(PostPublishVariant.viewShare);

        expect(
          experiment.variantForUser(pubkey.toUpperCase()),
          equals(experiment.variantForUser(pubkey)),
        );
      });

      test('splits the population close to evenly', () {
        // The one property an A/B experiment depends on. Asserting a
        // probed fixture lands in the bucket it was probed for is circular
        // and stays green at any threshold; this does not.
        const sampleSize = 1000;
        final treatment = List.generate(sampleSize, _syntheticPubkey)
            .where(
              (pubkey) =>
                  experiment.variantForUser(pubkey) ==
                  PostPublishVariant.viewShare,
            )
            .length;

        expect(treatment / sampleSize, closeTo(0.5, 0.05));
      });
    });

    group('completed', () {
      test('offers the confirmation for a viewShare publish', () async {
        await experiment.screenShown(
          publishId: 'publish-1',
          destination: 'profile',
          variant: PostPublishVariant.viewShare,
        );

        expect(experiment.completed({'publish-1'}), isNotNull);
      });

      test('offers nothing for a control publish', () async {
        await experiment.screenShown(
          publishId: 'publish-1',
          destination: 'profile',
          variant: PostPublishVariant.control,
        );

        expect(experiment.completed({'publish-1'}), isNull);
      });

      test('offers nothing for a publish it never saw', () {
        expect(experiment.completed({'unknown-publish'}), isNull);
      });

      test('does not offer twice for the same publish', () async {
        await experiment.screenShown(
          publishId: 'publish-1',
          destination: 'profile',
          variant: PostPublishVariant.viewShare,
        );
        experiment.completed({'publish-1'});

        expect(experiment.completed({'publish-1'}), isNull);
      });

      test('a failed publish forfeits its offer', () async {
        await experiment.screenShown(
          publishId: 'publish-1',
          destination: 'profile',
          variant: PostPublishVariant.viewShare,
        );
        experiment.failed({'publish-1'});

        expect(experiment.completed({'publish-1'}), isNull);
      });
    });

    group('tap analytics', () {
      test('viewTapped reports elapsed seconds since publish', () async {
        final offer = PostPublishConfirmationOffer(
          publishedAt: DateTime(2026, 8, 15, 12),
        );
        final clocked = PostPublishExperiment(
          analytics: analytics,
          now: () => DateTime(2026, 8, 15, 12, 0, 7),
        );

        await clocked.viewTapped(offer);

        expect(
          analytics.events.single.name,
          equals('post_publish_view_tapped'),
        );
        expect(
          analytics.events.single.parameters['seconds_since_publish'],
          equals(7),
        );
      });

      test('shareTapped logs its own event name', () async {
        await experiment.shareTapped(
          PostPublishConfirmationOffer(publishedAt: DateTime.now()),
        );

        expect(
          analytics.events.single.name,
          equals('post_publish_share_tapped'),
        );
      });

      test('clamps a clock that ran backwards to zero', () async {
        final offer = PostPublishConfirmationOffer(
          publishedAt: DateTime(2026, 8, 15, 12),
        );
        final clocked = PostPublishExperiment(
          analytics: analytics,
          now: () => DateTime(2026, 8, 15, 11, 59),
        );

        await clocked.viewTapped(offer);

        expect(
          analytics.events.single.parameters['seconds_since_publish'],
          equals(0),
        );
      });
    });

    test('screenShown reports the variant under test', () async {
      await experiment.screenShown(
        publishId: 'publish-1',
        destination: 'profile',
        variant: PostPublishVariant.viewShare,
      );

      expect(analytics.events.single.name, equals('post_publish_screen_shown'));
      expect(
        analytics.events.single.parameters['variant'],
        equals('view_share'),
      );
    });

    test(
      'records the first-party exposure only for an assigned user',
      () async {
        final exposures = <PostPublishVariant>[];
        final experimentWithExposure = PostPublishExperiment(
          analytics: analytics,
          recordExposure: (variant) async => exposures.add(variant),
        );

        await experimentWithExposure.screenShown(
          publishId: 'publish-1',
          destination: 'profile',
          variant: PostPublishVariant.control,
          isExperimentExposure: true,
        );
        await experimentWithExposure.screenShown(
          publishId: 'reply-1',
          destination: 'video_reply',
          variant: PostPublishVariant.control,
        );

        expect(exposures, [PostPublishVariant.control]);
      },
    );

    test(
      'disabled experiment stays in control and records no exposure',
      () async {
        final exposures = <PostPublishVariant>[];
        final disabledExperiment = PostPublishExperiment(
          analytics: analytics,
          isEnabled: () => false,
          recordExposure: (variant) async => exposures.add(variant),
        );
        final treatmentUser = _pubkeyForVariant(PostPublishVariant.viewShare);
        final variant = disabledExperiment.variantForUser(treatmentUser);

        await disabledExperiment.screenShown(
          publishId: 'publish-1',
          destination: 'profile',
          variant: variant,
          isExperimentExposure: true,
        );

        expect(variant, PostPublishVariant.control);
        expect(disabledExperiment.completed({'publish-1'}), isNull);
        expect(exposures, isEmpty);
        expect(analytics.events.single.parameters['variant'], 'control');
      },
    );

    test(
      'A/A mode records assignments but gives both groups control',
      () async {
        final exposures = <PostPublishVariant>[];
        final aaExperiment = PostPublishExperiment(
          analytics: analytics,
          isTreatmentEnabled: () => false,
          recordExposure: (variant) async => exposures.add(variant),
        );
        final treatmentUser = _pubkeyForVariant(PostPublishVariant.viewShare);
        final variant = aaExperiment.variantForUser(treatmentUser);

        await aaExperiment.screenShown(
          publishId: 'publish-1',
          destination: 'profile',
          variant: variant,
          isExperimentExposure: true,
        );

        expect(variant, PostPublishVariant.viewShare);
        expect(exposures, [PostPublishVariant.viewShare]);
        expect(aaExperiment.completed({'publish-1'}), isNull);
        expect(analytics.events.single.parameters['variant'], 'view_share');
      },
    );

    test(
      'turning the experiment off drops a confirmation already assigned',
      () async {
        var enabled = true;
        final killSwitchExperiment = PostPublishExperiment(
          analytics: analytics,
          isEnabled: () => enabled,
        );
        final treatmentUser = _pubkeyForVariant(PostPublishVariant.viewShare);

        await killSwitchExperiment.screenShown(
          publishId: 'publish-1',
          destination: 'profile',
          variant: killSwitchExperiment.variantForUser(treatmentUser),
        );
        enabled = false;

        expect(killSwitchExperiment.completed({'publish-1'}), isNull);
      },
    );

    test(
      'an exposure recording failure does not affect the publish flow',
      () async {
        final experimentWithFailure = PostPublishExperiment(
          analytics: analytics,
          recordExposure: (_) => Future<void>.error(StateError('offline')),
        );

        await expectLater(
          experimentWithFailure.screenShown(
            publishId: 'publish-1',
            destination: 'profile',
            variant: PostPublishVariant.viewShare,
            isExperimentExposure: true,
          ),
          completes,
        );
        expect(analytics.events.single.name, 'post_publish_screen_shown');
      },
    );
  });
}
