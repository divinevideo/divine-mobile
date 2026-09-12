// ABOUTME: Change-email flow for accounts that sign in with email/password
// ABOUTME: Page bridges the Riverpod repository into ChangeEmailCubit

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/change_email/change_email_cubit.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/account_credentials_providers.dart';
import 'package:openvine/screens/settings/general_settings_screen.dart';

/// Page layer: reads the repository from Riverpod and hands it to the cubit.
///
/// The [ValueKey] over the repository is the `state_management.md` guard
/// against a cubit outliving the dependency it captured. It is not what keeps
/// a change on the right account — the repository resolves an owner-bound
/// token per call for that.
class ChangeEmailScreen extends ConsumerWidget {
  const ChangeEmailScreen({super.key});

  static const routeName = 'change-email';
  static const subpath = 'change-email';
  static const path = '/general-settings/$subpath';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(accountCredentialsRepositoryProvider);

    return BlocProvider<ChangeEmailCubit>(
      key: ValueKey(repository),
      create: (_) =>
          ChangeEmailCubit(repository: repository)..loadCurrentEmail(),
      child: const ChangeEmailView(),
    );
  }
}

/// View layer: the form and its confirmation panel, driven entirely by
/// [ChangeEmailCubit].
class ChangeEmailView extends StatefulWidget {
  @visibleForTesting
  const ChangeEmailView({super.key});

  @override
  State<ChangeEmailView> createState() => _ChangeEmailViewState();
}

class _ChangeEmailViewState extends State<ChangeEmailView> {
  final _newEmailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _newEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onChanged(BuildContext context, ChangeEmailState state) {
    final l10n = context.l10n;
    final announcement = switch (state.status) {
      ChangeEmailStatus.editing || ChangeEmailStatus.submitting => null,
      // The whole form is replaced by the confirmation panel, and nothing moves
      // focus into it — without this a screen reader answers a submit with
      // silence.
      ChangeEmailStatus.requestSent =>
        '${l10n.changeEmailSentTitle}. '
            '${l10n.changeEmailSentMessage(state.newEmail.trim())}',
      ChangeEmailStatus.failure => switch (state.failureReason) {
        final reason? => changeEmailFailureMessage(context, reason),
        null => null,
      },
    };
    if (announcement == null) return;

    SemanticsService.sendAnnouncement(
      View.of(context),
      announcement,
      Directionality.of(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.accountSettingsChangeEmail,
        showBackButton: true,
        onBackPressed: () =>
            context.safePop(fallback: GeneralSettingsScreen.path),
      ),
      backgroundColor: context.vineColors.background,
      body: BlocConsumer<ChangeEmailCubit, ChangeEmailState>(
        listener: _onChanged,
        builder: (context, state) {
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: state.status == ChangeEmailStatus.requestSent
                    ? _RequestSent(newEmail: state.newEmail.trim())
                    : _Form(
                        state: state,
                        newEmailController: _newEmailController,
                        passwordController: _passwordController,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.state,
    required this.newEmailController,
    required this.passwordController,
  });

  final ChangeEmailState state;
  final TextEditingController newEmailController;
  final TextEditingController passwordController;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ChangeEmailCubit>();
    final currentEmail = state.currentEmail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 16,
              children: [
                const SizedBox(height: 8),
                Text(
                  context.l10n.changeEmailSubtitle,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.secondaryText,
                  ),
                ),
                if (currentEmail != null)
                  Text(
                    context.l10n.changeEmailCurrentAddress(currentEmail),
                    style: VineTheme.bodyMediumFont(
                      color: context.vineColors.primaryText,
                    ),
                  ),
                AutofillGroup(
                  child: Column(
                    spacing: 16,
                    children: [
                      DivineAuthTextField(
                        controller: newEmailController,
                        label: context.l10n.changeEmailNewLabel,
                        enabled: !state.isSubmitting,
                        autocorrect: false,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        errorText: _newEmailErrorText(
                          context,
                          state.newEmailError,
                        ),
                        textInputAction: TextInputAction.next,
                        onChanged: cubit.updateNewEmail,
                      ),
                      DivineAuthTextField(
                        controller: passwordController,
                        label: context.l10n.changeEmailPasswordLabel,
                        obscureText: true,
                        enabled: !state.isSubmitting,
                        autofillHints: const [AutofillHints.password],
                        errorText: state.passwordMissing
                            ? context.l10n.authPasswordRequired
                            : null,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => cubit.submit(),
                        onChanged: cubit.updatePassword,
                        showPasswordSemanticLabel:
                            context.l10n.authShowPassword,
                        hidePasswordSemanticLabel:
                            context.l10n.authHidePassword,
                      ),
                    ],
                  ),
                ),
                if (state.failureReason != null)
                  _FailureMessage(reason: state.failureReason!),
              ],
            ),
          ),
        ),
        DivineButton(
          expanded: true,
          label: context.l10n.changeEmailSubmit,
          isLoading: state.isSubmitting,
          onPressed: state.canSubmit ? cubit.submit : null,
        ),
        SizedBox(
          height: 32 + MediaQuery.viewPaddingOf(context).bottom,
        ),
      ],
    );
  }

  String? _newEmailErrorText(BuildContext context, NewEmailFieldError? error) =>
      switch (error) {
        NewEmailFieldError.missing => context.l10n.authEmailRequired,
        NewEmailFieldError.invalid => context.l10n.authEmailInvalid,
        NewEmailFieldError.sameAsCurrent =>
          context.l10n.changeEmailSameAsCurrent,
        null => null,
      };
}

/// What is true after Keycast accepts the request: two links are in flight and
/// nothing has changed yet.
class _RequestSent extends StatelessWidget {
  const _RequestSent({required this.newEmail});

  final String newEmail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 16,
              children: [
                const SizedBox(height: 8),
                Text(
                  context.l10n.changeEmailSentTitle,
                  style: VineTheme.titleMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
                Text(
                  context.l10n.changeEmailSentMessage(newEmail),
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.secondaryText,
                  ),
                ),
                DivineInfoCard(
                  icon: DivineIconName.envelope,
                  compact: true,
                  message: context.l10n.changeEmailSentExpiry,
                ),
              ],
            ),
          ),
        ),
        DivineButton(
          expanded: true,
          label: context.l10n.changeEmailSentDone,
          onPressed: () =>
              context.safePop(fallback: GeneralSettingsScreen.path),
        ),
        SizedBox(height: 32 + MediaQuery.viewPaddingOf(context).bottom),
      ],
    );
  }
}

/// The refusal copy for [reason].
///
/// Shared by the rendered message and the screen-reader announcement so the
/// two cannot drift.
@visibleForTesting
String changeEmailFailureMessage(
  BuildContext context,
  ChangeEmailFailureReason reason,
) {
  final l10n = context.l10n;
  return switch (reason) {
    ChangeEmailFailureReason.wrongPassword => l10n.changeEmailWrongPassword,
    ChangeEmailFailureReason.invalidEmail => l10n.authEmailInvalid,
    ChangeEmailFailureReason.needsSignIn => l10n.accountCredentialsNeedsSignIn,
    ChangeEmailFailureReason.rateLimited => l10n.accountCredentialsRateLimited,
    ChangeEmailFailureReason.network => l10n.accountCredentialsNetwork,
    ChangeEmailFailureReason.unknown => l10n.accountCredentialsUnknown,
  };
}

/// Why the change was refused, in copy the user can act on.
class _FailureMessage extends StatelessWidget {
  const _FailureMessage({required this.reason});

  final ChangeEmailFailureReason reason;

  @override
  Widget build(BuildContext context) {
    return Text(
      changeEmailFailureMessage(context, reason),
      style: VineTheme.bodyMediumFont(color: VineTheme.error),
    );
  }
}
