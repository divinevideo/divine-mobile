// ABOUTME: Pre-auth invite gate for waitlist-only and invite-code onboarding
// ABOUTME: Uses the invite server config to block or allow new account creation

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:openvine/blocs/invite_availability/invite_availability_cubit.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_bloc.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_event.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_state.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/invite_gate_error_l10n.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/invite_availability.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/utils/validators.dart';
import 'package:openvine/widgets/auth/auth_error_box.dart';
import 'package:openvine/widgets/auth_back_button.dart';
import 'package:openvine/widgets/rounded_icon_button.dart';
import 'package:url_launcher/url_launcher.dart';

class InviteGateScreen extends StatefulWidget {
  const InviteGateScreen({
    super.key,
    this.initialCode,
    this.initialError,
    this.initialErrorReason,
    this.initialSourceSlug,
  });

  static const String routeName = 'invite-gate';
  static const String path = '/invite';

  final String? initialCode;
  final String? initialError;
  final InviteGateError? initialErrorReason;
  final String? initialSourceSlug;

  @override
  State<InviteGateScreen> createState() => _InviteGateScreenState();
}

class _InviteGateScreenState extends State<InviteGateScreen> {
  late TextEditingController _inviteCodeController;
  String? _waitlistEmail;

  @override
  void initState() {
    super.initState();
    _inviteCodeController = TextEditingController(
      text: widget.initialCode == null
          ? ''
          : InviteApiClient.normalizeCode(widget.initialCode!),
    );
    final inviteGateBloc = context.read<InviteGateBloc>();
    inviteGateBloc.add(const InviteGateTransientCleared());
    final initialErrorReason = widget.initialErrorReason;
    if (initialErrorReason != null) {
      inviteGateBloc.add(InviteGateGeneralErrorSet(initialErrorReason));
    } else if (widget.initialError != null && widget.initialError!.isNotEmpty) {
      // Only the FACT of an upstream error survives the link; its text does
      // not. Trusted in-app recovery links use the allowlisted errorReason
      // parameter instead.
      inviteGateBloc.add(
        const InviteGateGeneralErrorSet(InviteGateError.unknown),
      );
    }
  }

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  void _validateInviteCode() {
    final normalizedCode = InviteApiClient.normalizeCode(
      _inviteCodeController.text,
    );
    _inviteCodeController.value = TextEditingValue(
      text: normalizedCode,
      selection: TextSelection.collapsed(offset: normalizedCode.length),
    );
    context.read<InviteGateBloc>().add(InviteGateCodeSubmitted(normalizedCode));
  }

  Future<void> _showWaitlistSheet(InviteClientConfig config) async {
    final sourceSlug =
        context.read<InviteGateBloc>().state.accessGrant?.creatorSlug ??
        widget.initialSourceSlug;
    final joinedEmail = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WaitlistEntrySheet(
        inviteApiClient: context.read<InviteApiClient>(),
        supportEmail: config.supportEmail,
        sourceSlug: sourceSlug,
      ),
    );

    if (joinedEmail != null && mounted) {
      setState(() {
        _waitlistEmail = joinedEmail;
      });
    }
  }

  Future<void> _contactSupport(String supportEmail) async {
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      queryParameters: {'subject': context.l10n.authInviteAccessHelp},
    );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.authCouldNotOpenEmail(supportEmail)),
          backgroundColor: VineTheme.error,
        ),
      );
    }
  }

  void _redirectToCreateAccount() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !context.read<InviteAvailabilityCubit>().state.isEnabled) {
        final queryParameters = <String, String>{
          if (widget.initialCode?.isNotEmpty ?? false)
            'code': widget.initialCode!,
          // Preserve the error signal if onboarding flips back to invite-only;
          // the invite gate discards the raw text before rendering it. See
          // #8305 for removing this parameter from the remaining auth routes.
          if (widget.initialError?.isNotEmpty ?? false)
            'error': widget.initialError!,
          if (widget.initialSourceSlug?.isNotEmpty ?? false)
            'sourceSlug': widget.initialSourceSlug!,
        };
        context.go(
          Uri(
            path: WelcomeScreen.createAccountPath,
            queryParameters: queryParameters.isEmpty ? null : queryParameters,
          ).toString(),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final waitlistEmail = _waitlistEmail;

    if (waitlistEmail != null) {
      return _InviteSheetPage(
        showBackButton: false,
        illustrationAsset: 'assets/stickers/confetti.svg',
        title: context.l10n.authWaitlistConfirmTitle,
        body: Text(
          context.l10n.authWaitlistUpdatesAt(waitlistEmail),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            height: 1.5,
            letterSpacing: 0.15,
            color: context.vineColors.mutedText,
          ),
        ),
        primaryButton: DivineButton(
          type: .secondary,
          label: context.l10n.authOk,
          onPressed: () => context.go(WelcomeScreen.path),
        ),
      );
    }

    return BlocBuilder<InviteAvailabilityCubit, InviteAvailabilityState>(
      builder: (context, availability) {
        if (!availability.isEnabled) {
          _redirectToCreateAccount();
          return const _InviteLoadingPage();
        }
        if (!availability.hasResolved) {
          return const _InviteLoadingPage();
        }

        final config = availability.resolvedConfig;
        return BlocConsumer<InviteGateBloc, InviteGateState>(
          listenWhen: (previous, current) =>
              previous.accessGrant != current.accessGrant &&
              current.accessGrant != null,
          listener: (context, state) {
            context.go(WelcomeScreen.createAccountPath);
          },
          builder: (context, state) {
            return _InviteCodeEntryPage(
              controller: _inviteCodeController,
              state: state,
              onChanged: () => context.read<InviteGateBloc>().add(
                const InviteGateTransientCleared(),
              ),
              onBack: () => context.pop(),
              onSubmit: _validateInviteCode,
              onShowWaitlist: () => _showWaitlistSheet(config),
              onContactSupport: () => _contactSupport(config.supportEmail),
            );
          },
        );
      },
    );
  }
}

class _InviteLoadingPage extends StatelessWidget {
  const _InviteLoadingPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.background,
      body: Center(
        child: DivineCircularProgressIndicator(
          color: context.vineColors.accentPositive,
        ),
      ),
    );
  }
}

class _InviteCodeEntryPage extends StatelessWidget {
  const _InviteCodeEntryPage({
    required this.controller,
    required this.state,
    required this.onChanged,
    required this.onBack,
    required this.onSubmit,
    required this.onShowWaitlist,
    required this.onContactSupport,
  });

  final TextEditingController controller;
  final InviteGateState state;
  final VoidCallback onChanged;
  final VoidCallback onBack;
  final VoidCallback onSubmit;
  final VoidCallback onShowWaitlist;
  final VoidCallback onContactSupport;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.background,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Positioned(
                  top: constraints.maxHeight / 2 - 80,
                  left: -36,
                  child: Transform.rotate(
                    angle: 12 * 3.14159 / 180,
                    child: const DivineSticker(sticker: .confetti, size: 174),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: CustomScrollView(
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 16),
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: RoundedIconButton(
                                  onPressed: onBack,
                                  semanticLabel: context.l10n.commonBack,
                                  semanticIdentifier:
                                      DiVineAppBarLeading.backButtonSemanticId,
                                  icon: DivineIcon(
                                    icon: DivineIconName.caretLeft,
                                    color: context.vineColors.onIconButton,
                                    size: 28,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                context.l10n.authAddInviteCode,
                                style: TextStyle(
                                  fontFamily: VineTheme.fontFamilyBricolage,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  color: context.vineColors.primaryText,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 32),
                              _InviteCodeInput(
                                controller: controller,
                                enabled: !state.isValidatingCode,
                                errorText: switch (state.inviteCodeError) {
                                  null => null,
                                  final error =>
                                    context.l10n.inviteCodeErrorMessage(error),
                                },
                                onChanged: onChanged,
                                onSubmitted: onSubmit,
                              ),
                              if (state.generalError != null) ...[
                                const SizedBox(height: 16),
                                AuthErrorBox(
                                  message: context.l10n.inviteGateErrorMessage(
                                    state.generalError!,
                                  ),
                                ),
                              ],

                              const Spacer(),

                              const SizedBox(height: 24),
                              DivineButton(
                                expanded: true,
                                label: context.l10n.authNext,
                                semanticIdentifier:
                                    SemanticIds.authInviteSubmitButton,
                                isLoading: state.isValidatingCode,
                                onPressed: state.isValidatingCode
                                    ? null
                                    : onSubmit,
                              ),
                              const SizedBox(height: 12),
                              DivineButton(
                                expanded: true,
                                type: DivineButtonType.secondary,
                                label: context.l10n.authJoinWaitlist,
                                onPressed: state.isValidatingCode
                                    ? null
                                    : onShowWaitlist,
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: state.isValidatingCode
                                    ? null
                                    : onContactSupport,
                                child: Text(
                                  context.l10n.authContactSupport,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 15,
                                    color: context.vineColors.mutedText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InviteCodeInput extends StatelessWidget {
  const _InviteCodeInput({
    required this.controller,
    required this.enabled,
    required this.onChanged,
    required this.onSubmitted,
    this.errorText,
  });

  final TextEditingController controller;
  final bool enabled;
  final String? errorText;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          identifier: SemanticIds.authInviteCodeField,
          textField: true,
          child: TextField(
            controller: controller,
            enabled: enabled,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9-]')),
              _InviteCodeTextInputFormatter(),
            ],
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: context.vineColors.primaryText,
              letterSpacing: 0.15,
            ),
            decoration: InputDecoration(
              labelText: context.l10n.authInviteCodeLabel,
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: hasError
                    ? VineTheme.error
                    : context.vineColors.accentPositive,
              ),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              hintText: context.l10n.authEnterYourCode,
              hintStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: context.vineColors.disabled,
                letterSpacing: 0.15,
              ),
              filled: true,
              fillColor: context.vineColors.surfaceContainer,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: hasError
                    ? const BorderSide(color: VineTheme.error)
                    : BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(
                  color: hasError
                      ? VineTheme.error
                      : context.vineColors.accentPositive,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
            ),
            onChanged: (_) => onChanged(),
            onSubmitted: (_) => onSubmitted(),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 20),
            child: Text(
              errorText!,
              style: const TextStyle(color: VineTheme.error, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}

class _InviteSheetPage extends StatelessWidget {
  const _InviteSheetPage({
    required this.illustrationAsset,
    required this.title,
    required this.body,
    required this.primaryButton,
    this.showBackButton = true,
  });

  final String illustrationAsset;
  final String title;
  final Widget body;
  final Widget primaryButton;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: context.vineColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Row(
                children: [
                  if (showBackButton)
                    const AuthBackButton()
                  else
                    const SizedBox(width: 48, height: 48),
                ],
              ),
            ),
            const Spacer(),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: context.vineColors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(VineTheme.bottomSheetBorderRadius),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 32,
                    width: double.infinity,
                    alignment: const Alignment(0, -0.2),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: context.vineColors.outlineDisabled,
                        ),
                      ),
                    ),
                    child: Container(
                      width: 64,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.vineColors.disabled,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 32, 16, 16 + safeBottom),
                    child: Column(
                      children: [
                        SvgPicture.asset(
                          illustrationAsset,
                          width: 132,
                          height: 132,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: VineTheme.fontFamilyBricolage,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: context.vineColors.primaryText,
                            height: 1.333,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        body,
                        const SizedBox(height: 32),
                        primaryButton,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaitlistEntrySheet extends StatefulWidget {
  const _WaitlistEntrySheet({
    required this.inviteApiClient,
    required this.supportEmail,
    this.sourceSlug,
  });

  final InviteApiClient inviteApiClient;
  final String supportEmail;
  final String? sourceSlug;

  @override
  State<_WaitlistEntrySheet> createState() => _WaitlistEntrySheetState();
}

class _WaitlistEntrySheetState extends State<_WaitlistEntrySheet> {
  final TextEditingController _emailController = TextEditingController();
  String? _emailError;
  String? _generalError;
  bool _isSubmitting = false;
  bool _newsletterOptIn = true;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final emailError = Validators.validateEmail(
      email,
      messages: AuthValidationMessages.fromL10n(context.l10n),
    );

    if (emailError != null) {
      setState(() {
        _emailError = emailError;
        _generalError = null;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _emailError = null;
      _generalError = null;
    });

    try {
      await widget.inviteApiClient.joinWaitlist(
        contact: email,
        sourceSlug: widget.sourceSlug,
        newsletterOptIn: _newsletterOptIn,
      );
      if (!mounted) return;
      Navigator.of(context).pop(email);
    } on InviteApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _generalError = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _contactSupport() async {
    final launched = await launchUrl(
      Uri(
        scheme: 'mailto',
        path: widget.supportEmail,
        queryParameters: {'subject': context.l10n.authInviteAccessHelp},
      ),
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.authCouldNotOpenEmail(widget.supportEmail),
          ),
          backgroundColor: VineTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 16,
      ),
      child: Material(
        color: context.vineColors.surface,
        borderRadius: BorderRadius.circular(VineTheme.bottomSheetBorderRadius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 4,
                decoration: BoxDecoration(
                  color: context.vineColors.disabled,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                context.l10n.authJoinWaitlistTitle,
                style: TextStyle(
                  fontFamily: VineTheme.fontFamilyBricolage,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: context.vineColors.primaryText,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.authJoinWaitlistDescription,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  height: 1.5,
                  letterSpacing: 0.15,
                  color: context.vineColors.mutedText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              MergeSemantics(
                child: Semantics(
                  checked: _newsletterOptIn,
                  enabled: !_isSubmitting,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _isSubmitting
                        ? null
                        : () => setState(() {
                            _newsletterOptIn = !_newsletterOptIn;
                          }),
                    child: DivineCheckbox(
                      state: _newsletterOptIn
                          ? DivineCheckboxState.selected
                          : DivineCheckboxState.unselected,
                      label: Text(
                        context.l10n.authJoinWaitlistNewsletterOptIn,
                        style: VineTheme.bodyLargeFont(
                          color: context.vineColors.mutedText,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              DivineAuthTextField(
                label: context.l10n.authEmailLabel,
                controller: _emailController,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                errorText: _emailError,
                onChanged: (_) {
                  if (_emailError != null || _generalError != null) {
                    setState(() {
                      _emailError = null;
                      _generalError = null;
                    });
                  }
                },
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              if (_generalError != null) ...[
                AuthErrorBox(message: _generalError!),
                const SizedBox(height: 16),
              ],
              DivineButton(
                type: .secondary,
                label: context.l10n.authJoinWaitlist,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submit,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isSubmitting ? null : _contactSupport,
                child: Text(
                  context.l10n.authContactSupport,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    color: context.vineColors.mutedText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteCodeTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = InviteApiClient.normalizeCode(newValue.text);
    // After the 4th character, show a trailing dash so the user knows
    // not to type one themselves. Skip when deleting so backspace
    // isn't trapped by the dash re-appearing.
    final isDeleting = newValue.text.length < oldValue.text.length;
    final display = normalized.length == 4 && !isDeleting
        ? '$normalized-'
        : normalized;
    return TextEditingValue(
      text: display,
      selection: TextSelection.collapsed(offset: display.length),
    );
  }
}
