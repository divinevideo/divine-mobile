import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/widgets/video_feed_item/content_warning_helpers.dart';

import '../helpers/large_screen_layout.dart';

class _MockContentFilterService extends Mock implements ContentFilterService {}

void main() {
  group('Overlay widths', () {
    for (final (windowWidth, sheetWidth, snackbarWidth) in [
      (1440.0, 640.0, 480.0),
      (390.0, 390.0, 390.0),
    ]) {
      testWidgets('centers the bottom sheet at $windowWidth pt', (
        tester,
      ) async {
        setTestWindowSize(tester, windowWidth);
        await tester.pumpWidget(
          largeScreenLayoutApp(
            enabled: true,
            theme: VineTheme.theme,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => unawaited(
                    VineBottomSheet.show<void>(
                      context: context,
                      body: const SizedBox(width: double.infinity, height: 100),
                    ),
                  ),
                  child: const Text('Open sheet'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open sheet'));
        await tester.pumpAndSettle();

        final rect = tester.getRect(find.byType(VineBottomSheet));
        expect(rect.width, sheetWidth);
        expect(rect.center.dx, windowWidth / 2);
        expect(rect.bottom, 900);
      });

      testWidgets('centers the content warning snackbar at $windowWidth pt', (
        tester,
      ) async {
        setTestWindowSize(tester, windowWidth);
        final filter = _MockContentFilterService();
        when(filter.initialize).thenAnswer((_) async {});
        await tester.pumpWidget(
          largeScreenLayoutApp(
            enabled: true,
            theme: VineTheme.theme,
            overrides: [contentFilterServiceProvider.overrideWithValue(filter)],
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () => unawaited(
                    hideContentWarningsLikeThese(
                      context: context,
                      ref: ref,
                      labels: const ['unknown-label'],
                    ),
                  ),
                  child: Text(context.l10n.contentWarningHideAllLikeThis),
                ),
              ),
            ),
          ),
        );
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.contentWarningHideAllLikeThis));
        await tester.pumpAndSettle();

        final snackbar = find.byType(SnackBar);
        expect(
          find.descendant(
            of: snackbar,
            matching: find.text(l10n.contentWarningNoFilterYet),
          ),
          findsOneWidget,
        );
        final surface = find
            .descendant(of: snackbar, matching: find.byType(Material))
            .first;
        expect(tester.getSize(surface).width, snackbarWidth);
        expect(tester.getCenter(surface).dx, windowWidth / 2);
      });
    }
  });
}
