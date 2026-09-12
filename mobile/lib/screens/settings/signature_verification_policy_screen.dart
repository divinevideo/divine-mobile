// ABOUTME: Screen for choosing which relays have their event signatures verified
// ABOUTME: Split out of nostr_settings_screen.dart so it can own a route (#6481)

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/signature_verification_policy/signature_verification_policy_cubit.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/nostr_signature_verification_policy.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/settings/nostr_settings_screen.dart';

class SignatureVerificationPolicyScreen extends ConsumerWidget {
  const SignatureVerificationPolicyScreen({super.key});

  static const routeName = 'signature-verification';
  static const subpath = 'signature-verification';
  static const path = '${NostrSettingsScreen.path}/$subpath';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocProvider(
      create: (_) => SignatureVerificationPolicyCubit(
        preferenceService: ref.read(
          nostrSignatureVerificationPreferenceServiceProvider,
        ),
        onPolicyChanged: () =>
            ref.invalidate(nostrSignatureVerificationPolicyProvider),
      ),
      child: const _SignatureVerificationPolicyView(),
    );
  }
}

class _SignatureVerificationPolicyView extends StatelessWidget {
  const _SignatureVerificationPolicyView();

  @override
  Widget build(BuildContext context) {
    final current = context.watch<SignatureVerificationPolicyCubit>().state;

    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.nostrSettingsSignatureVerification,
        showBackButton: true,
        // safePop: this screen has a registered path, so the back stack
        // can be empty on a cold entry and a raw pop would throw GoError.
        onBackPressed: () =>
            context.safePop(fallback: NostrSettingsScreen.path),
      ),
      backgroundColor: context.vineColors.background,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  context.l10n.nostrSettingsSignatureVerificationIntro,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.mutedText,
                  ),
                ),
              ),
              for (final policy in NostrSignatureVerificationPolicy.values)
                DivineSelectableRow(
                  title: signatureVerificationPolicyTitle(context, policy),
                  subtitle: signatureVerificationPolicySubtitle(
                    context,
                    policy,
                  ),
                  isSelected: policy == current,
                  onTap: () {
                    if (policy == current) return;
                    unawaited(
                      context
                          .read<SignatureVerificationPolicyCubit>()
                          .setPolicy(policy),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Display name for [policy], used by this screen and by the hub tile.
String signatureVerificationPolicyTitle(
  BuildContext context,
  NostrSignatureVerificationPolicy policy,
) {
  switch (policy) {
    case NostrSignatureVerificationPolicy.all:
      return context.l10n.nostrSettingsSignatureVerificationAll;
    case NostrSignatureVerificationPolicy.untrustedRelays:
      return context.l10n.nostrSettingsSignatureVerificationUntrusted;
    case NostrSignatureVerificationPolicy.nonDivineRelays:
      return context.l10n.nostrSettingsSignatureVerificationNonDivine;
  }
}

/// One-line explanation of [policy], used by this screen and by the hub tile.
String signatureVerificationPolicySubtitle(
  BuildContext context,
  NostrSignatureVerificationPolicy policy,
) {
  switch (policy) {
    case NostrSignatureVerificationPolicy.all:
      return context.l10n.nostrSettingsSignatureVerificationAllSubtitle;
    case NostrSignatureVerificationPolicy.untrustedRelays:
      return context.l10n.nostrSettingsSignatureVerificationUntrustedSubtitle;
    case NostrSignatureVerificationPolicy.nonDivineRelays:
      return context.l10n.nostrSettingsSignatureVerificationNonDivineSubtitle;
  }
}
