// ABOUTME: Locks direct messages behind email confirmation for accounts that
// ABOUTME: signed in before confirming, with a way to resend the link.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/email_confirmation/email_confirmation_cubit.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Shows [child] once the account's email is confirmed, and
/// [ConfirmEmailToMessageView] until then.
///
/// An unknown confirmation state lets the child through: a failed status
/// check must not lock messaging for an account that already confirmed. The
/// DM send policy refuses sends separately, so this gate is the explanation,
/// not the enforcement.
class EmailConfirmationGate extends StatelessWidget {
  const EmailConfirmationGate({
    required this.child,
    this.standalone = false,
    super.key,
  });

  final Widget child;

  /// Whether the gate fills a whole route, so the locked view brings its own
  /// app bar with a way back.
  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final isUnconfirmed = context.select<EmailConfirmationCubit?, bool>(
      (cubit) => cubit?.state.isUnconfirmed ?? false,
    );
    if (!isUnconfirmed) return child;
    if (!standalone) return const ConfirmEmailToMessageView();
    return Scaffold(
      backgroundColor: context.vineColors.background,
      appBar: DiVineAppBar(
        title: context.l10n.emailConfirmationTitle,
        showBackButton: true,
        onBackPressed: () => context.safePop(fallback: RoutePaths.inbox),
        backButtonSemanticLabel: context.l10n.commonBack,
      ),
      body: const SafeArea(child: ConfirmEmailToMessageView()),
    );
  }
}

/// Explains why messaging is locked and offers to resend the link.
class ConfirmEmailToMessageView extends StatelessWidget {
  @visibleForTesting
  const ConfirmEmailToMessageView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final email = context.select<EmailConfirmationCubit, String>(
      (cubit) => cubit.state.email ?? '',
    );
    final isSending = context.select<EmailConfirmationCubit, bool>(
      (cubit) =>
          cubit.state.resendStatus == EmailConfirmationResendStatus.sending,
    );
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DivineSticker(sticker: DivineStickerName.email),
              const SizedBox(height: 32),
              Text(
                l10n.emailConfirmationMessagesTitle,
                style: VineTheme.headlineSmallFont(
                  color: context.vineColors.primaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.emailConfirmationMessagesBody(email),
                style: VineTheme.bodyLargeFont(
                  color: context.vineColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              DivineButton(
                label: l10n.emailConfirmationResendButton,
                expanded: true,
                onPressed: isSending
                    ? null
                    : () => runDetached(
                        context.read<EmailConfirmationCubit>().resend(),
                        'resend confirmation email',
                        logName: 'ConfirmEmailToMessageView',
                        category: LogCategory.auth,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
