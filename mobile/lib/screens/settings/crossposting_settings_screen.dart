// ABOUTME: Repository-backed crossposting connection and mode settings.
// ABOUTME: Presents compact platform controls through a BLoC Page/View split.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/crossposting_settings/crossposting_settings_cubit.dart';
import 'package:openvine/features/oauth/app_oauth_callback.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/crossposting_providers.dart';
import 'package:openvine/repositories/crossposting_repository.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';

/// Wires authenticated dependencies for the crossposting settings view.
class CrosspostingSettingsScreen extends ConsumerWidget {
  const CrosspostingSettingsScreen({
    super.key,
    this.launchOAuth = launchAppOAuth,
    this.nonceGenerator = generateCrosspostingOAuthNonce,
  });

  static const routeName = 'crossposting-settings';
  static const String path = RoutePaths.crosspostingSettings;

  final CrosspostingOAuthLauncher launchOAuth;
  final CrosspostingNonceGenerator nonceGenerator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(crosspostingEligibleProvider)) {
      return _CrosspostingScaffold(
        child: Center(
          child: Text(
            context.l10n.crosspostingSignInRequired,
            style: VineTheme.bodyLargeFont(color: context.vineColors.mutedText),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final repository = ref.watch(crosspostingRepositoryProvider);
    return BlocProvider(
      key: ValueKey(repository),
      create: (_) => CrosspostingSettingsCubit(
        repository: repository,
        launchOAuth: launchOAuth,
        nonceGenerator: nonceGenerator,
      )..load(),
      child: const CrosspostingSettingsView(),
    );
  }
}

/// Renders repository state and sends user intent to the owning Cubit.
class CrosspostingSettingsView extends StatefulWidget {
  const CrosspostingSettingsView({super.key});

  @override
  State<CrosspostingSettingsView> createState() =>
      _CrosspostingSettingsViewState();
}

class _CrosspostingSettingsViewState extends State<CrosspostingSettingsView> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () => context.read<CrosspostingSettingsCubit>().refresh(),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CrosspostingScaffold(
      child: BlocConsumer<CrosspostingSettingsCubit, CrosspostingSettingsState>(
        listenWhen: (previous, current) =>
            (current.error != null &&
                (previous.error != current.error ||
                    previous.errorAttempt != current.errorAttempt)) ||
            (current.outcome != null &&
                (previous.outcome != current.outcome ||
                    previous.outcomeAttempt != current.outcomeAttempt)),
        listener: _onTransientEvent,
        builder: (context, state) => switch (state.status) {
          CrosspostingSettingsStatus.initial ||
          CrosspostingSettingsStatus.loading => const Center(
            child: BrandedLoadingIndicator(),
          ),
          CrosspostingSettingsStatus.failure => const _LoadFailed(),
          CrosspostingSettingsStatus.loaded when state.entries.isEmpty =>
            const _NoPlatforms(),
          CrosspostingSettingsStatus.loaded => _LoadedSettingsList(
            state: state,
          ),
        },
      ),
    );
  }

  void _onTransientEvent(
    BuildContext context,
    CrosspostingSettingsState state,
  ) {
    final cubit = context.read<CrosspostingSettingsCubit>();
    final messenger = ScaffoldMessenger.of(context);

    if (state.error != null) {
      if (state.status == CrosspostingSettingsStatus.failure) {
        cubit.acknowledgeError();
        return;
      }
      final message = switch (state.error!) {
        CrosspostingSettingsError.notConnected =>
          context.l10n.crosspostingNotConnectedError,
        CrosspostingSettingsError.callbackTimeout =>
          context.l10n.crosspostingCallbackTimeoutError,
        CrosspostingSettingsError.generic =>
          context.l10n.crosspostingGenericError,
      };
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        DivineSnackbarContainer.snackBar(message, error: true),
      );
      cubit.acknowledgeError();
      return;
    }

    final outcome = state.outcome;
    final platform = state.outcomePlatform;
    if (outcome == null || platform == null) return;
    final message = switch (outcome) {
      CrosspostingOAuthOutcome.connected =>
        context.l10n.crosspostingConnectionSuccess(platform.displayName),
      CrosspostingOAuthOutcome.denied =>
        context.l10n.crosspostingConnectionDenied(platform.displayName),
      CrosspostingOAuthOutcome.failed =>
        context.l10n.crosspostingConnectionFailed(platform.displayName),
    };
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      DivineSnackbarContainer.snackBar(
        message,
        error: outcome != CrosspostingOAuthOutcome.connected,
      ),
    );
    cubit.acknowledgeOutcome();
  }
}

class _LoadedSettingsList extends StatelessWidget {
  const _LoadedSettingsList({required this.state});

  final CrosspostingSettingsState state;

  @override
  Widget build(BuildContext context) {
    final refreshLabel = MaterialLocalizations.of(
      context,
    ).refreshIndicatorSemanticLabel;
    return RefreshIndicator(
      color: context.vineColors.accentPositive,
      backgroundColor: context.vineColors.surfaceContainer,
      onRefresh: context.read<CrosspostingSettingsCubit>().refresh,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.entries.length + 1,
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: context.vineColors.outlineMuted),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: DivineButton(
                  label: refreshLabel,
                  size: DivineButtonSize.small,
                  type: DivineButtonType.secondary,
                  leadingIcon: DivineIconName.arrowClockwise,
                  onPressed: state.hasPendingAction
                      ? null
                      : context.read<CrosspostingSettingsCubit>().refresh,
                ),
              ),
            );
          }
          return _PlatformSection(
            entry: state.entries[index - 1],
            state: state,
          );
        },
      ),
    );
  }
}

class _CrosspostingScaffold extends StatelessWidget {
  const _CrosspostingScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.settingsCrosspostingTitle,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: context.vineColors.background,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: child,
        ),
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Text(
              context.l10n.crosspostingLoadFailed,
              style: VineTheme.bodyLargeFont(
                color: context.vineColors.mutedText,
              ),
              textAlign: TextAlign.center,
            ),
            DivineButton(
              label: context.l10n.crosspostingRetry,
              size: DivineButtonSize.small,
              onPressed: () =>
                  unawaited(context.read<CrosspostingSettingsCubit>().load()),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoPlatforms extends StatelessWidget {
  const _NoPlatforms();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          context.l10n.crosspostingNoPlatforms,
          style: VineTheme.bodyLargeFont(color: context.vineColors.mutedText),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _PlatformSection extends StatelessWidget {
  const _PlatformSection({required this.entry, required this.state});

  final CrosspostingPlatformSettings entry;
  final CrosspostingSettingsState state;

  @override
  Widget build(BuildContext context) {
    final busy = state.hasPendingAction;
    final pending = state.pendingPlatform == entry.platform;
    final identity = _accountIdentity(entry);
    final status = _statusText(context, entry);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Row(
            spacing: 12,
            children: [
              DivineIcon(
                icon: DivineIconName.shareNetwork,
                color: entry.isConnected
                    ? context.vineColors.accentPositive
                    : entry.needsReauth
                    ? context.vineColors.accentWarning
                    : context.vineColors.mutedText,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.platform.displayName,
                      style: VineTheme.titleMediumFont(
                        color: context.vineColors.primaryText,
                      ),
                    ),
                    if (identity != null)
                      Text(
                        identity,
                        style: VineTheme.bodyMediumFont(
                          color: context.vineColors.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (identity == null || entry.needsReauth)
                      Text(
                        status,
                        style: VineTheme.bodyMediumFont(
                          color: entry.needsReauth
                              ? context.vineColors.accentWarning
                              : context.vineColors.mutedText,
                        ),
                      ),
                  ],
                ),
              ),
              _ConnectionAction(
                entry: entry,
                busy: busy,
                pending:
                    pending &&
                    state.pendingAction !=
                        CrosspostingPlatformAction.savingMode,
              ),
            ],
          ),
          if (entry.isConnected) ...[
            _ModeSelector(
              entry: entry,
              selectedMode: entry.mode,
              busy: busy,
              savingMode:
                  pending &&
                  state.pendingAction == CrosspostingPlatformAction.savingMode,
            ),
            if (entry.mode == CrosspostingMode.manual)
              Text(
                context.l10n.crosspostingModeManualSubtitle,
                style: VineTheme.bodySmallFont(
                  color: context.vineColors.mutedText,
                ),
              ),
            if (entry.mode == CrosspostingMode.automatic)
              Text(
                context.l10n.crosspostingModeAutomaticSubtitle,
                style: VineTheme.bodySmallFont(
                  color: context.vineColors.mutedText,
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _statusText(
    BuildContext context,
    CrosspostingPlatformSettings settings,
  ) {
    if (settings.needsReauth) {
      return context.l10n.crosspostingNeedsReconnect;
    }
    if (!settings.isConnected) {
      return context.l10n.crosspostingNotConnected;
    }
    return context.l10n.crosspostingConnected;
  }

  String? _accountIdentity(CrosspostingPlatformSettings settings) {
    final accountName = settings.connection?.externalAccountName?.trim();
    if (accountName != null && accountName.isNotEmpty) return accountName;
    final accountId = settings.connection?.externalAccountId?.trim();
    if (accountId != null && accountId.isNotEmpty) return accountId;
    return null;
  }
}

class _ConnectionAction extends StatelessWidget {
  const _ConnectionAction({
    required this.entry,
    required this.busy,
    required this.pending,
  });

  final CrosspostingPlatformSettings entry;
  final bool busy;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CrosspostingSettingsCubit>();
    final label = entry.isConnected
        ? context.l10n.crosspostingDisconnect
        : entry.needsReauth
        ? context.l10n.crosspostingReconnect
        : context.l10n.crosspostingConnect;

    return DivineButton(
      key: ValueKey('crossposting-action-${entry.platform.wireName}'),
      label: label,
      type: entry.isConnected
          ? DivineButtonType.ghostSecondary
          : entry.needsReauth
          ? DivineButtonType.secondary
          : DivineButtonType.primary,
      size: DivineButtonSize.small,
      isLoading: pending && busy,
      onPressed: busy
          ? null
          : () {
              if (entry.isConnected) {
                unawaited(cubit.disconnect(entry.platform));
              } else {
                unawaited(cubit.connect(entry.platform));
              }
            },
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.entry,
    required this.selectedMode,
    required this.busy,
    required this.savingMode,
  });

  final CrosspostingPlatformSettings entry;
  final CrosspostingMode selectedMode;
  final bool busy;
  final bool savingMode;

  @override
  Widget build(BuildContext context) {
    final options = <(CrosspostingMode, String)>[
      (CrosspostingMode.disabled, context.l10n.crosspostingModeOff),
      (CrosspostingMode.manual, context.l10n.crosspostingModeManual),
      if (entry.supportsAutomatic)
        (CrosspostingMode.automatic, context.l10n.crosspostingModeAutomatic),
    ];

    return Row(
      spacing: 4,
      children: [
        for (final (mode, label) in options)
          Expanded(
            child: _ModeOption(
              entry: entry,
              mode: mode,
              label: label,
              selected: mode == selectedMode,
              busy: busy,
              saving: savingMode && mode == selectedMode,
            ),
          ),
      ],
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.entry,
    required this.mode,
    required this.label,
    required this.selected,
    required this.busy,
    required this.saving,
  });

  final CrosspostingPlatformSettings entry;
  final CrosspostingMode mode;
  final String label;
  final bool selected;
  final bool busy;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onPressed = busy
        ? null
        : () => unawaited(
            context.read<CrosspostingSettingsCubit>().setMode(
              entry.platform,
              mode,
            ),
          );
    return Semantics(
      key: ValueKey(
        'crossposting-mode-semantics-'
        '${entry.platform.wireName}-${mode.wireName}',
      ),
      button: true,
      selected: selected,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: DivineButton(
        key: ValueKey(
          'crossposting-mode-'
          '${entry.platform.wireName}-${mode.wireName}',
        ),
        label: label,
        type: selected ? DivineButtonType.primary : DivineButtonType.secondary,
        size: DivineButtonSize.small,
        expanded: true,
        isLoading: saving,
        onPressed: onPressed,
      ),
    );
  }
}
