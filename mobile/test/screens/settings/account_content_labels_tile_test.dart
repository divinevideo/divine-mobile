// ABOUTME: Widget tests for AccountContentLabelsTile — renders the selected
// ABOUTME: labels and persists a new selection through AccountLabelService.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/l10n/localized_content_label_name.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/settings/account_content_labels_tile.dart';
import 'package:openvine/services/account_label_service.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockAccountLabelService extends Mock implements AccountLabelService {}

void main() {
  setUpAll(() {
    registerFallbackValue(<ContentLabel>{});
  });

  group(AccountContentLabelsTile, () {
    late _MockAccountLabelService service;

    setUp(() {
      service = _MockAccountLabelService();
      when(() => service.accountLabels).thenReturn(const {});
      when(() => service.setAccountLabels(any())).thenAnswer((_) async {});
    });

    Widget buildSubject() => testMaterialApp(
      additionalOverrides: [
        accountLabelServiceProvider.overrideWithValue(service),
      ],
      home: const Scaffold(body: AccountContentLabelsTile()),
    );

    AppLocalizations l10nOf(WidgetTester tester) => AppLocalizations.of(
      tester.element(find.byType(AccountContentLabelsTile)),
    );

    testWidgets('shows the empty subtitle when no labels are set', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(
        find.text(l10nOf(tester).contentPreferencesAccountLabelsEmpty),
        findsOneWidget,
      );
    });

    testWidgets('lists the selected label names', (tester) async {
      when(
        () => service.accountLabels,
      ).thenReturn(const {ContentLabel.nudity});

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(
        find.text(
          localizedContentLabelName(l10nOf(tester), ContentLabel.nudity),
        ),
        findsOneWidget,
      );
    });

    testWidgets('opens the multiselect and persists the chosen labels', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Open the multiselect sheet.
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();
      expect(find.byType(DivineRowCheckbox), findsWidgets);

      // Select the first label and confirm.
      await tester.tap(find.byType(DivineRowCheckbox).first);
      await tester.pump();
      // Two DivineButtons live in the sheet (header "Clear all" + the pinned
      // confirm action); the confirm one is the expanded, full-width button.
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is DivineButton && widget.expanded,
        ),
      );
      await tester.pumpAndSettle();

      verify(() => service.setAccountLabels(any())).called(1);
    });
  });
}
