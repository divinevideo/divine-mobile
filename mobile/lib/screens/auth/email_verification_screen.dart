// ABOUTME: Screen to handle email verification via polling or token
// ABOUTME: Supports polling mode (after registration) and token mode (from deep link)
// ABOUTME: Supports auto-login on cold start via persisted verification data

import 'dart:async';
import 'dart:math';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/email_verification/email_verification_cubit.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_bloc.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_event.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_state.dart';
import 'package:openvine/l10n/email_verification_error_l10n.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/pending_verification_restore_policy.dart';
import 'package:openvine/utils/sensitive_uri_for_logs.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:url_launcher/url_launcher.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  /// Route name for navigation
  static const String routeName = 'verify-email';

  /// Path for navigation
  static const String path = RoutePaths.emailVerification;

  const EmailVerificationScreen({
    super.key,
    this.token,
    this.deviceCode,
    this.verifier,
    this.email,
    this.restored = false,
  });

  /// Token from deep link (token mode)
  final String? token;

  /// Device code from registration (polling mode)
  final String? deviceCode;

  /// PKCE verifier from registration (polling mode)
  final String? verifier;

  /// User's email address (polling mode)
  final String? email;

  /// Whether the screen was restored on a cold start from the persisted
  /// pending-verification record (see `pendingEmailVerificationRestoreLocation`
  /// in the router). When true, the close / "Start over" affordance is treated
  /// as an escape hatch: it clears the persisted record so the user can
  /// register or log in as a different user without being restored back here.
  final bool restored;

  /// Check if this is polling mode
  bool get isPollingMode =>
      deviceCode != null && deviceCode!.isNotEmpty && verifier != null;

  /// Check if this is token mode
  bool get isTokenMode => token != null && token!.isNotEmpty;

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  /// Offset of the floating close button from the top-start corner.
  static const double _closeButtonInset = 16;

  /// Clears the floating close button: its inset plus the box a small
  /// [DivineIconButton] occupies. That box is `scaleSize(48)`, so it grows
  /// with the icon text scale and a fixed 64 would let the button sit on the
  /// content at large accessibility sizes.
  double _contentTopPadding(BuildContext context) =>
      _closeButtonInset + DivineIcon.scaleSize(context, 48);

  bool _isTokenMode = false;
  StreamSubscription<AuthState>? _authSubscription;
  late final EmailVerificationCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<EmailVerificationCubit>();

    // Clear any stale state from a previous verification (e.g., User A
    // verified successfully, now User B's deep link opens this screen).
    _cubit.reset();

    // Use post-frame callback to access context safely
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVerification();
      _listenForAuthState();
    });
  }

  /// Listen for auth state changes and navigate away when authenticated.
  ///
  /// GoRouter's `refreshListenable` redirect is unreliable for navigating
  /// away from this screen after sign-in completes. This listener provides
  /// an explicit, reliable navigation path.
  void _listenForAuthState() {
    final authService = ref.read(authServiceProvider);
    _authSubscription = authService.authStateStream.listen((authState) {
      if (authState == AuthState.authenticated && mounted) {
        Log.info(
          'Auth state became authenticated, navigating to explore '
          '(cubit=${_cubit.hashCode})',
          name: 'EmailVerificationScreen',
          category: LogCategory.auth,
        );
        _cubit.stopPolling();
        ref.read(pendingVerificationServiceProvider).clear();
        context.read<InviteGateBloc>().add(const InviteGateAccessCleared());
        context.go(ExploreScreen.pathForTab('popular'));
      }
    });
  }

  void _initializeVerification() {
    // Start the appropriate verification mode
    if (widget.isPollingMode) {
      Log.info(
        'Starting polling mode verification (cubit=${_cubit.hashCode})',
        name: 'EmailVerificationScreen',
        category: LogCategory.auth,
      );
      unawaited(_startPollingWithHydratedInvite());
    } else if (widget.restored) {
      // Cold-start restore: the URL deliberately carries no deviceCode /
      // verifier (they are secrets), so rehydrate the full context from the
      // persisted record.
      Log.info(
        'Restoring verification from persisted record (cubit=${_cubit.hashCode})',
        name: 'EmailVerificationScreen',
        category: LogCategory.auth,
      );
      unawaited(_restoreFromPersistedRecord());
    } else if (widget.isTokenMode) {
      // Token mode - check for persisted verification data for auto-login
      _isTokenMode = true;
      _initTokenModeWithPersistenceCheck();
    } else {
      Log.warning(
        'EmailVerificationScreen opened without token or deviceCode',
        name: 'EmailVerificationScreen',
        category: LogCategory.auth,
      );
    }
  }

  /// Starts polling for the URL's device code / verifier (the fresh
  /// post-registration path), hydrating the invite code from the persisted
  /// record.
  ///
  /// The registration URL carries deviceCode/verifier but not the invite, and
  /// the in-memory [InviteGateBloc] grant may already be gone. Reading the
  /// invite from the matching persisted record — mirroring the token-mode path
  /// — keeps the invite so it is consumed on completion. Falls back to the
  /// in-memory grant when no matching record is present.
  Future<void> _startPollingWithHydratedInvite() async {
    final pending = await ref.read(pendingVerificationServiceProvider).load();
    if (!mounted) return;
    final recordInvite =
        (pending != null && pending.deviceCode == widget.deviceCode)
        ? pending.inviteCode
        : null;
    final inviteCode =
        recordInvite ?? context.read<InviteGateBloc>().state.accessGrant?.code;
    _cubit.startPolling(
      deviceCode: widget.deviceCode!,
      verifier: widget.verifier!,
      email: widget.email ?? '',
      inviteCode: inviteCode,
    );
  }

  /// Rehydrates the full verification context from the persisted record and
  /// starts polling, for the cold-start restore path whose URL carries no
  /// secrets (deviceCode / verifier). If no record survives, there is nothing
  /// to restore — leave the screen so the user can use the escape hatch.
  Future<void> _restoreFromPersistedRecord() async {
    final pending = await ref.read(pendingVerificationServiceProvider).load();
    if (!mounted) return;
    if (pending == null) {
      Log.warning(
        'Cold-start restore found no pending record',
        name: 'EmailVerificationScreen',
        category: LogCategory.auth,
      );
      return;
    }
    final authService = ref.read(authServiceProvider);
    if (!canRestorePendingEmailVerification(
      pending: pending,
      authState: authService.authState,
      isAnonymous: authService.isAnonymous,
      currentPublicKeyHex: authService.currentPublicKeyHex,
    )) {
      Log.warning(
        'Cold-start restore rejected for the active identity',
        name: 'EmailVerificationScreen',
        category: LogCategory.auth,
      );
      return;
    }
    _cubit.startPolling(
      deviceCode: pending.deviceCode,
      verifier: pending.verifier,
      email: pending.email,
      inviteCode: pending.inviteCode,
    );
  }

  /// Initialize token mode, checking for persisted data for auto-login.
  ///
  /// If persisted verification data exists (from a previous registration),
  /// we can verify the email and then complete the OAuth flow automatically
  /// instead of requiring the user to log in manually.
  Future<void> _initTokenModeWithPersistenceCheck() async {
    final pendingService = ref.read(pendingVerificationServiceProvider);
    final pending = await pendingService.load();
    if (!mounted) {
      return;
    }

    if (pending != null) {
      Log.info(
        'Found persisted verification data for '
        '${redactEmailForLogs(pending.email)}, '
        'attempting auto-login flow',
        name: 'EmailVerificationScreen',
        category: LogCategory.auth,
      );

      // Verify the email first, then start polling to complete login.
      final result = await _verifyEmailToken(
        widget.token!,
        pendingEmail: pending.email,
      );
      if (!mounted || !result.isSuccess) {
        return;
      }

      _cubit.startPolling(
        deviceCode: pending.deviceCode,
        verifier: pending.verifier,
        email: pending.email,
        inviteCode: pending.inviteCode,
      );
    } else {
      Log.info(
        'No persisted verification data, using standard token mode',
        name: 'EmailVerificationScreen',
        category: LogCategory.auth,
      );
      _verifyWithToken(widget.token!);
    }
  }

  Future<EmailTokenVerificationResult> _verifyEmailToken(
    String token, {
    String? pendingEmail,
    bool keepPollingOnTransient = false,
  }) async {
    final result = await _cubit.verifyEmailToken(
      token: token,
      pendingEmail: pendingEmail,
      keepPollingOnTransient: keepPollingOnTransient,
    );
    if (!mounted) {
      return result;
    }

    if (result.errorCode == EmailVerificationError.emailAlreadyRegistered) {
      unawaited(ref.read(pendingVerificationServiceProvider).clear());
    }
    return result;
  }

  /// Verify email with token (standalone token mode without polling)
  Future<void> _verifyWithToken(String token) async {
    Log.info(
      'Verifying email with token',
      name: 'EmailVerificationScreen',
      category: LogCategory.auth,
    );

    final result = await _verifyEmailToken(token);
    if (!mounted) {
      return;
    }

    if (result.isSuccess) {
      Log.info(
        'Email verification successful (token mode)',
        name: 'EmailVerificationScreen',
        category: LogCategory.auth,
      );
      // In token mode without polling, redirect to login
      _handleTokenModeSuccess();
    }
  }

  Future<void> _verifyDeepLinkToken() async {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      return;
    }

    final result = await _verifyEmailToken(
      token,
      pendingEmail: widget.email ?? _cubit.state.pendingEmail,
      keepPollingOnTransient: true,
    );
    if (!mounted || !result.isSuccess) {
      return;
    }

    // A late link click after the 15-minute poll window: re-arm polling so it
    // auto-completes instead of waiting on manual PIN entry. No-ops unless the
    // cubit is in pollingTimedOut with retained context.
    _cubit.resumePollingAfterTimeout();

    Log.info(
      'Email verification successful from token update',
      name: 'EmailVerificationScreen',
      category: LogCategory.auth,
    );
  }

  @override
  void didUpdateWidget(EmailVerificationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Re-verify when token changes (polling->token OR token->token update).
    // This marks the email as verified on the server, allowing in-progress
    // polling to complete.
    final tokenChanged = widget.token != oldWidget.token;
    if (widget.isTokenMode && tokenChanged) {
      Log.info(
        'Token received via deep link, calling verifyEmail',
        name: 'EmailVerificationScreen',
        category: LogCategory.auth,
      );
      unawaited(_verifyDeepLinkToken());
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    // Stop polling when the screen is disposed (e.g., router redirect after
    // auth). The cubit is app-level so we don't close() it, but we must stop
    // its timers to prevent zombie polling.
    _cubit.stopPolling();
    super.dispose();
  }

  void _handleSuccess() {
    // Clear persisted verification data on successful login
    ref.read(pendingVerificationServiceProvider).clear();

    if (!_isTokenMode) {
      // Polling mode: the auth-state listener navigates to the explore
      // Popular tab (by URL) once sign-in completes.
      Log.info(
        'Email verification succeeded, navigating to explore (Popular tab)',
        name: 'EmailVerificationScreen',
        category: LogCategory.auth,
      );
    } else {
      // Token mode: redirect to login screen
      _handleTokenModeSuccess();
    }
  }

  void _handleTokenModeSuccess() {
    // Clear persisted verification data
    ref.read(pendingVerificationServiceProvider).clear();
    // Show feedback message before redirecting to login
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.authEmailVerifiedLogin),
        backgroundColor: VineTheme.vineGreen,
        duration: const Duration(seconds: 3),
      ),
    );
    // Redirect to login screen
    context.go(WelcomeScreen.loginOptionsPath);
  }

  void _handleCancel() {
    _cubit.stopPolling();
    // On a normal post-registration cancel, don't clear pending verification
    // data — the user may still verify via the email link or PIN later. Data is
    // cleared on successful login, logout, or expiration (24h verify window).
    // On a cold-start restore, closing is the escape hatch ("register / log in
    // as a different user"), so clear the record to avoid restoring back here.
    _maybeClearRestoredRecord();
    // Go back to previous screen (registration form)
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _handleStartOver() {
    // Start Over is a terminal exit: verification failed and the persisted
    // record is unusable, so clear it unconditionally (not just in restored
    // mode) so a later cold start doesn't restore the user into a dead flow.
    ref.read(pendingVerificationServiceProvider).clear();
    context.go('/');
  }

  void _handleSignInRecovery(String? email, EmailVerificationError errorCode) {
    _cubit.stopPolling();
    ref.read(pendingVerificationServiceProvider).clear();
    context.read<InviteGateBloc>().add(const InviteGateAccessCleared());
    context.go(
      WelcomeScreen.loginOptionsPathWithRecovery(
        email: email,
        error: context.l10n.emailVerificationErrorMessage(errorCode),
      ),
    );
  }

  /// Clears the persisted pending-verification record when this screen was
  /// restored on a cold start, so leaving it doesn't trap the user back here.
  void _maybeClearRestoredRecord() {
    if (!widget.restored) return;
    ref.read(pendingVerificationServiceProvider).clear();
  }

  void _handleInviteRecovery(
    String inviteCode,
    EmailVerificationError? errorCode,
  ) {
    _cubit.stopPolling();
    ref.read(pendingVerificationServiceProvider).clear();
    context.read<InviteGateBloc>().add(const InviteGateAccessCleared());
    final errorReason = switch (errorCode) {
      EmailVerificationError.inviteAlreadyUsed ||
      EmailVerificationError.inviteInvalid => InviteGateError.inviteUnavailable,
      EmailVerificationError.inviteTemporary => InviteGateError.checkFailed,
      EmailVerificationError.inviteUnknown => InviteGateError.unknown,
      null => null,
      _ => InviteGateError.unknown,
    };
    context.go(
      WelcomeScreen.inviteGatePathWithCode(
        inviteCode,
        errorReason: errorReason,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.background,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        // Each listener is edge-triggered on its own field. One listener over
        // the union of fields re-fires every announcement that happens to be
        // true whenever any single field moves, so a resend after polling had
        // already stopped would repeat "we stopped checking" and interrupt
        // itself.
        child: MultiBlocListener(
          listeners: [
            BlocListener<EmailVerificationCubit, EmailVerificationState>(
              listenWhen: (previous, current) =>
                  previous.status != current.status &&
                  current.status == EmailVerificationStatus.success,
              listener: (context, state) => _handleSuccess(),
            ),
            BlocListener<EmailVerificationCubit, EmailVerificationState>(
              listenWhen: (previous, current) =>
                  previous.status != current.status &&
                  current.status == EmailVerificationStatus.pollingTimedOut,
              listener: (context, state) => SemanticsService.sendAnnouncement(
                View.of(context),
                context.l10n.authVerificationPollingStopped,
                Directionality.of(context),
              ),
            ),
            BlocListener<EmailVerificationCubit, EmailVerificationState>(
              listenWhen: (previous, current) =>
                  previous.resendStatus != current.resendStatus &&
                  current.resendStatus == ResendStatus.unavailable,
              listener: (context, state) => SemanticsService.sendAnnouncement(
                View.of(context),
                context.l10n.authVerificationResendUnavailable,
                Directionality.of(context),
              ),
            ),
            BlocListener<EmailVerificationCubit, EmailVerificationState>(
              listenWhen: (previous, current) =>
                  previous.resendStatus != current.resendStatus &&
                  current.resendStatus == ResendStatus.failure,
              listener: (context, state) => SemanticsService.sendAnnouncement(
                View.of(context),
                context.l10n.authVerificationResendFailed,
                Directionality.of(context),
              ),
            ),
            BlocListener<EmailVerificationCubit, EmailVerificationState>(
              listenWhen: (previous, current) =>
                  previous.resendStatus != current.resendStatus &&
                  current.resendStatus == ResendStatus.expired,
              listener: (context, state) => SemanticsService.sendAnnouncement(
                View.of(context),
                context.l10n.authVerificationResendExpired,
                Directionality.of(context),
              ),
            ),
            BlocListener<EmailVerificationCubit, EmailVerificationState>(
              listenWhen: (previous, current) =>
                  (previous.pinStatus != current.pinStatus ||
                      previous.pinErrorCode != current.pinErrorCode) &&
                  current.pinStatus == PinSubmissionStatus.failure,
              listener: (context, state) => SemanticsService.sendAnnouncement(
                View.of(context),
                context.l10n.emailVerificationErrorMessage(
                  state.pinErrorCode ?? EmailVerificationError.pinFailed,
                ),
                Directionality.of(context),
              ),
            ),
          ],
          child: BlocBuilder<EmailVerificationCubit, EmailVerificationState>(
            builder: (context, state) {
              final showCloseButton =
                  state.status != EmailVerificationStatus.success;
              final startsOver =
                  state.status == EmailVerificationStatus.failure;
              return Stack(
                children: [
                  // Main content. The keyboard is not resized away
                  // (`resizeToAvoidBottomInset: false`), so shrink the scroll
                  // viewport by the inset instead: PIN entry and its submit
                  // button stay reachable while the keyboard is up.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    // Focus dismissal is not an accessibility action; exclude
                    // this detector so it does not make the whole screen tap.
                    excludeFromSemantics: true,
                    onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      child: CustomScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        slivers: [
                          // Fills the viewport so the content's `Spacer`s can
                          // center it, and scrolls once it no longer fits.
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                24,
                                _contentTopPadding(context),
                                24,
                                32,
                              ),
                              child: switch (state.status) {
                                EmailVerificationStatus.initial =>
                                  _PollingContent(
                                    email: null,
                                    isPollingMode:
                                        widget.isPollingMode || !_isTokenMode,
                                  ),
                                EmailVerificationStatus.polling =>
                                  _PollingContent(
                                    email: state.pendingEmail,
                                    isPollingMode:
                                        widget.isPollingMode || !_isTokenMode,
                                  ),
                                EmailVerificationStatus.pollingTimedOut =>
                                  _PollingContent(
                                    email: state.pendingEmail,
                                    isPollingMode:
                                        widget.isPollingMode || !_isTokenMode,
                                    isActivelyPolling: false,
                                  ),
                                EmailVerificationStatus.success =>
                                  const _SuccessContent(),
                                EmailVerificationStatus.failure =>
                                  _ErrorContent(
                                    errorCode: state.errorCode,
                                    onStartOver: _handleStartOver,
                                    onSignInInstead:
                                        state.errorCode ==
                                            EmailVerificationError
                                                .emailAlreadyRegistered
                                        ? () => _handleSignInRecovery(
                                            state.pendingEmail,
                                            state.errorCode!,
                                          )
                                        : null,
                                    onReturnToInviteGate:
                                        state.showInviteGateRecovery &&
                                            state.inviteRecoveryCode != null
                                        ? () => _handleInviteRecovery(
                                            state.inviteRecoveryCode!,
                                            state.errorCode,
                                          )
                                        : null,
                                  ),
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Close affordance (hidden on success), floating above the
                  // scrolling content so it never shifts with it.
                  if (showCloseButton)
                    PositionedDirectional(
                      top: _closeButtonInset,
                      start: _closeButtonInset,
                      child: DivineIconButton(
                        type: .secondary,
                        onPressed: startsOver
                            ? _handleStartOver
                            : _handleCancel,
                        size: .small,
                        icon: .x,
                        semanticLabel: startsOver
                            ? context.l10n.authStartOver
                            : context.l10n.commonClose,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Status button with a spinner (non-interactive).
class _StatusButton extends StatelessWidget {
  const _StatusButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(
          color: VineTheme.vineGreenDark.withValues(alpha: 0.5),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: DivineCircularProgressIndicator(
              strokeWidth: 2,
              color: VineTheme.vineGreenDark.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: context.vineColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Polling/loading content shown while waiting for email verification.
class _PollingContent extends StatelessWidget {
  const _PollingContent({
    required this.email,
    required this.isPollingMode,
    this.isActivelyPolling = true,
  });

  final String? email;
  final bool isPollingMode;

  /// Whether the poll loop is still running. When the 15-minute window
  /// elapses this becomes false: the spinner is dropped but PIN entry / resend
  /// stay available instead of a terminal failure screen.
  final bool isActivelyPolling;

  Future<void> _openEmailApp() async {
    Log.info(
      'Opening email app (platform=${defaultTargetPlatform.name})',
      name: 'EmailVerification',
      category: LogCategory.auth,
    );

    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        // Use AndroidIntent to fire ACTION_MAIN + APP_EMAIL which opens
        // the default email app's inbox (not compose).
        const intent = AndroidIntent(
          action: 'android.intent.action.MAIN',
          category: 'android.intent.category.APP_EMAIL',
          flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        );
        await intent.launch();
        Log.info(
          'Android email intent launched successfully',
          name: 'EmailVerification',
          category: LogCategory.auth,
        );
      } else {
        // iOS: 'message://' opens the Mail inbox directly
        final launched = await launchUrl(
          Uri.parse('message://'),
          mode: LaunchMode.externalApplication,
        );
        Log.info(
          'iOS message:// launch result: $launched',
          name: 'EmailVerification',
          category: LogCategory.auth,
        );
      }
    } catch (e) {
      Log.warning(
        'Primary email launch failed: $e',
        name: 'EmailVerification',
        category: LogCategory.auth,
      );
      // Fallback: mailto: opens the email app (compose view)
      try {
        await launchUrl(
          Uri(scheme: 'mailto'),
          mode: LaunchMode.externalApplication,
        );
        Log.info(
          'Fallback mailto: launched',
          name: 'EmailVerification',
          category: LogCategory.auth,
        );
      } catch (fallbackError) {
        Log.warning(
          'Fallback mailto: also failed: $fallbackError',
          name: 'EmailVerification',
          category: LogCategory.auth,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),

        // Email sticker
        Transform.rotate(
          angle: -8 * pi / 180,
          child: const DivineSticker(
            sticker: DivineStickerName.email,
            size: 120,
          ),
        ),
        const SizedBox(height: 32),

        // Title
        Text(
          isPollingMode
              ? context.l10n.authCompleteRegistration
              : context.l10n.authVerifying,
          style: TextStyle(
            fontFamily: VineTheme.fontFamilyBricolage,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: context.vineColors.primaryText,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        if (isPollingMode && email != null && email!.isNotEmpty) ...[
          Text(
            context.l10n.authVerificationLinkSent,
            style: TextStyle(
              fontSize: 16,
              color: context.vineColors.secondaryText,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            email!,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.vineColors.primaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.authClickVerificationLink,
            style: TextStyle(
              fontSize: 14,
              color: context.vineColors.secondaryText,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ] else ...[
          Text(
            context.l10n.authPleaseWaitVerifying,
            style: TextStyle(
              fontSize: 16,
              color: context.vineColors.secondaryText,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],

        const Spacer(),

        // Status + action buttons at bottom
        Padding(
          padding: const EdgeInsets.only(top: 32),
          child: Column(
            children: [
              if (isPollingMode) ...[
                const _PinEntrySection(),
                const SizedBox(height: 20),
              ],
              if (isActivelyPolling)
                _StatusButton(
                  label: context.l10n.authWaitingForVerification,
                )
              else
                Text(
                  context.l10n.authVerificationPollingStopped,
                  style: VineTheme.bodySmallFont(
                    color: context.vineColors.secondaryText,
                  ),
                  textAlign: TextAlign.center,
                ),
              if (isPollingMode) ...[
                const SizedBox(height: 20),
                DivineButton(
                  expanded: true,
                  type: DivineButtonType.secondary,
                  label: context.l10n.authOpenEmailApp,
                  onPressed: _openEmailApp,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// In-app PIN entry: a 6-digit code field the user reads from the verification
/// email, submitted to keycast as a fallback when the email link / poll never
/// completes (e.g. sandboxed in-app browsers). Additive — shown alongside the
/// link/poll affordances, never replacing them.
class _PinEntrySection extends StatefulWidget {
  const _PinEntrySection();

  @override
  State<_PinEntrySection> createState() => _PinEntrySectionState();
}

class _PinEntrySectionState extends State<_PinEntrySection> {
  static const _pinLength = 6;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.length != _pinLength) return;
    if (context.read<EmailVerificationCubit>().state.pinStatus ==
        PinSubmissionStatus.submitting) {
      return;
    }
    context.read<EmailVerificationCubit>().submitPin(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pinStatus = context.select(
      (EmailVerificationCubit c) => c.state.pinStatus,
    );
    final pinErrorCode = context.select(
      (EmailVerificationCubit c) => c.state.pinErrorCode,
    );
    final submitting = pinStatus == PinSubmissionStatus.submitting;
    final errorText = pinStatus == PinSubmissionStatus.failure
        ? l10n.emailVerificationErrorMessage(
            pinErrorCode ?? EmailVerificationError.pinFailed,
          )
        : null;
    final canSubmit = _controller.text.length == _pinLength && !submitting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.authVerificationPinPrompt,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.secondaryText,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        // Material wrap keeps the field's ink / overlay layer stable across the
        // verification screen's route transitions.
        Material(
          type: MaterialType.transparency,
          child: DivineAuthTextField(
            label: l10n.authVerificationPinFieldLabel,
            controller: _controller,
            enabled: !submitting,
            autocorrect: false,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_pinLength),
            ],
            errorText: errorText,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(height: 16),
        DivineButton(
          expanded: true,
          label: l10n.authVerificationPinSubmit,
          isLoading: submitting,
          onPressed: canSubmit ? _submit : null,
        ),
        const SizedBox(height: 12),
        const _ResendRow(),
      ],
    );
  }
}

/// Resend-verification affordance with the 5-minute cooldown surfaced.
class _ResendRow extends StatelessWidget {
  const _ResendRow();

  static String _formatCooldown(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final resendStatus = context.select(
      (EmailVerificationCubit c) => c.state.resendStatus,
    );
    final cooldownSeconds = context.select(
      (EmailVerificationCubit c) => c.state.resendCooldownSeconds,
    );
    // `unavailable` stays tappable: the only cause is a server build without
    // the resend-pin route, so a session spanning that deploy should be able
    // to tap again and have it work. A repeat tap before then just re-shows
    // the same message.
    final disabled =
        resendStatus == ResendStatus.sending ||
        resendStatus == ResendStatus.cooldown ||
        resendStatus == ResendStatus.expired;
    final label = resendStatus == ResendStatus.cooldown
        ? l10n.authVerificationResendCooldown(_formatCooldown(cooldownSeconds))
        : l10n.authVerificationResend;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.authVerificationResendPrompt,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.secondaryText,
              ),
            ),
            const SizedBox(width: 4),
            Semantics(
              button: true,
              enabled: !disabled,
              label: label,
              // `ExcludeSemantics` sits inside the detector, not around it:
              // wrapping the detector drops its own `SemanticsAction.tap`
              // along with the subtree, leaving a node that announces a
              // button VoiceOver cannot activate.
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: disabled
                    ? null
                    : () => context
                          .read<EmailVerificationCubit>()
                          .resendVerification(),
                child: ExcludeSemantics(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: VineTheme.labelLargeFont(
                          color: disabled
                              ? context.vineColors.secondaryText
                              : context.vineColors.accentPositive,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (resendStatus == ResendStatus.failure) ...[
          const SizedBox(height: 4),
          Text(
            l10n.authVerificationResendFailed,
            style: VineTheme.bodySmallFont(color: VineTheme.error),
            textAlign: TextAlign.center,
          ),
        ] else if (resendStatus == ResendStatus.expired) ...[
          const SizedBox(height: 4),
          Text(
            l10n.authVerificationResendExpired,
            style: VineTheme.bodySmallFont(color: VineTheme.error),
            textAlign: TextAlign.center,
          ),
        ] else if (resendStatus == ResendStatus.unavailable) ...[
          const SizedBox(height: 4),
          Text(
            l10n.authVerificationResendUnavailable,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// Success content shown briefly when email is verified.
class _SuccessContent extends StatelessWidget {
  const _SuccessContent();

  @override
  Widget build(BuildContext context) {
    // Navigation happens automatically via BlocConsumer listener
    // This UI is shown briefly during the transition
    return Column(
      children: [
        const Spacer(),

        // Shaka sticker (celebration)
        const DivineSticker(sticker: DivineStickerName.hangLoose, size: 120),
        const SizedBox(height: 32),

        Text(
          context.l10n.authWelcomeToDivine,
          style: TextStyle(
            fontFamily: VineTheme.fontFamilyBricolage,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: context.vineColors.primaryText,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.authEmailVerified,
          style: TextStyle(
            fontSize: 16,
            color: context.vineColors.secondaryText,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),

        const Spacer(),

        // Signing you in status button
        _StatusButton(label: context.l10n.authSigningYouIn),
      ],
    );
  }
}

/// Error content shown when verification fails.
class _ErrorContent extends StatelessWidget {
  const _ErrorContent({
    required this.onStartOver,
    required this.errorCode,
    this.onSignInInstead,
    this.onReturnToInviteGate,
  });

  final VoidCallback onStartOver;
  final EmailVerificationError? errorCode;
  final VoidCallback? onSignInInstead;
  final VoidCallback? onReturnToInviteGate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final message = errorCode == null
        ? l10n.authVerificationFailed
        : l10n.emailVerificationErrorMessage(errorCode!);
    return Column(
      children: [
        const Spacer(),

        // Siren sticker
        const DivineSticker(sticker: DivineStickerName.policeSiren, size: 120),
        const SizedBox(height: 32),

        Text(
          l10n.authErrorTitle,
          style: TextStyle(
            fontFamily: VineTheme.fontFamilyBricolage,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: context.vineColors.primaryText,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          message,
          style: TextStyle(
            fontSize: 16,
            color: context.vineColors.secondaryText,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),

        const Spacer(),

        // Start over button
        DivineButton(
          expanded: true,
          label: onSignInInstead != null
              ? l10n.authSignInButton
              : onReturnToInviteGate == null
              ? l10n.authStartOver
              : l10n.authBackToInviteCode,
          onPressed: onSignInInstead ?? onReturnToInviteGate ?? onStartOver,
        ),
      ],
    );
  }
}
