// ABOUTME: The MaterialApp.router, rebuilt when locale or appearance changes
// ABOUTME: Split out of _DivineAppState.build() (#3337)

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show Intl;
import 'package:openvine/blocs/locale/locale_cubit.dart';
import 'package:openvine/features/app_review/app_review_coordinator.dart';
import 'package:openvine/features/appearance/bloc/appearance_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/resolve_app_ui_locale.dart';
import 'package:openvine/providers/layer_rasterizer_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/startup/database_corruption_gate.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show LayerRasterizerHost;

/// The app's [MaterialApp].
///
/// Reads the locale and appearance cubits provided by [AppCompositionRoot],
/// so it can only be mounted beneath that tree.
class DivineMaterialApp extends ConsumerWidget {
  const DivineMaterialApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = context.watch<LocaleCubit>().state.locale;
    final appearanceMode = context.watch<AppearanceCubit>().state;

    if (locale != null) {
      Intl.defaultLocale = locale.toLanguageTag();
    }
    final themeMode = resolveThemeMode(mode: appearanceMode);
    return PlatformBrightnessStatusBar(
      themeMode: themeMode,
      child: MaterialApp.router(
        title: 'Divine',
        debugShowCheckedModeBanner: false,
        theme: VineTheme.lightTheme,
        darkTheme: VineTheme.theme,
        themeMode: themeMode,
        // A saved route state go_router cannot decode must not take the
        // launch path down with it — the same state replays on every cold
        // start, so the crash loops instead of recovering (#7869).
        routerConfig: ref.read(routerConfigProvider),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        localeListResolutionCallback: resolveAppUiLocale,
        // One gate above every route: once the local database reports
        // corruption there is no screen left that can work, so ask for the
        // restart that repairs it instead of failing route by route. The
        // review coordinator lives inside that gate so the recovery screen
        // cannot be interrupted by an OS-native review card.
        //
        // The rasterizer host sits above both: baking a draft's editor layers
        // needs them mounted somewhere, and that has to keep working while the
        // corruption gate swaps out everything below it.
        builder: (context, child) => LayerRasterizerHost(
          rasterizer: ref.read(layerRasterizerProvider),
          child: DatabaseCorruptionGate(
            child: AppReviewCoordinator(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps the root status-bar style synchronized with the effective appearance.
class PlatformBrightnessStatusBar extends StatefulWidget {
  const PlatformBrightnessStatusBar({
    required this.child,
    this.themeMode = ThemeMode.system,
    super.key,
  });

  final Widget child;
  final ThemeMode themeMode;

  @override
  State<PlatformBrightnessStatusBar> createState() =>
      _PlatformBrightnessStatusBarState();
}

class _PlatformBrightnessStatusBarState
    extends State<PlatformBrightnessStatusBar>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (widget.themeMode == ThemeMode.system) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBrightness = switch (widget.themeMode) {
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness,
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
    };
    final statusBarStyle = effectiveBrightness == Brightness.light
        ? VineTheme.lightStatusBarStyle
        : VineTheme.statusBarStyle;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: statusBarStyle,
      child: widget.child,
    );
  }
}
