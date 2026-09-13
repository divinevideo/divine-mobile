// ABOUTME: Riverpod wiring for creator-delete media cleanup enforcement.
// ABOUTME: Scopes the NIP-98 repository and its HTTP client together.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/crash_reporting_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/repositories/creator_delete_enforcement_repository.dart';

final creatorDeleteEnforcementRepositoryProvider =
    Provider<CreatorDeleteEnforcementRepository>((ref) {
      final client = ref.watch(instrumentedHttpClientFactoryProvider)();
      ref.onDispose(client.close);
      final environment = ref.watch(currentEnvironmentProvider);
      return CreatorDeleteEnforcementRepository(
        baseUrl: environment.moderationApiBaseUrl,
        enabled: environment.creatorDeleteEnforcementEnabled,
        httpClient: client,
        nip98AuthService: ref.watch(nip98AuthServiceProvider),
        performanceMonitor: ref.watch(performanceMonitoringServiceProvider),
        shouldBoundSigning: () =>
            ref
                .read(authServiceProvider)
                .currentIdentity
                ?.signsRemotelyNonInteractive ??
            false,
        reportError: (error, stackTrace) => unawaited(
          ref
              .read(crashReportingServiceProvider)
              .recordError(
                Reportable(
                  error,
                  context: 'CreatorDeleteEnforcementRepository',
                ),
                stackTrace,
                reason: 'Creator-delete enforcement contract failure',
              ),
        ),
      );
    });
