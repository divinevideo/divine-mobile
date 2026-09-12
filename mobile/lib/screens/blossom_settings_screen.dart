// ABOUTME: Settings screen for configuring Blossom media server uploads
// ABOUTME: Allows users to enable Blossom uploads and configure their preferred server

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/blossom_settings/blossom_settings_cubit.dart';
import 'package:openvine/blocs/blossom_settings/blossom_settings_state.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';

/// Page: bridges `BlossomUploadService` into [BlossomSettingsCubit].
class BlossomSettingsScreen extends ConsumerWidget {
  const BlossomSettingsScreen({super.key});

  /// Route name for this screen.
  static const routeName = 'blossom-settings';

  /// Path for this route.
  static const String path = RoutePaths.blossomSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blossomUploadService = ref.watch(blossomUploadServiceProvider);
    return BlocProvider(
      key: ValueKey(blossomUploadService),
      create: (_) =>
          BlossomSettingsCubit(blossomUploadService: blossomUploadService)
            ..load(),
      child: const BlossomSettingsView(),
    );
  }
}

/// View: renders blossom settings from the Cubit state. The server-URL
/// `TextEditingController` is owned here (the "first hybrid" pattern —
/// controllers are UI plumbing, not Cubit state).
class BlossomSettingsView extends StatefulWidget {
  @visibleForTesting
  const BlossomSettingsView({super.key});

  @override
  State<BlossomSettingsView> createState() => _BlossomSettingsViewState();
}

class _BlossomSettingsViewState extends State<BlossomSettingsView> {
  final _serverController = TextEditingController();
  bool _seededFromState = false;

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  /// Seeds the server-URL field exactly once, on the first `ready`/`saving`
  /// state. After the first seed the [TextEditingController] owns the value;
  /// later state emissions intentionally do not overwrite the user's input.
  void _seedControllerIfNeeded(BlossomSettingsState state) {
    if (_seededFromState) return;
    if (state.status == BlossomSettingsStatus.ready ||
        state.status == BlossomSettingsStatus.saving) {
      _serverController.text = state.initialServerUrl;
      _seededFromState = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BlossomSettingsCubit, BlossomSettingsState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        if (state.status == BlossomSettingsStatus.saveSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            DivineSnackbarContainer.snackBar(context.l10n.blossomSettingsSaved),
          );
          context.pop();
        } else if (state.status == BlossomSettingsStatus.saveFailure) {
          final messenger = ScaffoldMessenger.of(context);
          final message = switch (state.saveFailureMessageKey) {
            BlossomSaveFailureKey.invalidServerUrl =>
              context.l10n.blossomValidServerUrl,
            BlossomSaveFailureKey.mustUseHttps =>
              context.l10n.blossomServerUrlMustUseHttps,
            BlossomSaveFailureKey.genericFailure ||
            null => context.l10n.blossomFailedToSaveSettings,
          };
          messenger.showSnackBar(
            DivineSnackbarContainer.snackBar(message, error: true),
          );
        }
      },
      builder: (context, state) {
        _seedControllerIfNeeded(state);
        final isLoading =
            state.status == BlossomSettingsStatus.loading ||
            state.status == BlossomSettingsStatus.initial;
        final isSaving = state.status == BlossomSettingsStatus.saving;
        return Scaffold(
          appBar: DiVineAppBar(
            title: context.l10n.nostrSettingsMediaServers,
            showBackButton: true,
            onBackPressed: context.pop,
            actions: isLoading
                ? const []
                : [
                    DiVineAppBarAction(
                      icon: SvgIconSource(DivineIconName.check.assetPath),
                      onPressed: isSaving
                          ? null
                          : () => context.read<BlossomSettingsCubit>().save(
                              _serverController.text,
                            ),
                      tooltip: context.l10n.blossomSaveTooltip,
                    ),
                  ],
          ),
          backgroundColor: context.vineColors.background,
          body: isLoading
              ? const Center(child: BrandedLoadingIndicator(size: 60))
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: ListView(
                      padding: .fromLTRB(
                        0,
                        16,
                        0,
                        16 + MediaQuery.viewPaddingOf(context).bottom,
                      ),
                      children: [
                        const _AboutCard(),
                        const SizedBox(height: 20),
                        const _EnableToggle(),
                        const SizedBox(height: 20),
                        if (state.isBlossomEnabled)
                          _ServerUrlSection(
                            controller: _serverController,
                          ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DivineInfoCard(
        title: context.l10n.blossomAboutTitle,
        message: context.l10n.blossomAboutDescription,
      ),
    );
  }
}

class _EnableToggle extends StatelessWidget {
  const _EnableToggle();

  @override
  Widget build(BuildContext context) {
    final isEnabled = context.select(
      (BlossomSettingsCubit cubit) => cubit.state.isBlossomEnabled,
    );
    return DivineSwitchTile(
      title: context.l10n.blossomUseCustomServer,
      subtitle: isEnabled
          ? context.l10n.blossomCustomServerEnabledSubtitle
          : context.l10n.blossomCustomServerDisabledSubtitle,
      value: isEnabled,
      onChanged: (value) =>
          context.read<BlossomSettingsCubit>().setEnabled(value),
    );
  }
}

class _ServerUrlSection extends StatelessWidget {
  const _ServerUrlSection({required this.controller});

  final TextEditingController controller;

  static const _popularServers = <(String url, String name)>[
    ('https://blossom.band', 'Blossom Band'),
    ('https://cdn.satellite.earth', 'Satellite Earth'),
    ('https://blossom.primal.net', 'Primal'),
    ('https://nostr.download', 'Nostr Download'),
    ('https://cdn.nostrcheck.me', 'NostrCheck'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.blossomCustomServerUrl,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          DivineTextField(
            controller: controller,
            labelText: 'https://blossom.band',
            keyboardType: TextInputType.url,
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
            spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.blossomCustomServerHelper,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 30),
          Text(
            context.l10n.blossomPopularServers,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.primaryText,
            ),
          ),
          const SizedBox(height: 12),
          for (final entry in _popularServers)
            _ServerOption(
              url: entry.$1,
              name: entry.$2,
              onSelect: () => controller.text = entry.$1,
            ),
        ],
      ),
    );
  }
}

class _ServerOption extends StatelessWidget {
  const _ServerOption({
    required this.url,
    required this.name,
    required this.onSelect,
  });

  final String url;
  final String name;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.vineColors.surfaceContainer,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          name,
          style: VineTheme.bodyLargeFont(color: context.vineColors.primaryText),
        ),
        subtitle: Text(
          url,
          style: VineTheme.bodySmallFont(
            color: context.vineColors.onSurfaceMuted,
          ),
        ),
        trailing: const DivineIcon(
          icon: DivineIconName.arrowRight,
          color: VineTheme.vineGreen,
        ),
        onTap: onSelect,
      ),
    );
  }
}
