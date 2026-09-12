// ABOUTME: Developer-options section for validating a staged Shorebird patch
// ABOUTME: Keeps a test device on staging across the validation relaunch

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/shorebird_patch/shorebird_patch_cubit.dart';
import 'package:openvine/blocs/shorebird_patch/shorebird_patch_state.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/repositories/shorebird_patch_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Lets a tester pull the `staging` track on the store binary they are running.
class ShorebirdPatchSection extends StatefulWidget {
  const ShorebirdPatchSection({
    required this.preferences,
    this.updaterFactory,
    super.key,
  });

  final SharedPreferences preferences;

  /// Injection seam that also keeps the updater's synchronous FFI probe out of
  /// the build pass.
  @visibleForTesting
  final ShorebirdUpdater Function()? updaterFactory;

  @override
  State<ShorebirdPatchSection> createState() => _ShorebirdPatchSectionState();
}

class _ShorebirdPatchSectionState extends State<ShorebirdPatchSection> {
  ShorebirdPatchCubit? _cubit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final updater = widget.updaterFactory?.call() ?? ShorebirdUpdater();
      final cubit = ShorebirdPatchCubit(
        repository: ShorebirdPatchRepository(
          updater: updater,
          preferences: widget.preferences,
        ),
      )..load();
      setState(() => _cubit = cubit);
    });
  }

  @override
  void dispose() {
    _cubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = _cubit;
    if (cubit == null) return const SizedBox.shrink();
    return BlocProvider<ShorebirdPatchCubit>.value(
      value: cubit,
      child: const ShorebirdPatchView(),
    );
  }
}

@visibleForTesting
class ShorebirdPatchView extends StatelessWidget {
  @visibleForTesting
  const ShorebirdPatchView({super.key});

  @override
  Widget build(BuildContext context) {
    final usesStagingTrack = context.select(
      (ShorebirdPatchCubit cubit) => cubit.state.usesStagingTrack,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(),
        const _CurrentPatchTile(),
        const _CheckTile(),
        const _ApplyTile(),
        if (usesStagingTrack) const _UseStableTrackTile(),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        context.l10n.devOptionsShorebirdTitle,
        style: VineTheme.titleMediumFont(
          color: context.vineColors.accentPositive,
        ),
      ),
    );
  }
}

class _CurrentPatchTile extends StatelessWidget {
  const _CurrentPatchTile();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ShorebirdPatchCubit>().state;
    final l10n = context.l10n;
    final unavailable =
        state.status == ShorebirdPatchValidationStatus.unavailable;

    return ListTile(
      title: Text(
        unavailable
            ? l10n.devOptionsShorebirdUnavailable
            : l10n.devOptionsShorebirdPatchLabel,
        style: VineTheme.titleMediumFont(
          color: context.vineColors.primaryText,
        ),
      ),
      subtitle: Text(
        _subtitleFor(state, l10n),
        style: VineTheme.bodyMediumFont(
          color: context.vineColors.secondaryText,
        ),
      ),
      trailing: unavailable
          ? null
          : Text(
              state.currentPatchNumber?.toString() ??
                  l10n.devOptionsShorebirdNoPatch,
              style: VineTheme.titleMediumFont(
                color: context.vineColors.secondaryText,
              ),
            ),
    );
  }

  String _subtitleFor(ShorebirdPatchState state, AppLocalizations l10n) {
    return switch (state.status) {
      ShorebirdPatchValidationStatus.loading => l10n.devOptionsShorebirdLoading,
      ShorebirdPatchValidationStatus.notChecked =>
        l10n.devOptionsShorebirdNotChecked,
      ShorebirdPatchValidationStatus.unavailable =>
        l10n.devOptionsShorebirdUnavailableSubtitle,
      ShorebirdPatchValidationStatus.checking =>
        l10n.devOptionsShorebirdChecking,
      ShorebirdPatchValidationStatus.updateAvailable =>
        l10n.devOptionsShorebirdUpdateAvailable,
      ShorebirdPatchValidationStatus.upToDate =>
        l10n.devOptionsShorebirdUpToDate,
      ShorebirdPatchValidationStatus.restartRequired =>
        l10n.devOptionsShorebirdRestartRequired,
      ShorebirdPatchValidationStatus.rollbackRequired =>
        l10n.devOptionsShorebirdRollbackRequired,
      ShorebirdPatchValidationStatus.applying =>
        l10n.devOptionsShorebirdApplying,
      ShorebirdPatchValidationStatus.applied => l10n.devOptionsShorebirdApplied,
      ShorebirdPatchValidationStatus.unchanged =>
        l10n.devOptionsShorebirdUnchanged,
      ShorebirdPatchValidationStatus.selectingStableTrack =>
        l10n.devOptionsShorebirdSelectingStableTrack,
      ShorebirdPatchValidationStatus.stableRestored =>
        l10n.devOptionsShorebirdStableRestored,
      ShorebirdPatchValidationStatus.failure => l10n.devOptionsShorebirdFailure,
    };
  }
}

class _CheckTile extends StatelessWidget {
  const _CheckTile();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ShorebirdPatchCubit>().state;
    final enabled = state.isAvailable && !state.isBusy;
    return _ActionTile(
      enabled: enabled,
      icon: DivineIconName.arrowClockwise,
      title: context.l10n.devOptionsShorebirdCheck,
      onTap: () => context.read<ShorebirdPatchCubit>().checkStagingTrack(),
    );
  }
}

class _ApplyTile extends StatelessWidget {
  const _ApplyTile();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ShorebirdPatchCubit>().state;
    return _ActionTile(
      enabled: state.isAvailable && state.canApply && !state.isBusy,
      icon: DivineIconName.arrowDown,
      title: context.l10n.devOptionsShorebirdApply,
      onTap: () => context.read<ShorebirdPatchCubit>().applyStagedPatch(),
    );
  }
}

class _UseStableTrackTile extends StatelessWidget {
  const _UseStableTrackTile();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ShorebirdPatchCubit>().state;
    return _ActionTile(
      enabled: !state.isBusy,
      icon: DivineIconName.arrowCounterClockwise,
      title: context.l10n.devOptionsShorebirdUseStable,
      onTap: () => context.read<ShorebirdPatchCubit>().useStableTrack(),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.enabled,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final bool enabled;
  final DivineIconName icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? context.vineColors.primaryText
        : context.vineColors.secondaryText;
    return ListTile(
      enabled: enabled,
      leading: DivineIcon(icon: icon, color: color),
      title: Text(title, style: VineTheme.titleMediumFont(color: color)),
      onTap: enabled ? onTap : null,
    );
  }
}
