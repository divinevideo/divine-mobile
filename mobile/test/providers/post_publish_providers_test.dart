// ABOUTME: Proves the post-publish experiment reads the existing feature flag.
// ABOUTME: Keeps the disabled path on normal control behavior.

import 'package:analytics/analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/post_publish/post_publish_experiment.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/post_publish_providers.dart';

class _NoopAnalytics implements AnalyticsEventSink {
  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {}

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> setUserId(String? userId) async {}
}

void main() {
  String treatmentUser() {
    final reference = PostPublishExperiment(analytics: _NoopAnalytics());
    return List.generate(
      1000,
      (index) => index.toRadixString(16).padLeft(64, '0'),
    ).firstWhere(
      (pubkey) =>
          reference.variantForUser(pubkey) == PostPublishVariant.viewShare,
    );
  }

  group('postPublishExperimentProvider', () {
    test('off switch forces the post-publish experiment into control', () {
      final container = ProviderContainer(
        overrides: [
          analyticsEventSinkProvider.overrideWithValue(_NoopAnalytics()),
          isFeatureEnabledProvider(
            FeatureFlag.postPublishConfirmationExperiment,
          ).overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      final configured = container.read(postPublishExperimentProvider);

      expect(
        configured.variantForUser(treatmentUser()),
        PostPublishVariant.control,
      );
    });

    test(
      'A/A switch keeps assignments but suppresses treatment behavior',
      () async {
        final container = ProviderContainer(
          overrides: [
            analyticsEventSinkProvider.overrideWithValue(_NoopAnalytics()),
            isFeatureEnabledProvider(
              FeatureFlag.postPublishConfirmationExperiment,
            ).overrideWithValue(true),
            isFeatureEnabledProvider(
              FeatureFlag.postPublishConfirmationTreatment,
            ).overrideWithValue(false),
          ],
        );
        addTearDown(container.dispose);
        final configured = container.read(postPublishExperimentProvider);
        final variant = configured.variantForUser(treatmentUser());

        await configured.screenShown(
          publishId: 'publish-1',
          destination: 'profile',
          variant: variant,
        );

        expect(variant, PostPublishVariant.viewShare);
        expect(configured.completed({'publish-1'}), isNull);
      },
    );
  });
}
