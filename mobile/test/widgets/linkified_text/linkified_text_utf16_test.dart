// ABOUTME: Regression test for Crashlytics #6111 — malformed UTF-16 in
// ABOUTME: user content must not crash LinkifiedText's paragraph layout.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_widgets.dart';

void main() {
  group('LinkifiedText UTF-16 safety', () {
    testWidgets('renders text containing a lone high surrogate', (
      tester,
    ) async {
      // A truncated emoji leaves an unpaired high surrogate; the raw
      // string crashes _NativeParagraphBuilder.addText (#6111).
      final malformed = 'broken ${String.fromCharCode(0xD83D)} #vine';

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: LinkifiedText(text: malformed)),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(LinkifiedText), findsOneWidget);
    });

    testWidgets('renders plain text containing a lone low surrogate', (
      tester,
    ) async {
      final malformed = 'oops${String.fromCharCode(0xDE00)}';

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: LinkifiedText(text: malformed)),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('oops\uFFFD'), findsOneWidget);
    });

    testWidgets('renders $SelectableLinkifiedText with a lone surrogate', (
      tester,
    ) async {
      final malformed = 'sel ${String.fromCharCode(0xD83D)} #vine';

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SelectableLinkifiedText(text: malformed)),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SelectableLinkifiedText), findsOneWidget);
    });
  });
}
