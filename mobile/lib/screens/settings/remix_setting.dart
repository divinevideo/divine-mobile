// ABOUTME: Settings switch letting a creator block remixing of all their videos.
// ABOUTME: Persists divine_allow_video_reuse in the account's kind 0 profile.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/remix_settings/remix_settings_cubit.dart';
import 'package:openvine/blocs/remix_settings/remix_settings_state.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Page: provides a [RemixSettingsCubit] scoped to this switch.
///
/// The cubit is re-keyed on the signing repository and the account, so an
/// account switch never publishes through a repository bound to the previous
/// signer.
class RemixSetting extends ConsumerWidget {
  const RemixSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(currentAuthStateProvider);
    final pubkey = ref.watch(authServiceProvider).currentPublicKeyHex;
    final repository = ref.watch(profileRepositoryProvider);
    return BlocProvider(
      key: ValueKey((pubkey, repository)),
      create: (_) {
        final cubit = RemixSettingsCubit(
          repository: repository,
          pubkey: pubkey,
          onProfileSaved: (saved) {
            ref
              ..invalidate(userProfileReactiveProvider(saved.pubkey))
              ..invalidate(fetchUserProfileProvider(saved.pubkey));
          },
        );
        runDetached(
          cubit.load(),
          'load remix setting',
          logName: 'RemixSetting',
          category: LogCategory.ui,
        );
        return cubit;
      },
      child: const RemixSettingView(),
    );
  }
}

/// View: the switch once the stored answer is read, a retry when the read
/// fails, plus the snackbar when a save fails.
class RemixSettingView extends StatelessWidget {
  @visibleForTesting
  const RemixSettingView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RemixSettingsCubit>().state;
    return BlocListener<RemixSettingsCubit, RemixSettingsState>(
      listenWhen: (previous, current) =>
          previous.saveStatus != current.saveStatus &&
          current.saveStatus == RemixSettingsSaveStatus.failure,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            DivineSnackbarContainer.snackBar(
              switch (state.failure) {
                RemixSettingsSaveFailure.noRelays =>
                  context.l10n.profileSetupNoRelaysConnected,
                RemixSettingsSaveFailure.publishFailed ||
                null => context.l10n.profileSetupPublishFailed,
              },
              error: true,
            ),
          );
      },
      // The switch defaults to on, so showing it before the stored answer is
      // read would tell a creator who blocked remixing that it is allowed.
      child: switch (state.loadStatus) {
        RemixSettingsLoadStatus.ready => DivineSwitchTile(
          leadingIcon: DivineIconName.filmSlate,
          title: context.l10n.remixSettingAllowTitle,
          subtitle: context.l10n.remixSettingAllowSubtitle,
          value: state.allowVideoReuse,
          // Disabled while a publish is in flight, so a second flip cannot
          // land on an unconfirmed one.
          onChanged: state.canEdit
              ? (value) =>
                    context.read<RemixSettingsCubit>().setAllowVideoReuse(value)
              : null,
        ),
        RemixSettingsLoadStatus.failure => const _RemixSettingLoadFailure(),
        RemixSettingsLoadStatus.initial ||
        RemixSettingsLoadStatus.loading => const _RemixSettingLoading(),
      },
    );
  }
}

class _RemixSettingLoading extends StatelessWidget {
  const _RemixSettingLoading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: DivineCircularProgressIndicator(
          semanticsLabel: context.l10n.commonLoading,
        ),
      ),
    );
  }
}

class _RemixSettingLoadFailure extends StatelessWidget {
  const _RemixSettingLoadFailure();

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        spacing: 8,
        children: [
          Text(
            context.l10n.remixSettingAllowTitle,
            style: VineTheme.titleMediumFont(color: colors.primaryText),
          ),
          Text(
            context.l10n.commonSomethingWentWrong,
            style: VineTheme.bodyMediumFont(color: colors.mutedText),
          ),
          DivineButton(
            label: context.l10n.commonRetry,
            type: DivineButtonType.secondary,
            onPressed: () => context.read<RemixSettingsCubit>().load(),
          ),
        ],
      ),
    );
  }
}
