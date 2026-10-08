// ABOUTME: Tests PeopleListResultNotice's per-result copy and live region.
// ABOUTME: Pending and successful results must render nothing.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/view/widgets/people_list_result_notice.dart';
import 'package:openvine/l10n/l10n.dart';

void main() {
  group(PeopleListResultNotice, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    Widget buildSubject(PeopleListsOperationResult? result) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PeopleListResultNotice(
            result: result,
            failedMessage: 'Custom failure copy',
          ),
        ),
      );
    }

    testWidgets('shows the supplied copy for a failed result', (tester) async {
      await tester.pumpWidget(
        buildSubject(PeopleListsOperationResult.failed),
      );

      expect(find.text('Custom failure copy'), findsOneWidget);
    });

    testWidgets('reports a cancelled result as a changed session', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(PeopleListsOperationResult.cancelled),
      );

      expect(find.text(l10n.peopleListsSessionChanged), findsOneWidget);
      expect(find.text('Custom failure copy'), findsNothing);
    });

    for (final result in [null, PeopleListsOperationResult.succeeded]) {
      testWidgets('renders nothing for $result', (tester) async {
        await tester.pumpWidget(buildSubject(result));

        expect(find.byType(Text), findsNothing);
      });
    }

    testWidgets('announces the message as a live region', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        buildSubject(PeopleListsOperationResult.failed),
      );

      final semantics = tester.getSemantics(find.text('Custom failure copy'));
      expect(semantics.label, 'Custom failure copy');
      expect(semantics.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });
  });
}
