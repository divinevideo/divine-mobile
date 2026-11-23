// ABOUTME: Placeholder screen for Divine Confirmation, the paid tier that lets
// ABOUTME: an account link others by signing in. Nothing can be bought yet.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/supporter_providers.dart';
import 'package:openvine/screens/verify/verify_screen.dart';

/// The Divine Confirmation pitch, with the purchase controls disabled.
///
/// TODO(#8278): replace with the real purchase flow once the store products
/// exist. Until then no purchase call is made from here.
class VerifyConfirmationPage extends ConsumerWidget {
  /// Creates a [VerifyConfirmationPage].
  const VerifyConfirmationPage({super.key});

  /// Route name used by GoRouter.
  static const routeName = 'verify-confirmation';

  /// Route path segment, a child of [VerifyPage.path].
  static const path = 'confirmation';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only the buy controls depend on this: a build no store can bill has
    // nothing to buy with, so it gets a note in their place.
    final canBuy = ref.watch(supporterStoreBillingAvailableProvider);
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;

    return Scaffold(
      appBar: DiVineAppBar(
        title: l10n.verifyConfirmationTitle,
        showBackButton: true,
        // safePop: a registered path can be entered cold with no back stack.
        onBackPressed: () => context.safePop(fallback: VerifyPage.path),
      ),
      backgroundColor: context.vineColors.surface,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const DivineIcon(
                icon: DivineIconName.checkCircle,
                color: VineTheme.accentOrange,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.verifyConfirmationTitle,
                style: textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.verifyConfirmationHeroBody,
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.verifyConfirmationIncludedTitle,
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const DivineIcon(
                    icon: DivineIconName.check,
                    color: VineTheme.accentOrange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.verifyConfirmationIncludedSignIn,
                      style: textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (canBuy) ...[
                // Disabled: no product exists yet, so there is nothing to buy
                // or restore.
                DivineButton(
                  label: l10n.verifyConfirmationComingSoon,
                  semanticLabel: l10n.verifyConfirmationBuySemantic,
                  expanded: true,
                  onPressed: null,
                ),
                const SizedBox(height: 16),
                DivineButton(
                  type: DivineButtonType.link,
                  label: l10n.supporterRestorePurchases,
                  semanticLabel: l10n.verifyConfirmationRestoreSemantic,
                  onPressed: null,
                ),
              ] else
                Text(
                  l10n.verifyConfirmationStoreOnly,
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 32),
              Text(
                l10n.verifyConfirmationSmallPrint,
                style: textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
