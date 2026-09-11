// ABOUTME: Screen for managing Nostr relay connections and settings
// ABOUTME: Allows users to add, remove, and configure external relay preferences

import 'package:count_formatter/count_formatter.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/relay_settings/relay_settings_cubit.dart';
import 'package:openvine/blocs/relay_settings/relay_settings_state.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/relay_list_repository_provider.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/services/relay_statistics_service.dart';
import 'package:openvine/utils/relay_url_utils.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:url_launcher/url_launcher.dart';

/// Page: bridges the NostrClient + RelayCapabilityService + VideoEventService
/// into [RelaySettingsCubit].
class RelaySettingsScreen extends ConsumerWidget {
  /// Route name for this screen.
  static const routeName = 'relay-settings';

  /// Path for this route.
  static const String path = RoutePaths.relaySettings;

  const RelaySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nostrService = ref.watch(nostrServiceProvider);
    final relayListRepository = ref.watch(relayListRepositoryProvider);
    final capabilityService = ref.watch(relayCapabilityServiceProvider);
    final videoService = ref.watch(videoEventServiceProvider);
    return BlocProvider(
      key: ValueKey((
        nostrService,
        relayListRepository,
        capabilityService,
        videoService,
      )),
      create: (_) => RelaySettingsCubit(
        nostrClient: nostrService,
        relayListRepository: relayListRepository,
        relayCapabilityService: capabilityService,
        videoEventService: videoService,
      )..load(),
      child: const RelaySettingsView(),
    );
  }
}

/// View: renders the relay list + per-relay stats + capability info from
/// Cubit state. Stats come from the existing reactive Riverpod stream
/// provider — the Cubit only owns the configured-relay snapshot and the
/// capability cache.
class RelaySettingsView extends StatelessWidget {
  @visibleForTesting
  const RelaySettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.relaySettingsTitle,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: context.vineColors.background,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                const _InfoBanner(),
                Expanded(
                  child:
                      BlocSelector<
                        RelaySettingsCubit,
                        RelaySettingsState,
                        List<String>
                      >(
                        selector: (state) => state.relays,
                        builder: (context, relays) {
                          Log.info(
                            'Displaying ${relays.length} external relays',
                            name: 'RelaySettingsScreen',
                          );
                          return relays.isEmpty
                              ? const _EmptyRelayList()
                              : _RelayList(relays: relays);
                        },
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: DivineInfoCard(
        tone: DivineInfoCardTone.neutral,
        compact: true,
        title: context.l10n.relaySettingsInfoTitle,
        message: context.l10n.relaySettingsInfoDescription,
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            _ExternalLink(
              label: context.l10n.relaySettingsLearnMoreNostr,
              url: 'https://nostr.com',
            ),
            _ExternalLink(
              label: context.l10n.relaySettingsFindPublicRelays,
              url: 'https://nostr.co.uk/relays/',
            ),
          ],
        ),
      ),
    );
  }
}

class _ExternalLink extends StatelessWidget {
  const _ExternalLink({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () => _launchExternalUrl(context, Uri.parse(url)),
        child: Text(
          label,
          style: VineTheme.bodySmallFont(
            color: VineTheme.vineGreen,
          ).copyWith(decoration: TextDecoration.underline),
        ),
      ),
    );
  }
}

class _EmptyRelayList extends StatelessWidget {
  const _EmptyRelayList();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const DivineIcon(
            icon: DivineIconName.warningCircle,
            color: VineTheme.warning,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.relaySettingsAppNotFunctional,
            style: VineTheme.titleLargeFont(
              color: context.vineColors.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              context.l10n.relaySettingsRequiresRelay,
              textAlign: TextAlign.center,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.secondaryText,
              ),
            ),
          ),
          const SizedBox(height: 32),
          DivineButton(
            label: context.l10n.relaySettingsRestoreDefaultRelay,
            leadingIcon: DivineIconName.arrowCounterClockwise,
            onPressed: () => _restoreDefaultRelay(context),
          ),
          const SizedBox(height: 12),
          DivineButton(
            label: context.l10n.relaySettingsAddCustomRelay,
            leadingIcon: DivineIconName.plus,
            type: DivineButtonType.secondary,
            onPressed: () => _showAddRelayDialog(context),
          ),
        ],
      ),
    );
  }
}

class _RelayList extends StatelessWidget {
  const _RelayList({required this.relays});

  final List<String> relays;

  @override
  Widget build(BuildContext context) {
    final defaultRelayUrl = context.read<RelaySettingsCubit>().defaultRelayUrl;
    final hasDefaultRelay = relays.any(
      (relay) => relayUrlsEquivalent(relay, defaultRelayUrl),
    );

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            spacing: 12,
            children: [
              Expanded(
                child: DivineButton(
                  label: context.l10n.relaySettingsAddRelay,
                  leadingIcon: DivineIconName.plus,
                  expanded: true,
                  onPressed: () => _showAddRelayDialog(context),
                ),
              ),
              Expanded(
                child: DivineButton(
                  label: context.l10n.relaySettingsRetry,
                  leadingIcon: DivineIconName.arrowClockwise,
                  type: DivineButtonType.secondary,
                  expanded: true,
                  onPressed: () => _retryConnection(context),
                ),
              ),
            ],
          ),
        ),
        if (!hasDefaultRelay)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: DivineButton(
              label: context.l10n.relaySettingsRestoreDefaultRelay,
              leadingIcon: DivineIconName.arrowCounterClockwise,
              expanded: true,
              onPressed: () => _restoreDefaultRelay(context),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: relays.length,
            itemBuilder: (context, index) =>
                _RelayTile(relayUrl: relays[index]),
          ),
        ),
      ],
    );
  }
}

class _RelayTile extends ConsumerWidget {
  const _RelayTile({required this.relayUrl});

  final String relayUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(relayStatisticsStreamProvider);
    final stats = statsAsync.whenData((allStats) => allStats[relayUrl]).value;
    final isConnected = stats?.isConnected ?? false;
    final statusSummary = _relayStatusSummary(context, stats);
    final isDefaultRelay = relayUrlsEquivalent(
      relayUrl,
      context.read<RelaySettingsCubit>().defaultRelayUrl,
    );

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: VineTheme.transparent),
      child: ExpansionTile(
        leading: DivineIcon(
          // The icon set has no cloud pair; connected / not-connected reads
          // just as clearly on the check-vs-warning pair the rest of this
          // screen already uses.
          icon: isConnected
              ? DivineIconName.checkCircle
              : DivineIconName.warningCircle,
          color: isConnected ? VineTheme.success : VineTheme.warning,
          size: 20,
        ),
        title: Text(
          relayUrl,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.primaryText,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          statusSummary,
          style: VineTheme.bodySmallFont(
            color: isConnected
                ? context.vineColors.mutedText
                : VineTheme.warning,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DivineIconButton(
              icon: DivineIconName.trash,
              size: DivineIconButtonSize.small,
              backgroundColor: VineTheme.transparent,
              foregroundColor: VineTheme.error,
              showShadow: false,
              tooltip: context.l10n.relaySettingsRemoveRelayTooltip,
              onPressed: () => _confirmRemoveRelay(
                context,
                relayUrl,
                isDefaultRelay: isDefaultRelay,
              ),
            ),
            const SizedBox(width: 8),
            DivineIcon(
              icon: DivineIconName.caretDown,
              color: context.vineColors.mutedText,
              size: 20,
            ),
          ],
        ),
        iconColor: context.vineColors.mutedText,
        collapsedIconColor: context.vineColors.mutedText,
        onExpansionChanged: (expanded) {
          if (expanded) {
            context.read<RelaySettingsCubit>().fetchCapabilities(relayUrl);
          }
        },
        children: [_RelayDetails(stats: stats, relayUrl: relayUrl)],
      ),
    );
  }
}

class _RelayDetails extends StatelessWidget {
  const _RelayDetails({required this.stats, required this.relayUrl});

  final RelayStatistics? stats;
  final String relayUrl;

  @override
  Widget build(BuildContext context) {
    if (stats == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          context.l10n.relaySettingsNoStats,
          style: VineTheme.bodySmallFont(color: context.vineColors.mutedText),
        ),
      );
    }
    final entry = context.select(
      (RelaySettingsCubit cubit) => cubit.state.capabilities[relayUrl],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatRow(
            label: context.l10n.relaySettingsConnection,
            value: stats!.isConnected
                ? context.l10n.relaySettingsConnected
                : context.l10n.relaySettingsDisconnected,
            valueColor: stats!.isConnected
                ? VineTheme.success
                : VineTheme.warning,
          ),
          if (stats!.sessionDuration != null)
            _StatRow(
              label: context.l10n.relaySettingsSessionDuration,
              value: _formatDuration(stats!.sessionDuration!),
              valueColor: context.vineColors.secondaryText,
            ),
          if (stats!.lastConnected != null)
            _StatRow(
              label: context.l10n.relaySettingsLastConnected,
              value: _formatTime(context, stats!.lastConnected!),
              valueColor: context.vineColors.secondaryText,
            ),
          if (!stats!.isConnected && stats!.lastDisconnected != null)
            _StatRow(
              label: context.l10n.relaySettingsDisconnectedLabel,
              value: _formatTime(context, stats!.lastDisconnected!),
              valueColor: VineTheme.warning,
            ),
          if (stats!.lastDisconnectReason != null && !stats!.isConnected)
            _StatRow(
              label: context.l10n.relaySettingsReason,
              value: stats!.lastDisconnectReason!,
              valueColor: VineTheme.warning,
            ),
          Divider(color: context.vineColors.mutedText, height: 16),
          _StatRow(
            label: context.l10n.relaySettingsActiveSubscriptions,
            value: '${stats!.activeSubscriptions}',
            valueColor: VineTheme.info,
          ),
          _StatRow(
            label: context.l10n.relaySettingsTotalSubscriptions,
            value: '${stats!.totalSubscriptions}',
            valueColor: context.vineColors.secondaryText,
          ),
          _StatRow(
            label: context.l10n.relaySettingsEventsReceived,
            value: CountFormatter.formatCompact(stats!.eventsReceived),
            valueColor: VineTheme.success,
          ),
          _StatRow(
            label: context.l10n.relaySettingsEventsSent,
            value: CountFormatter.formatCompact(stats!.eventsSent),
            valueColor: VineTheme.info,
          ),
          Divider(color: context.vineColors.mutedText, height: 16),
          _StatRow(
            label: context.l10n.relaySettingsRequestsThisSession,
            value: '${stats!.requestsThisSession}',
            valueColor: context.vineColors.secondaryText,
          ),
          _StatRow(
            label: context.l10n.relaySettingsFailedRequests,
            value: '${stats!.failedRequests}',
            valueColor: stats!.failedRequests > 0
                ? VineTheme.error
                : context.vineColors.secondaryText,
          ),
          _RelayInfoSection(relayUrl: relayUrl, entry: entry),
        ],
      ),
    );
  }
}

class _RelayInfoSection extends StatelessWidget {
  const _RelayInfoSection({required this.relayUrl, required this.entry});

  final String relayUrl;
  final RelayCapabilityEntry? entry;

  @override
  Widget build(BuildContext context) {
    final isLoading = entry?.loading ?? false;
    final capabilities = entry?.capabilities;

    if (isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: context.vineColors.mutedText, height: 24),
          Row(
            children: [
              // The label beside it already announces the wait.
              const SizedBox(
                width: 16,
                height: 16,
                child: ExcludeSemantics(
                  child: BrandedLoadingIndicator(size: 16),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.relaySettingsLoadingRelayInfo,
                style: VineTheme.bodySmallFont(
                  color: context.vineColors.mutedText,
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (capabilities == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: context.vineColors.mutedText, height: 24),
        Text(
          context.l10n.relaySettingsAboutRelay,
          style: VineTheme.labelLargeFont(
            color: context.vineColors.secondaryText,
          ),
        ),
        const SizedBox(height: 8),
        if (capabilities.name != null && capabilities.name!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              capabilities.name!,
              style: VineTheme.titleMediumFont(
                color: context.vineColors.primaryText,
              ),
            ),
          ),
        if (capabilities.description != null &&
            capabilities.description!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              capabilities.description!,
              style: VineTheme.bodySmallFont(
                color: context.vineColors.secondaryText,
              ),
            ),
          ),
        if (capabilities.supportedNips.isNotEmpty)
          _StatRow(
            label: context.l10n.relaySettingsSupportedNips,
            value: capabilities.supportedNips.join(', '),
            valueColor: context.vineColors.secondaryText,
          ),
        if (capabilities.rawData['software'] != null)
          _StatRow(
            label: context.l10n.relaySettingsSoftware,
            value: _formatSoftwareVersion(capabilities.rawData),
            valueColor: context.vineColors.secondaryText,
          ),
        const SizedBox(height: 12),
        DivineButton(
          label: context.l10n.relaySettingsViewWebsite,
          leadingIcon: DivineIconName.arrowUpRight,
          type: DivineButtonType.secondary,
          size: DivineButtonSize.small,
          onPressed: () => _openRelayWebsite(context, relayUrl),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: VineTheme.bodySmallFont(color: context.vineColors.mutedText),
          ),
          Text(value, style: VineTheme.bodySmallFont(color: valueColor)),
        ],
      ),
    );
  }
}

/// Add-relay sheet body. The `TextEditingController` lives in this widget per
/// the hybrid pattern (controllers are UI plumbing, not Cubit state).
class _AddRelaySheet extends StatefulWidget {
  const _AddRelaySheet();

  @override
  State<_AddRelaySheet> createState() => _AddRelaySheetState();
}

class _AddRelaySheetState extends State<_AddRelaySheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // The sheet is fixed-mode, so nothing else lifts it clear of the
      // keyboard — without the view inset the URL field and both buttons sit
      // underneath it the moment the field takes focus.
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        4 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            context.l10n.relaySettingsAddRelayPrompt,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.mutedText,
            ),
          ),
          Semantics(
            button: true,
            label: context.l10n.relaySettingsBrowsePublicRelays,
            child: GestureDetector(
              onTap: () => _launchExternalUrl(
                context,
                Uri.parse('https://nostr.co.uk/relays/'),
              ),
              child: Text(
                context.l10n.relaySettingsBrowsePublicRelays,
                style: VineTheme.bodySmallFont(
                  color: VineTheme.vineGreen,
                ).copyWith(decoration: TextDecoration.underline),
              ),
            ),
          ),
          const SizedBox(height: 8),
          DivineTextField(
            controller: _controller,
            labelText: 'wss://relay.example.com',
            keyboardType: TextInputType.url,
            textCapitalization: TextCapitalization.none,
            autocorrect: false,
            autofocus: true,
            filled: true,
            textInputAction: .done,
            onSubmitted: (_) {
              final url = _controller.text.trim();
              if (url.isNotEmpty) context.popModalIfMounted(url);
            },
            spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
          ),
          const SizedBox(height: 8),
          Row(
            spacing: 16,
            children: [
              Expanded(
                child: DivineButton(
                  label: context.l10n.relaySettingsCancel,
                  type: DivineButtonType.secondary,
                  expanded: true,
                  onPressed: () => context.popModalIfMounted(),
                ),
              ),
              Expanded(
                child: DivineButton(
                  label: context.l10n.relaySettingsAdd,
                  expanded: true,
                  onPressed: () {
                    final url = _controller.text.trim();
                    if (url.isNotEmpty) context.popModalIfMounted(url);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Action helpers — pulled to top-level functions so the private widget
// classes can share them without each having to be a ConsumerWidget /
// reach into a parent state.

Future<void> _showAddRelayDialog(BuildContext context) async {
  final cubit = context.read<RelaySettingsCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;

  final relayUrl = await VineBottomSheet.show<String>(
    context: context,
    scrollable: false,
    contentTitle: l10n.relaySettingsAddRelayTitle,
    children: const [_AddRelaySheet()],
  );
  if (relayUrl == null || relayUrl.isEmpty) return;

  final outcome = await cubit.addRelay(relayUrl);
  switch (outcome) {
    case AddRelayOutcome.added:
      messenger.showSnackBar(
        DivineSnackbarContainer.snackBar(
          l10n.relaySettingsAddedRelay(relayUrl),
        ),
      );
      Log.info(
        'Successfully added relay: $relayUrl',
        name: 'RelaySettingsScreen',
      );
    case AddRelayOutcome.addedLocalOnly:
      _showWarning(messenger, l10n.relaySettingsSavedLocallyPublishPending);
      Log.warning(
        'Added relay locally but kind:10002 publish is pending: $relayUrl',
        name: 'RelaySettingsScreen',
      );
    case AddRelayOutcome.addedConnectionPending:
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.relaySettingsFailedToConnectCheck),
          backgroundColor: VineTheme.warning,
        ),
      );
      Log.info(
        'Added relay without connection: $relayUrl',
        name: 'RelaySettingsScreen',
      );
    case AddRelayOutcome.addedConnectionPendingLocalOnly:
      _showWarning(
        messenger,
        '${l10n.relaySettingsFailedToConnectCheck} '
        '${l10n.relaySettingsSavedLocallyPublishPending}',
      );
      Log.warning(
        'Added relay locally without connection and kind:10002 publish is pending: $relayUrl',
        name: 'RelaySettingsScreen',
      );
    case AddRelayOutcome.invalidUrl:
      _showError(messenger, l10n.relaySettingsInvalidUrl);
    case AddRelayOutcome.insecureUrl:
      _showError(messenger, l10n.relaySettingsInsecureUrl);
    case AddRelayOutcome.failed:
      _showError(messenger, l10n.relaySettingsFailedToAddRelay);
  }
}

Future<void> _confirmRemoveRelay(
  BuildContext context,
  String relayUrl, {
  required bool isDefaultRelay,
}) async {
  final cubit = context.read<RelaySettingsCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;

  final confirm = await VineBottomSheet.show<bool>(
    context: context,
    scrollable: false,
    contentTitle: isDefaultRelay
        ? l10n.relaySettingsRemoveDefaultRelayTitle
        : l10n.relaySettingsRemoveRelayTitle,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(
          isDefaultRelay
              ? l10n.relaySettingsRemoveDefaultRelayMessage(relayUrl)
              : l10n.relaySettingsRemoveRelayMessage(relayUrl),
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.secondaryText,
          ),
        ),
      ),
      // The buttons resolve the Navigator from the sheet's own subtree rather
      // than from the relay screen's context: the list rebuilds on every relay
      // status change, and a caller context that has gone defunct leaves both
      // buttons inert.
      Builder(
        builder: (sheetContext) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            spacing: 16,
            children: [
              Expanded(
                child: DivineButton(
                  label: l10n.relaySettingsCancel,
                  type: DivineButtonType.secondary,
                  expanded: true,
                  onPressed: () => sheetContext.popModalIfMounted(false),
                ),
              ),
              Expanded(
                child: DivineButton(
                  label: l10n.relaySettingsRemove,
                  type: DivineButtonType.error,
                  expanded: true,
                  onPressed: () => sheetContext.popModalIfMounted(true),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
  if (confirm != true) return;

  final outcome = await cubit.removeRelay(relayUrl);
  switch (outcome) {
    case RemoveRelayOutcome.removed:
      messenger.showSnackBar(
        DivineSnackbarContainer.snackBar(
          l10n.relaySettingsRemovedRelay(relayUrl),
        ),
      );
      Log.info(
        'Successfully removed relay: $relayUrl',
        name: 'RelaySettingsScreen',
      );
    case RemoveRelayOutcome.removedLocalOnly:
      _showWarning(messenger, l10n.relaySettingsSavedLocallyPublishPending);
      Log.warning(
        'Removed relay locally but kind:10002 publish is pending: $relayUrl',
        name: 'RelaySettingsScreen',
      );
    case RemoveRelayOutcome.failed:
      _showError(messenger, l10n.relaySettingsFailedToRemoveRelay);
  }
}

Future<void> _retryConnection(BuildContext context) async {
  final cubit = context.read<RelaySettingsCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;

  messenger.showSnackBar(
    DivineSnackbarContainer.snackBar(l10n.relaySettingsForcingReconnection),
  );

  final outcome = await cubit.retryConnection();
  switch (outcome.kind) {
    case RetryConnectionOutcomeKind.connected:
      messenger.showSnackBar(
        DivineSnackbarContainer.snackBar(
          l10n.relaySettingsConnectedToRelays(outcome.connectedCount),
        ),
      );
    case RetryConnectionOutcomeKind.stillConnecting:
      // Not an error: the reconnect is still running and its relays will
      // report as they land.
      messenger.showSnackBar(
        DivineSnackbarContainer.snackBar(l10n.relaySettingsStillConnecting),
      );
    case RetryConnectionOutcomeKind.notConnected:
    case RetryConnectionOutcomeKind.failed:
      _showError(messenger, l10n.relaySettingsFailedToConnectCheck);
  }
}

Future<void> _restoreDefaultRelay(BuildContext context) async {
  final cubit = context.read<RelaySettingsCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;

  final outcome = await cubit.restoreDefaultRelay();
  switch (outcome) {
    case RestoreDefaultRelayOutcome.restored:
      messenger.showSnackBar(
        DivineSnackbarContainer.snackBar(
          l10n.relaySettingsRestoredDefault(cubit.defaultRelayUrl),
        ),
      );
      Log.info('Restored default relay', name: 'RelaySettingsScreen');
    case RestoreDefaultRelayOutcome.restoredLocalOnly:
      _showWarning(messenger, l10n.relaySettingsSavedLocallyPublishPending);
      Log.warning(
        'Restored default relay locally but kind:10002 publish is pending',
        name: 'RelaySettingsScreen',
      );
    case RestoreDefaultRelayOutcome.restoredConnectionPending:
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.relaySettingsFailedToConnectCheck),
          backgroundColor: VineTheme.warning,
        ),
      );
      Log.info(
        'Restored default relay without connection',
        name: 'RelaySettingsScreen',
      );
    case RestoreDefaultRelayOutcome.restoredConnectionPendingLocalOnly:
      _showWarning(
        messenger,
        '${l10n.relaySettingsFailedToConnectCheck} '
        '${l10n.relaySettingsSavedLocallyPublishPending}',
      );
      Log.warning(
        'Restored default relay locally without connection and kind:10002 publish is pending',
        name: 'RelaySettingsScreen',
      );
    case RestoreDefaultRelayOutcome.failed:
      _showError(messenger, l10n.relaySettingsFailedToRestoreDefault);
  }
}

Future<void> _openRelayWebsite(BuildContext context, String relayUrl) async {
  final httpUrl = relayUrl
      .replaceFirst('wss://', 'https://')
      .replaceFirst('ws://', 'http://');
  await _launchExternalUrl(context, Uri.parse(httpUrl));
}

Future<void> _launchExternalUrl(BuildContext context, Uri url) async {
  final messenger = ScaffoldMessenger.of(context);
  final couldNotOpenBrowserMessage =
      context.l10n.relaySettingsCouldNotOpenBrowser;
  final failedToOpenLinkMessage = context.l10n.relaySettingsFailedToOpenLink;
  try {
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showError(messenger, couldNotOpenBrowserMessage);
    }
  } catch (e) {
    Log.error('Failed to launch URL: $e', name: 'RelaySettingsScreen');
    _showError(messenger, failedToOpenLinkMessage);
  }
}

void _showError(ScaffoldMessengerState messenger, String message) {
  messenger.showSnackBar(
    DivineSnackbarContainer.snackBar(message, error: true),
  );
}

void _showWarning(ScaffoldMessengerState messenger, String message) {
  messenger.showSnackBar(
    SnackBar(content: Text(message), backgroundColor: VineTheme.warning),
  );
}

String _formatSoftwareVersion(Map<String, dynamic> rawData) {
  final software = rawData['software'] as String?;
  final version = rawData['version'] as String?;
  if (software == null) return '';
  if (version != null) return '$software v$version';
  return software;
}

String _relayStatusSummary(BuildContext context, RelayStatistics? stats) {
  if (stats == null) return context.l10n.relaySettingsExternalRelay;
  if (!stats.isConnected) {
    if (stats.lastDisconnected != null) {
      final ago = DateTime.now().difference(stats.lastDisconnected!);
      return context.l10n.relaySettingsDisconnectedAgo(_formatDuration(ago));
    }
    return context.l10n.relaySettingsNotConnected;
  }

  final parts = <String>[];
  if (stats.activeSubscriptions > 0) {
    parts.add(
      context.l10n.relaySettingsSubscriptionsSummary(stats.activeSubscriptions),
    );
  }
  if (stats.eventsReceived > 0) {
    parts.add(
      StringUtils.compactPlural(
        stats.eventsReceived,
        context.l10n.relaySettingsEventsSummary,
      ),
    );
  }
  if (parts.isEmpty) return context.l10n.relaySettingsConnected;
  return parts.join(' | ');
}

String _formatDuration(Duration duration) {
  if (duration.inDays > 0) {
    return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
  } else if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  } else if (duration.inMinutes > 0) {
    return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
  } else {
    return '${duration.inSeconds}s';
  }
}

String _formatTime(BuildContext context, DateTime time) {
  final now = DateTime.now();
  final diff = now.difference(time);
  if (diff.inSeconds < 60) {
    return context.l10n.relaySettingsTimeAgo('${diff.inSeconds}s');
  } else if (diff.inMinutes < 60) {
    return context.l10n.relaySettingsTimeAgo('${diff.inMinutes}m');
  } else if (diff.inHours < 24) {
    return context.l10n.relaySettingsTimeAgo('${diff.inHours}h');
  } else {
    return context.l10n.relaySettingsTimeAgo('${diff.inDays}d');
  }
}
