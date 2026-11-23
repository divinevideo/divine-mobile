// ABOUTME: Runs a Google or Apple sign-in from the welcome screen: terms,
// ABOUTME: provider token, Keycast session, app sign-in.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/repositories/social_sign_in_repository.dart';
import 'package:openvine/services/auth/account_activation_coordinator.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/social_identity_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:unified_logger/unified_logger.dart';

part 'social_sign_in_state.dart';

/// Signs in with Google or Apple.
///
/// Tapping a provider counts as accepting the terms, like the other buttons
/// on the welcome screen. On success the auth state flips and the router
/// leaves the screen; this cubit only reports progress and failures.
class SocialSignInCubit extends Cubit<SocialSignInState>
    with CloseGuardedEmit<SocialSignInState> {
  SocialSignInCubit({
    required SocialSignInRepository repository,
    required AuthService authService,
    required bool enabled,
  }) : _repository = repository,
       _authService = authService,
       super(
         SocialSignInState(
           availableProviders: enabled
               ? [
                   for (final provider in _displayOrder)
                     if (repository.isAvailable(provider)) provider,
                 ]
               : const [],
         ),
       );

  /// Apple first where it is offered, as Apple's guidelines show it.
  static const List<SocialProvider> _displayOrder = [
    SocialProvider.apple,
    SocialProvider.google,
  ];

  final SocialSignInRepository _repository;
  final AuthService _authService;

  Future<void> signIn(SocialProvider provider) async {
    if (state.isBusy || !state.availableProviders.contains(provider)) return;
    emit(
      state.copyWith(
        status: SocialSignInStatus.inProgress,
        activeProvider: provider,
      ),
    );

    try {
      await _authService.acceptTerms();
      final session = await _repository.signIn(provider);
      await _authService.signInWithDivineOAuth(session);
      // signInWithDivineOAuth reports most failures through the auth state
      // instead of throwing.
      if (!_authService.isAuthenticated) {
        _fail(provider, SocialSignInFailureReason.failed, 'not authenticated');
        return;
      }
      emitIfOpen(state.copyWith(status: SocialSignInStatus.signedIn));
    } on SocialIdentityException catch (e) {
      switch (e.failure) {
        case SocialIdentityFailure.cancelled:
          emitIfOpen(state.copyWith(status: SocialSignInStatus.idle));
        case SocialIdentityFailure.unavailable:
          _fail(provider, SocialSignInFailureReason.unavailable, e);
        case SocialIdentityFailure.failed:
          _fail(provider, SocialSignInFailureReason.failed, e);
      }
    } on SocialSignInException catch (e) {
      _fail(provider, _reasonFor(e.failure), e);
    } on UserDataCleanupException catch (e, stackTrace) {
      addError(e, stackTrace);
      _fail(provider, SocialSignInFailureReason.accountCleanupFailed, e);
    } on AccountActivationRetiredException {
      // A newer sign-in or account switch took over; it reports its own
      // outcome.
      emitIfOpen(state.copyWith(status: SocialSignInStatus.idle));
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      _fail(provider, SocialSignInFailureReason.failed, e);
    }
  }

  void _fail(
    SocialProvider provider,
    SocialSignInFailureReason reason,
    Object cause,
  ) {
    Log.warning(
      'Sign in with ${provider.name} failed: ${reason.name} ($cause)',
      name: 'SocialSignInCubit',
      category: LogCategory.auth,
    );
    emitIfOpen(
      state.copyWith(status: SocialSignInStatus.failed, failureReason: reason),
    );
  }

  static SocialSignInFailureReason _reasonFor(SocialLoginFailure failure) =>
      switch (failure) {
        SocialLoginFailure.accountLinkRequired =>
          SocialSignInFailureReason.accountLinkRequired,
        SocialLoginFailure.emailMissing =>
          SocialSignInFailureReason.emailMissing,
        SocialLoginFailure.emailNotVerified =>
          SocialSignInFailureReason.emailNotVerified,
        SocialLoginFailure.providerUnavailable =>
          SocialSignInFailureReason.unavailable,
        SocialLoginFailure.rateLimited => SocialSignInFailureReason.rateLimited,
        SocialLoginFailure.network => SocialSignInFailureReason.network,
        SocialLoginFailure.invalidToken ||
        SocialLoginFailure.unknown => SocialSignInFailureReason.failed,
      };
}
