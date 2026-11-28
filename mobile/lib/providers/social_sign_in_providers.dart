// ABOUTME: Riverpod wiring for Google and Apple sign-in: the native token
// ABOUTME: service and the repository that trades its token for a session.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/repositories/social_sign_in_repository.dart';
import 'package:openvine/services/social_identity_service.dart';

/// Native Google and Apple sign-in.
///
/// Watches nothing, so it is built once per app: the Google plugin may only
/// be initialized once per process.
final socialIdentityServiceProvider = Provider<SocialIdentityService>(
  (ref) => SocialIdentityService(),
);

/// Trades a Google or Apple token for a Keycast session.
final socialSignInRepositoryProvider = Provider<SocialSignInRepository>(
  (ref) => SocialSignInRepository(
    identityService: ref.watch(socialIdentityServiceProvider),
    oauthClient: ref.watch(oauthClientProvider),
  ),
);
