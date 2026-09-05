// ABOUTME: Welcome screen with returning-user variant and new-user variant
// ABOUTME: Page/View pattern with WelcomeBloc for state management
// DESIGN: https://www.figma.com/design/rp1DsDEUuCaicW0lk6I2aZ/UI-Design?node-id=6562-57240

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/welcome/welcome_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/startup_performance_provider.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/minor_account_review_screen.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/auth/auth_hero_section.dart';
import 'package:openvine/widgets/error_message.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:url_launcher/url_launcher.dart';

/// Welcome screen — Page that provides [WelcomeBloc] and auth state.
class WelcomeScreen extends ConsumerWidget {
  /// Route name for this screen.
  static const routeName = 'welcome';

  /// Path for this route.
  static const String path = RoutePaths.welcome;

  /// Path for login options route.
  static const String loginOptionsPath = RoutePaths.welcomeLoginOptions;

  /// Path for create account route.
  static const createAccountPath = '/welcome/create-account';

  /// Path for reset password route.
  static const String resetPasswordPath = RoutePaths.welcomeResetPassword;

  /// Query parameter key for pre-selecting an account on the welcome screen.
  static const selectedPubkeyParam = 'selectedPubkey';

  /// Build a welcome path with a pre-selected account pubkey.
  static String pathWithSelectedPubkey(String pubkeyHex) => Uri(
    path: path,
    queryParameters: {selectedPubkeyParam: pubkeyHex},
  ).toString();

  /// Build a login-options path with optional recovery context prefilled.
  static String loginOptionsPathWithRecovery({String? email, String? error}) {
    final queryParameters = <String, String>{};

    if (email != null && email.isNotEmpty) {
      queryParameters['email'] = email;
    }
    if (error != null && error.isNotEmpty) {
      queryParameters['error'] = error;
    }

    return Uri(
      path: loginOptionsPath,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    ).toString();
  }

  const WelcomeScreen({this.initialSelectedPubkeyHex, super.key});

  /// Optional pubkey to pre-select on the welcome screen.
  final String? initialSelectedPubkeyHex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(currentAuthStateProvider);
    final authService = ref.watch(authServiceProvider);
    final db = ref.watch(databaseProvider);
    final deletionPendingPubkeyHex = ref
        .watch(submittedAccountDeletionAttemptProvider)
        ?.pubkeyHex;

    final isAuthLoading =
        authState == AuthState.checking ||
        authState == AuthState.authenticating;

    return BlocProvider(
      create: (_) =>
          WelcomeBloc(
            userProfilesDao: db.userProfilesDao,
            authService: authService,
            deletionPendingPubkeyHex: deletionPendingPubkeyHex,
          )..add(
            WelcomeStarted(initialSelectedPubkeyHex: initialSelectedPubkeyHex),
          ),
      child: _WelcomeView(
        isAuthLoading: isAuthLoading,
        lastError: authService.lastError,
      ),
    );
  }
}

/// Welcome screen — View that consumes [WelcomeBloc] state.
class _WelcomeView extends ConsumerWidget {
  const _WelcomeView({required this.isAuthLoading, required this.lastError});

  /// Whether the global auth state is in a loading state.
  final bool isAuthLoading;

  /// Auth service error to display, if any.
  final String? lastError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocConsumer<WelcomeBloc, WelcomeState>(
      listenWhen: (prev, current) =>
          current.status == WelcomeStatus.navigatingToLoginOptions ||
          current.status == WelcomeStatus.navigatingToCreateAccount ||
          current.status == WelcomeStatus.navigatingToAccountDeletionRecovery ||
          current.status == WelcomeStatus.error ||
          current.status == WelcomeStatus.sessionExpired ||
          current.status == WelcomeStatus.accountRestoreFailed,
      listener: (context, state) {
        switch (state.status) {
          case WelcomeStatus.navigatingToCreateAccount:
            context.push(WelcomeScreen.createAccountPath);
          case WelcomeStatus.navigatingToLoginOptions:
            context.push(WelcomeScreen.loginOptionsPath);
          case WelcomeStatus.navigatingToAccountDeletionRecovery:
            context.go(RoutePaths.accountDeletionRecovery);
          case WelcomeStatus.sessionExpired:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.authSessionExpired),
                backgroundColor: VineTheme.error,
              ),
            );
          case WelcomeStatus.accountRestoreFailed:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.authAccountRestoreFailed),
                backgroundColor: VineTheme.error,
              ),
            );
          case WelcomeStatus.error:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.authSignInFailed),
                backgroundColor: VineTheme.error,
              ),
            );
          default:
            break;
        }
      },
      builder: (context, state) {
        if (state.status == WelcomeStatus.loaded) {
          ref.read(startupPerformanceServiceProvider).markAuthShellReady();
        }

        final isLoading = isAuthLoading || state.isAccepting;

        final isReturningUser = state.hasReturningUsers;
        return Scaffold(
          backgroundColor: isReturningUser
              ? context.vineColors.nav
              : context.vineColors.background,
          appBar: isReturningUser
              ? DiVineAppBar(
                  title: '',
                  leadingIcon: SvgIconSource(DivineIconName.x.assetPath),
                  leadingActionSemanticLabel: context.l10n.commonClose,
                  onLeadingPressed: () {
                    final bloc = context.read<WelcomeBloc>();
                    // If a specific account was pre-selected (account-switcher
                    // flow), cancel the switch and restore the previous account.
                    // Otherwise, sign back in with the default selected account.
                    if (bloc.state.selectedPubkeyHex != null) {
                      bloc.add(const WelcomeCancelSwitchRequested());
                    } else {
                      bloc.add(const WelcomeLogBackInRequested());
                    }
                  },
                )
              : null,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: isReturningUser
                  ? _ReturningUserLayout(
                      state: state,
                      isLoading: isLoading,
                      lastError: lastError,
                    )
                  : _NewUserLayout(isLoading: isLoading, lastError: lastError),
            ),
          ),
        );
      },
    );
  }
}

/// Default layout for new users — AuthHeroSection with create/login buttons.
class _NewUserLayout extends StatelessWidget {
  const _NewUserLayout({required this.isLoading, required this.lastError});

  final bool isLoading;
  final String? lastError;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Expanded(child: Center(child: AuthHeroSection())),

        if (lastError != null) ...[
          ErrorMessage(message: lastError),
          const SizedBox(height: 16),
        ],

        if (!isLoading) ...[
          Text(
            context.l10n.authMinAgeNotice,
            textAlign: TextAlign.center,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          const _Under16Choices(),
          const SizedBox(height: 16),
          const _TermsNotice(),
          const SizedBox(height: 20),
          DivineButton(
            label: context.l10n.authCreateNewAccount,
            expanded: true,
            semanticIdentifier: SemanticIds.authCreateAccountButton,
            onPressed: () => context.read<WelcomeBloc>().add(
              const WelcomeCreateAccountRequested(),
            ),
          ),
          const SizedBox(height: 12),
          DivineButton(
            label: context.l10n.authSignInDifferentAccount,
            expanded: true,
            type: .secondary,
            semanticIdentifier: SemanticIds.authSignInButton,
            onPressed: () => context.read<WelcomeBloc>().add(
              const WelcomeLoginOptionsRequested(),
            ),
          ),
        ],

        const SizedBox(height: 32),
      ],
    );
  }
}

/// Returning-user layout with profile info and log back in button.
class _ReturningUserLayout extends StatelessWidget {
  const _ReturningUserLayout({
    required this.state,
    required this.isLoading,
    required this.lastError,
  });

  final WelcomeState state;
  final bool isLoading;
  final String? lastError;

  @override
  Widget build(BuildContext context) {
    final account = state.selectedAccount;
    if (account == null) return const SizedBox.shrink();
    final displayName =
        account.profile?.bestDisplayName ??
        UserProfile.defaultDisplayNameFor(account.pubkeyHex);

    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            children: [
              // Profile section
              _ReturningUserProfile(
                pubkeyHex: account.pubkeyHex,
                profile: account.profile,
              ),

              // Session-recovery banner: visible when sign-out left an anchor
              // so the welcome screen can explain where local drafts/clips
              // live before the user confirms a sign-in.
              if (state.hasRecoveryAnchor)
                _CrossAccountRecoveryBanner(
                  isSelectedAccountAnchor:
                      account.pubkeyHex == state.recoveryAnchorPubkeyHex,
                ),

              const Spacer(),

              if (lastError != null) ...[
                ErrorMessage(message: lastError),
                const SizedBox(height: 16),
              ],

              const _TermsNotice(),

              const SizedBox(height: 20),

              // Continue with the selected local account.
              DivineButton(
                label: context.l10n.authContinueAs(displayName),
                isLoading: isLoading,
                expanded: true,
                semanticIdentifier: SemanticIds.authContinueAsButton,
                onPressed: () => context.read<WelcomeBloc>().add(
                  const WelcomeLogBackInRequested(),
                ),
              ),

              const SizedBox(height: 12),

              // Login with another account.
              DivineButton(
                label: context.l10n.authUseAnotherAccount,
                expanded: true,
                type: .secondary,
                semanticIdentifier: SemanticIds.authUseAnotherAccountButton,
                onPressed: isLoading
                    ? null
                    : () => context.read<WelcomeBloc>().add(
                        const WelcomeLoginOptionsRequested(),
                      ),
              ),

              const SizedBox(height: 12),

              // Create a separate account.
              DivineButton(
                label: context.l10n.authCreateNewAccountShort,
                expanded: true,
                type: .secondary,
                semanticIdentifier: SemanticIds.authCreateAccountButton,
                onPressed: isLoading
                    ? null
                    : () => context.read<WelcomeBloc>().add(
                        const WelcomeCreateAccountRequested(),
                      ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }
}

/// Contextual banner shown when sign-out left a session-recovery anchor.
///
/// When [isSelectedAccountAnchor] is true the selected account IS the anchor
/// account (the safe default), so the banner reassures the user that their
/// local drafts/clips belong here. When false, the user has explicitly switched
/// the dropdown to a different account, and the banner warns that those
/// drafts/clips will be hidden after sign-in.
class _CrossAccountRecoveryBanner extends StatefulWidget {
  const _CrossAccountRecoveryBanner({required this.isSelectedAccountAnchor});

  final bool isSelectedAccountAnchor;

  @override
  State<_CrossAccountRecoveryBanner> createState() =>
      _CrossAccountRecoveryBannerState();
}

class _CrossAccountRecoveryBannerState
    extends State<_CrossAccountRecoveryBanner> {
  String? _announcedMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final message = _message(context);
    if (_announcedMessage == message) return;
    _announcedMessage = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      );
    });
  }

  String _message(BuildContext context) {
    return widget.isSelectedAccountAnchor
        ? context.l10n.authRecoveryDraftsOwner
        : context.l10n.authRecoveryOtherAccountWarning;
  }

  @override
  Widget build(BuildContext context) {
    final message = _message(context);
    final chip = context.vineColors.accentChipYellow;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: chip.container,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          spacing: 8,
          children: [
            ExcludeSemantics(
              child: DivineIcon(
                icon: DivineIconName.warningCircle,
                size: 16,
                color: chip.onContainer,
              ),
            ),
            Expanded(
              child: Text(
                message,
                style: VineTheme.bodySmallFont(color: chip.onContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays the returning user's avatar, display name, identifier, and auth
/// source badge.
class _ReturningUserProfile extends StatelessWidget {
  const _ReturningUserProfile({required this.pubkeyHex, required this.profile});

  final String pubkeyHex;
  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final displayName =
        profile?.bestDisplayName ??
        UserProfile.defaultDisplayNameFor(pubkeyHex);

    final identifier =
        profile?.shortDisplayNip05 ?? NostrKeyUtils.truncateNpub(pubkeyHex);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AvatarWithSwitchButton(
          imageUrl: profile?.picture,
          displayName: displayName,
          pubkeyHex: pubkeyHex,
        ),
        const SizedBox(height: 16),
        Text(
          displayName,
          style: VineTheme.headlineSmallFont(
            color: context.vineColors.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          identifier,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _AvatarWithSwitchButton extends StatelessWidget {
  const _AvatarWithSwitchButton({
    required this.imageUrl,
    required this.displayName,
    required this.pubkeyHex,
  });

  final String? imageUrl;
  final String displayName;
  final String pubkeyHex;

  static const double _avatarSize = 144;

  @override
  Widget build(BuildContext context) {
    return UserAvatar(
      imageUrl: imageUrl,
      name: displayName,
      placeholderSeed: pubkeyHex,
      size: _avatarSize,
    );
  }
}

/// Passive terms notice text with clickable links.
class _TermsNotice extends StatefulWidget {
  const _TermsNotice();

  @override
  State<_TermsNotice> createState() => _TermsNoticeState();
}

class _TermsNoticeState extends State<_TermsNotice> {
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;
  late final TapGestureRecognizer _safetyRecognizer;
  late final TapGestureRecognizer _ageAuthorizationRecognizer;

  Future<void> _openUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => _openUrl('https://divine.video/terms');
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => _openUrl('https://divine.video/privacy');
    _safetyRecognizer = TapGestureRecognizer()
      ..onTap = () => _openUrl('https://divine.video/safety');
    _ageAuthorizationRecognizer = TapGestureRecognizer()
      ..onTap = () => context.push(MinorAccountReviewScreen.pathFor());
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    _safetyRecognizer.dispose();
    _ageAuthorizationRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final linkStyle = TextStyle(
      color: context.vineColors.primaryText,
      decoration: TextDecoration.underline,
      decorationColor: context.vineColors.accentPositive,
    );

    return RichText(
      textAlign: TextAlign.center,
      textScaler: MediaQuery.textScalerOf(context),
      text: TextSpan(
        style: VineTheme.bodySmallFont(color: context.vineColors.secondaryText),
        children: [
          TextSpan(text: context.l10n.authTermsPrefix),
          TextSpan(
            text: context.l10n.authTermsAgeAuthorizationCta,
            style: linkStyle,
            recognizer: _ageAuthorizationRecognizer,
          ),
          TextSpan(text: context.l10n.authTermsAfterAgeAuthorization),
          TextSpan(
            text: context.l10n.authTermsOfService,
            style: linkStyle,
            recognizer: _termsRecognizer,
          ),
          const TextSpan(text: ', '),
          TextSpan(
            text: context.l10n.authPrivacyPolicy,
            style: linkStyle,
            recognizer: _privacyRecognizer,
          ),
          TextSpan(text: context.l10n.authTermsAnd),
          TextSpan(
            text: context.l10n.authSafetyStandards,
            style: linkStyle,
            recognizer: _safetyRecognizer,
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}

/// Inline link that lets under-16 users discover the family-guidance flow.
///
/// Renders "Not 16 yet? That's OK." in white, followed by the tappable
/// "Here are your choices." call-to-action in `accentPositive`.
class _Under16Choices extends StatefulWidget {
  const _Under16Choices();

  @override
  State<_Under16Choices> createState() => _Under16ChoicesState();
}

class _Under16ChoicesState extends State<_Under16Choices> {
  late final TapGestureRecognizer _ctaRecognizer;

  @override
  void initState() {
    super.initState();
    _ctaRecognizer = TapGestureRecognizer()
      ..onTap = () => context.push(MinorAccountReviewScreen.pathFor());
  }

  @override
  void dispose() {
    _ctaRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          context.l10n.authUnder16Prefix + context.l10n.authUnder16ChoicesCta,
      child: RichText(
        textAlign: TextAlign.center,
        textScaler: MediaQuery.textScalerOf(context),
        text: TextSpan(
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.primaryText,
          ),
          children: [
            TextSpan(text: context.l10n.authUnder16Prefix),
            TextSpan(
              text: context.l10n.authUnder16ChoicesCta,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.accentPositive,
              ),
              recognizer: _ctaRecognizer,
            ),
          ],
        ),
      ),
    );
  }
}
