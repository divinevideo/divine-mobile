// ABOUTME: Widget test for SocialCountsInfoSheet's "Learn more" FAQ deep-link,
// ABOUTME: which opens the follower-counts answer on the public FAQ. #8276 AC#4.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/creator_analytics/social_counts_info_sheet.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../helpers/url_launcher_test_double.dart';

void main() {
  group('SocialCountsInfoSheet', () {
    testWidgets(
      'Learn more opens the follower-counts FAQ in an external browser',
      (tester) async {
        final launcher = UrlLauncherTestDouble();
        final originalPlatform = UrlLauncherPlatform.instance;
        UrlLauncherPlatform.instance = launcher;
        addTearDown(() => UrlLauncherPlatform.instance = originalPlatform);

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: const Scaffold(
              body: SingleChildScrollView(child: SocialCountsInfoSheet()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Learn more'));
        await tester.pumpAndSettle();

        expect(launcher.launched, hasLength(1));
        expect(
          launcher.launched.single.url,
          'https://about.divine.video/faqs/#follower-counts',
        );
        expect(launcher.launched.single.useExternalApplication, isTrue);
      },
    );
  });
}
