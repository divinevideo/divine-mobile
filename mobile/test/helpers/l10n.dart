import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';

/// Wraps a widget with localization delegates for testing.
///
/// Use this when testing widgets that access `context.l10n`.
Widget buildLocalizedWidget(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}
