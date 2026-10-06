// ABOUTME: Verifies the shared recovery notice uses the current locale.
// ABOUTME: Keeps the readonly explanation accessible as live feedback.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/curated_list_recovery_read_only_notice.dart';

void main() {
  testWidgets('announces localized readonly recovery feedback', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('es'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: CuratedListRecoveryReadOnlyNotice()),
      ),
    );
    final l10n = lookupAppLocalizations(const Locale('es'));
    expect(find.text(l10n.listRecoveryReadOnly), findsOneWidget);
    expect(
      find.text(
        lookupAppLocalizations(const Locale('en')).listRecoveryReadOnly,
      ),
      findsNothing,
    );
    expect(
      tester.getSemantics(find.text(l10n.listRecoveryReadOnly)),
      isSemantics(isLiveRegion: true, label: l10n.listRecoveryReadOnly),
    );
    semantics.dispose();
  });
}
