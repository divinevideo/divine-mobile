import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// Wraps a widget with localization delegates for testing.
///
/// Use this when testing widgets that access `context.l10n`.
Widget buildLocalizedWidget(Widget child) {
  return MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}
