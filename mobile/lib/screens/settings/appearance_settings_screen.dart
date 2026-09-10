import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/appearance/bloc/appearance_cubit.dart';
import 'package:openvine/features/appearance/models/appearance_mode.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_paths.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  static const routeName = 'appearance-settings';
  static const String path = RoutePaths.appearanceSettings;

  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.appearanceSettingsTitle,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      body: BlocBuilder<AppearanceCubit, AppearanceMode>(
        builder: (context, mode) => ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                context.l10n.appearanceSettingsSubtitle,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.secondaryText,
                ),
              ),
            ),
            _ModeTile(
              title: context.l10n.appearanceSettingsSystem,
              value: AppearanceMode.system,
              selected: mode,
            ),
            _ModeTile(
              title: context.l10n.appearanceSettingsLight,
              value: AppearanceMode.light,
              selected: mode,
            ),
            _ModeTile(
              title: context.l10n.appearanceSettingsDark,
              value: AppearanceMode.dark,
              selected: mode,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.title,
    required this.value,
    required this.selected,
  });

  final String title;
  final AppearanceMode value;
  final AppearanceMode selected;

  @override
  Widget build(BuildContext context) {
    return DivineSelectableRow(
      title: title,
      isSelected: value == selected,
      onTap: () => context.read<AppearanceCubit>().setMode(value),
    );
  }
}
