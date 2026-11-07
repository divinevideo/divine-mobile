// ABOUTME: Tests for NotificationLeadingTypeIcon — the shared wrapper
// ABOUTME: that combines notificationTypeIconSpec with NotificationTypeIcon
// ABOUTME: for use in both row variants.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/notifications/widgets/notification_leading_type_icon.dart';
import 'package:openvine/notifications/widgets/notification_type_icon_spec.dart';
import 'package:openvine/widgets/notification_type_icon.dart';

Future<void> _pump(
  WidgetTester tester, {
  required NotificationKind type,
  required bool isRead,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme ?? VineTheme.theme,
      home: Scaffold(
        body: NotificationLeadingTypeIcon(type: type, isRead: isRead),
      ),
    ),
  );
}

void main() {
  group(NotificationLeadingTypeIcon, () {
    for (final appearance in ['dark', 'light']) {
      testWidgets('loads every notification icon as a compiled vector in '
          '$appearance mode', (tester) async {
        for (final kind in NotificationKind.values) {
          await _pump(
            tester,
            type: kind,
            isRead: false,
            theme: appearance == 'dark'
                ? VineTheme.theme
                : VineTheme.lightTheme,
          );
          final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
          expect(picture.bytesLoader, isNot(isA<SvgAssetLoader>()));
          final context = tester.element(find.byType(SvgPicture));
          final decoded = await tester.runAsync(
            () => vg.loadPicture(picture.bytesLoader, context),
          );
          expect(decoded, isNotNull, reason: kind.name);
          expect(decoded!.size.isEmpty, isFalse, reason: kind.name);
          decoded.picture.dispose();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: kind.name);
        }
      });
    }

    testWidgets('renders the underlying $NotificationTypeIcon', (tester) async {
      await _pump(tester, type: NotificationKind.follow, isRead: false);

      expect(find.byType(NotificationTypeIcon), findsOneWidget);
    });

    testWidgets(
      'forwards the spec for the given kind to NotificationTypeIcon',
      (tester) async {
        await _pump(tester, type: NotificationKind.follow, isRead: true);

        final widget = tester.widget<NotificationTypeIcon>(
          find.byType(NotificationTypeIcon),
        );
        final spec = notificationTypeIconSpec(
          NotificationKind.follow,
          colors: VineTheme.darkColors,
        );
        expect(widget.icon, equals(spec.icon));
        expect(widget.backgroundColor, equals(spec.background));
        expect(widget.foregroundColor, equals(spec.foreground));
      },
    );

    testWidgets('shows unread dot when isRead is false', (tester) async {
      await _pump(tester, type: NotificationKind.like, isRead: false);

      final widget = tester.widget<NotificationTypeIcon>(
        find.byType(NotificationTypeIcon),
      );
      expect(widget.showUnreadDot, isTrue);
    });

    testWidgets('hides unread dot when isRead is true', (tester) async {
      await _pump(tester, type: NotificationKind.like, isRead: true);

      final widget = tester.widget<NotificationTypeIcon>(
        find.byType(NotificationTypeIcon),
      );
      expect(widget.showUnreadDot, isFalse);
    });
  });
}
