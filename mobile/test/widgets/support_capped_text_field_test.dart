// ABOUTME: Widget tests for support form text-field feedback
// ABOUTME: Covers rejected keyboard images alongside paste truncation notices

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/support_capped_text_field.dart';

import '../helpers/keyboard_content_insertion.dart';

void main() {
  const notice = 'That image was not added.';
  late TextEditingController controller;

  setUp(() => controller = TextEditingController());
  tearDown(() => controller.dispose());

  Widget buildSubject({String? imageInsertionNotice = notice}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SupportCappedTextField(
          controller: controller,
          maxLength: 100,
          imageInsertionNotice: imageInsertionNotice,
        ),
      ),
    );
  }

  group('keyboard image insertion', () {
    testWidgets('leaves insertion disabled without notice', (tester) async {
      await tester.pumpWidget(buildSubject(imageInsertionNotice: null));

      expect(
        tester
            .widget<TextField>(find.byType(TextField))
            .contentInsertionConfiguration,
        isNull,
      );
    });

    testWidgets('shows visible feedback without changing text', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'typed report details');

      await commitKeyboardImage(tester);
      await tester.pumpAndSettle();

      expect(find.text(notice), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'typed report details',
      );
    });

    testWidgets('announces every rejection', (tester) async {
      final announcements = <String>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
            SystemChannels.accessibility,
            (
              message,
            ) async {
              final data = message! as Map<Object?, Object?>;
              if (data['type'] == 'announce') {
                final payload = data['data']! as Map<Object?, Object?>;
                announcements.add(payload['message']! as String);
              }
              return null;
            },
          );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              null,
            ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(TextField));
      await commitKeyboardImage(tester);
      await commitKeyboardImage(tester);
      await tester.pumpAndSettle();

      expect(announcements.where((message) => message == notice), hasLength(2));
    });

    testWidgets('clears feedback when the reporter types', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(TextField));
      await commitKeyboardImage(tester);
      await tester.pumpAndSettle();
      expect(find.text(notice), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'described in words');
      await tester.pumpAndSettle();

      expect(find.text(notice), findsNothing);
    });

    testWidgets('renders feedback above the affected field', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(TextField));
      await commitKeyboardImage(tester);
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.text(notice)).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(TextField)).top),
      );
    });
  });
}
