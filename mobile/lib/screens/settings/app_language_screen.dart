// ABOUTME: App language picker screen for changing the UI display locale
// ABOUTME: Uses LocaleCubit to persist and apply locale changes immediately

import 'dart:ui';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/locale/locale_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/services/locale_preference_service.dart';

/// Screen for selecting the app's display language.
///
/// Shows "Device default" at the top followed by all supported locales
/// with their native names. Tapping a locale saves it via [LocaleCubit]
/// and the app updates immediately.
class AppLanguageScreen extends StatelessWidget {
  static const routeName = 'app-language';
  static const String path = RoutePaths.appLanguage;

  const AppLanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.settingsAppLanguageTitle,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: context.vineColors.background,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: BlocBuilder<LocaleCubit, LocaleState>(
            builder: (context, state) {
              final currentLocale = state.locale;
              final isDeviceDefault = currentLocale == null;

              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      context.l10n.settingsAppLanguageDescription,
                      style: VineTheme.bodyMediumFont(
                        color: context.vineColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  _DeviceDefaultTile(isSelected: isDeviceDefault),
                  Divider(color: context.vineColors.outlineMuted, height: 1),
                  ...LocalePreferenceService.supportedLocales.entries.map(
                    (entry) => _LocaleTile(
                      code: entry.key,
                      nativeName: entry.value,
                      isSelected:
                          !isDeviceDefault &&
                          currentLocale.languageCode == entry.key,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DeviceDefaultTile extends StatelessWidget {
  const _DeviceDefaultTile({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final deviceLanguageCode = PlatformDispatcher.instance.locale.languageCode;
    final deviceLanguageName = LocalePreferenceService.nativeNameFor(
      deviceLanguageCode,
    );

    return DivineSelectableRow(
      title: context.l10n.settingsAppLanguageUseDeviceLanguage,
      subtitle: deviceLanguageName,
      isSelected: isSelected,
      onTap: () => context.read<LocaleCubit>().clearLocale(),
    );
  }
}

class _LocaleTile extends StatelessWidget {
  const _LocaleTile({
    required this.code,
    required this.nativeName,
    required this.isSelected,
  });

  final String code;
  final String nativeName;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return DivineSelectableRow(
      title: nativeName,
      subtitle: code.toUpperCase(),
      isSelected: isSelected,
      onTap: () => context.read<LocaleCubit>().setLocale(code),
    );
  }
}
