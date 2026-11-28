// ABOUTME: Shown where an account created with Google or Apple hits a password
// ABOUTME: check: explains there is none yet and emails a link to set one

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/password_setup/password_setup_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/account_credentials_providers.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Replaces the "wrong password"-style refusal for an account that has no
/// password at all.
///
/// Keycast sets a first password only from a link it emails to a signed-in
/// account, so this offers that link right here instead of sending the person
/// to "Forgot password", which cannot start it.
class PasswordSetupPrompt extends ConsumerWidget {
  const PasswordSetupPrompt({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(accountCredentialsRepositoryProvider);

    return BlocProvider<PasswordSetupCubit>(
      key: ValueKey(repository),
      create: (_) => PasswordSetupCubit(repository: repository),
      child: const PasswordSetupPromptView(),
    );
  }
}

/// The prompt itself, driven by [PasswordSetupCubit].
class PasswordSetupPromptView extends StatelessWidget {
  @visibleForTesting
  const PasswordSetupPromptView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PasswordSetupCubit, PasswordSetupStatus>(
      listenWhen: (previous, current) => previous != current,
      listener: (context, status) {
        final message = _outcomeMessage(context.l10n, status);
        if (message == null) return;
        // The outcome replaces text in place and nothing moves focus there, so
        // a screen reader would otherwise answer the tap with silence.
        _announce(context, message);
      },
      builder: (context, status) {
        final l10n = context.l10n;
        if (status == PasswordSetupStatus.sent) {
          return Text(
            l10n.accountCredentialsPasswordSetupSent,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          );
        }
        final error = _outcomeMessage(l10n, status);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Text(
              l10n.accountCredentialsPasswordNotSet,
              style: VineTheme.bodyMediumFont(color: VineTheme.error),
            ),
            if (error != null)
              Text(
                error,
                style: VineTheme.bodyMediumFont(color: VineTheme.error),
              ),
            DivineButton(
              label: l10n.accountCredentialsPasswordSetupSend,
              leadingIcon: DivineIconName.envelope,
              type: DivineButtonType.secondary,
              size: DivineButtonSize.small,
              isLoading: status == PasswordSetupStatus.sending,
              onPressed: status == PasswordSetupStatus.sending
                  ? null
                  : () => runDetached(
                      context.read<PasswordSetupCubit>().requestLink(),
                      'request a password setup link',
                      logName: 'PasswordSetupPrompt',
                      category: LogCategory.auth,
                    ),
            ),
          ],
        );
      },
    );
  }

  static void _announce(BuildContext context, String message) =>
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      );

  /// What the last request ended in, or null while there is nothing to report.
  static String? _outcomeMessage(
    AppLocalizations l10n,
    PasswordSetupStatus status,
  ) => switch (status) {
    PasswordSetupStatus.sent => l10n.accountCredentialsPasswordSetupSent,
    PasswordSetupStatus.needsSignIn => l10n.accountCredentialsNeedsSignIn,
    PasswordSetupStatus.failed => l10n.accountCredentialsUnknown,
    PasswordSetupStatus.idle || PasswordSetupStatus.sending => null,
  };
}
