// ABOUTME: Riverpod compatibility bridge for server-backed OG Diviner eligibility.
// ABOUTME: Keeps existing ConsumerWidget identity surfaces reactive during BLoC migration.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/services/og_diviner_eligibility_service.dart';

final ogDivinerEligibilityServiceProvider =
    Provider<OgDivinerEligibilityService>((ref) {
      return OgDivinerEligibilityService(
        keycast: ref.watch(oauthClientProvider),
      );
    });

final FutureProviderFamily<bool, String> ogDivinerEligibilityProvider =
    FutureProvider.family<bool, String>((
      ref,
      pubkey,
    ) {
      return ref.watch(ogDivinerEligibilityServiceProvider).isEligible(pubkey);
    });
