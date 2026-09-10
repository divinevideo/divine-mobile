// ABOUTME: Widget tests for the post-publish confirmation sheet's actions,
// ABOUTME: dismissal, and thumbnail fallback.

import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/post_publish/view/post_publish_confirmation_sheet.dart';
import 'package:openvine/l10n/l10n.dart';

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

/// Stand-in for a cover frame. Never decoded — the assertions below read the
/// widget's [MemoryImage], so the bytes only need to be identifiable.
final _coverFrame = Uint8List.fromList([1, 2, 3, 4, 5]);

/// Pumps a host screen with a button that opens the confirmation sheet.
Future<void> _pumpSheetHost(
  WidgetTester tester, {
  required VoidCallback onView,
  required VoidCallback onShare,
  Uint8List? thumbnailBytes,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: VineTheme.theme,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: DivineButton(
              label: 'open',
              onPressed: () => PostPublishConfirmationSheet.show(
                context: context,
                onView: onView,
                onShare: onShare,
                thumbnailBytes: thumbnailBytes,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group(PostPublishConfirmationSheet, () {
    testWidgets('offers view and share, not a prompt to record again', (
      tester,
    ) async {
      await _pumpSheetHost(tester, onView: () {}, onShare: () {});

      expect(find.text(_l10n.postPublishConfirmationTitle), findsOneWidget);
      expect(find.text(_l10n.postPublishConfirmationView), findsOneWidget);
      expect(find.text(_l10n.postPublishConfirmationShare), findsOneWidget);
      // The offer this replaces. Its return would be the regression.
      expect(find.text(_l10n.libraryRecordVideo), findsNothing);
    });

    testWidgets('reads its copy from l10n rather than hardcoded English', (
      tester,
    ) async {
      await _pumpSheetHost(tester, onView: () {}, onShare: () {});

      expect(
        find.text(
          lookupAppLocalizations(
            const Locale('de'),
          ).postPublishConfirmationView,
        ),
        findsNothing,
      );
    });

    testWidgets('view fires its callback and closes the sheet', (tester) async {
      var viewed = 0;
      await _pumpSheetHost(tester, onView: () => viewed++, onShare: () {});

      await tester.tap(find.text(_l10n.postPublishConfirmationView));
      await tester.pumpAndSettle();

      expect(viewed, equals(1));
      expect(find.text(_l10n.postPublishConfirmationTitle), findsNothing);
    });

    testWidgets('share fires its callback and closes the sheet', (
      tester,
    ) async {
      var shared = 0;
      await _pumpSheetHost(tester, onView: () {}, onShare: () => shared++);

      await tester.tap(find.text(_l10n.postPublishConfirmationShare));
      await tester.pumpAndSettle();

      expect(shared, equals(1));
      expect(find.text(_l10n.postPublishConfirmationTitle), findsNothing);
    });

    testWidgets('the close action dismisses without acting on the video', (
      tester,
    ) async {
      var viewed = 0;
      var shared = 0;
      await _pumpSheetHost(
        tester,
        onView: () => viewed++,
        onShare: () => shared++,
      );

      await tester.tap(
        find.bySemanticsLabel(_l10n.commonClose),
      );
      await tester.pumpAndSettle();

      expect(find.text(_l10n.postPublishConfirmationTitle), findsNothing);
      expect(viewed, isZero);
      expect(shared, isZero);
    });

    testWidgets('previews the cover frame it was handed', (tester) async {
      // Bytes, not a path: publishing deletes the draft and reclaims its
      // cover file, so a path would be dangling by the time this decoded.
      await _pumpSheetHost(
        tester,
        onView: () {},
        onShare: () {},
        thumbnailBytes: _coverFrame,
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(
        image.image,
        isA<MemoryImage>().having(
          (provider) => provider.bytes,
          'bytes',
          equals(_coverFrame),
        ),
      );
    });

    testWidgets('still opens when the draft carried no cover frame', (
      tester,
    ) async {
      // A draft with no cover frame must not cost the creator the whole
      // confirmation.
      await _pumpSheetHost(tester, onView: () {}, onShare: () {});

      expect(find.byType(Image), findsNothing);
      expect(find.text(_l10n.postPublishConfirmationView), findsOneWidget);
    });

    testWidgets('labels the thumbnail for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpSheetHost(
        tester,
        onView: () {},
        onShare: () {},
        thumbnailBytes: _coverFrame,
      );

      expect(
        find.bySemanticsLabel(_l10n.postPublishConfirmationThumbnailLabel),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
