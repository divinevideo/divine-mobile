// ABOUTME: Riverpod wiring for the app-wide email confirmation cubit, which the
// ABOUTME: widget tree reads through BlocProvider and the DM send policy reads.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/email_confirmation/email_confirmation_cubit.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/repositories/email_confirmation_repository.dart';
import 'package:openvine/services/auth_service.dart';

/// Reads and resends the signed-in account's email confirmation.
final emailConfirmationRepositoryProvider =
    Provider<EmailConfirmationRepository>((ref) {
      return EmailConfirmationRepository(
        oauthClient: ref.watch(oauthClientProvider),
        // Owner-bound, so a session left behind by another account cannot
        // answer for this one.
        readAccessToken: ref
            .watch(authServiceProvider)
            .activeAccountKeycastToken,
      );
    });

/// The single [EmailConfirmationCubit] behind the profile note, the Messages
/// lock and the DM send policy.
///
/// Provided to the widget tree with `BlocProvider.value` in
/// `AppCompositionRoot`, and pointed at the signed-in account by
/// `EmailConfirmationSync`.
final emailConfirmationCubitProvider = Provider<EmailConfirmationCubit>((ref) {
  final cubit = EmailConfirmationCubit(
    repository: ref.watch(emailConfirmationRepositoryProvider),
  );
  ref.onDispose(cubit.close);
  return cubit;
});

/// Public key (hex) of the signed-in account that has an email to confirm,
/// or null when nobody is signed in or the account signed in without Keycast
/// email and password (local key, bunker, signer app).
final emailConfirmationAccountProvider = Provider<String?>((ref) {
  final authState = ref.watch(currentAuthStateProvider);
  final authService = ref.watch(authServiceProvider);
  final isKeycastAccount =
      authState == AuthState.authenticated &&
      authService.authenticationSource == AuthenticationSource.divineOAuth;
  return isKeycastAccount ? authService.currentPublicKeyHex : null;
});
