import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/notifications/view/announcement_detail_screen.dart';

void main() {
  final announcement = AnnouncementNotification(
    announcementId: 'd7388b9c-b35c-4269-8fc5-fac5d7a454ad',
    title: 'Your profile has a home',
    body: 'The full announcement body.\n\nYour website is ready to share.',
    timestamp: DateTime.utc(2026, 10, 23),
    expiresAt: DateTime.utc(2026, 11, 23),
    learnMoreUrl: Uri.parse('https://divine.video/updates'),
  );

  Future<void> pump(WidgetTester tester, Widget screen) => tester.pumpWidget(
    MaterialApp(
      theme: VineTheme.theme,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: screen,
    ),
  );

  testWidgets('shows full message and opens the validated learn-more URL', (
    tester,
  ) async {
    Uri? opened;
    await pump(
      tester,
      AnnouncementDetailScreen(
        announcement: announcement,
        onLearnMore: (url) async => opened = url,
      ),
    );
    expect(find.text('From Divine'), findsOneWidget);
    expect(find.text(announcement.title), findsOneWidget);
    expect(find.text(announcement.body), findsOneWidget);
    await tester.tap(find.text('Learn More'));
    expect(opened, Uri.parse('https://divine.video/updates'));
  });

  testWidgets('missing or withdrawn announcement has a safe empty state', (
    tester,
  ) async {
    await pump(tester, const AnnouncementDetailScreen());
    expect(
      find.text('This announcement is no longer available.'),
      findsOneWidget,
    );
    expect(find.text('Learn More'), findsNothing);
  });

  for (final brightness in Brightness.values) {
    testWidgets('supports large text in ${brightness.name} appearance', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == Brightness.dark
              ? VineTheme.theme
              : VineTheme.lightTheme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: AnnouncementDetailScreen(
            announcement: announcement,
            onLearnMore: (_) async {},
          ),
        ),
      );
      expect(find.text(announcement.title), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Learn More'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(find.text('Learn More'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('does not offer a learn-more action without a URL', (
    tester,
  ) async {
    await pump(
      tester,
      AnnouncementDetailScreen(
        announcement: AnnouncementNotification(
          announcementId: 'd7388b9c-b35c-4269-8fc5-fac5d7a454ad',
          title: 'A small update',
          body: 'Everything you need is here.',
          timestamp: DateTime.utc(2026, 10, 23),
          expiresAt: DateTime.utc(2026, 11, 23),
        ),
      ),
    );
    expect(find.text('Everything you need is here.'), findsOneWidget);
    expect(find.text('Learn More'), findsNothing);
  });
}
