// ABOUTME: The MaterialApp.router, rebuilt when locale or appearance changes
// ABOUTME: Split out of _DivineAppState.build() (#3337)

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show Intl;
import 'package:material_ui/material_ui.dart';
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
        // go_router can fail to decode the route state it reported itself when
        // this router is mounted again or refreshed; unguarded, that leaves
        // the app with no routes (#7869).
        routerConfig: ref.read(routerConfigProvider),
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
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
        //
        // The compatibility bridge is outermost. Packages that still build on
        // `package:flutter/material.dart` — skeletonizer is the one that
        // renders on Divine screens today — read the framework's
        // `Theme.of(context)`, which no longer finds this app's theme and
        // silently degrades to `ThemeData.fallback()`: a light theme, so
        // skeletonizer picks its light shimmer on every dark page. The bridge
        // maps the material_ui theme back onto the framework types for the
        // whole subtree, which is what the material_ui migration guide
        // prescribes (#8916). It goes away when the last such package moves.
        // The bridge ships deprecated on purpose, to mark it as migration
        // scaffolding rather than API.
        // TODO(#9078): Remove after all rendered dependencies use material_ui.
        // ignore: deprecated_member_use
        builder: (context, child) => MaterialUiCompatibilityBridge(
          child: LayerRasterizerHost(
            rasterizer: ref.read(layerRasterizerProvider),
            child: DatabaseCorruptionGate(
              child: AppReviewCoordinator(
                child: child ?? const SizedBox.shrink(),
              ),
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
