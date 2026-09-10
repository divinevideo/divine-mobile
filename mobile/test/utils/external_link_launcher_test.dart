// ABOUTME: Tests for shared outbound external-link launch policy.
// ABOUTME: Covers trusted hosts, mailto normalization, scheme prepending, and confirmation.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/utils/external_link_launcher.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../helpers/url_launcher_test_double.dart';

void main() {
  group('isTrustedExternalLinkHost', () {
    test('accepts Divine hosts and subdomains case-insensitively', () {
      expect(isTrustedExternalLinkHost('divine.video'), isTrue);
      expect(isTrustedExternalLinkHost('MEDIA.DIVINE.VIDEO'), isTrue);
      expect(isTrustedExternalLinkHost('cdn.divine.video'), isTrue);
    });

    test('rejects lookalike external hosts', () {
      expect(isTrustedExternalLinkHost('evildivine.video'), isFalse);
      expect(isTrustedExternalLinkHost('divine.video.example.com'), isFalse);
    });
  });

  group(openExternalLink, () {
    late UrlLauncherPlatform originalPlatform;
    late UrlLauncherTestDouble launcher;

    setUp(() {
      originalPlatform = UrlLauncherPlatform.instance;
      launcher = UrlLauncherTestDouble();
      UrlLauncherPlatform.instance = launcher;
    });

    tearDown(() {
      UrlLauncherPlatform.instance = originalPlatform;
    });

    testWidgets('prepends https for trusted hosts without confirmation', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _Harness(link: 'media.divine.video/watch/1'),
      );

      await tester.tap(find.byKey(_Harness.openButtonKey));
      await tester.pump();

      expect(
        launcher.launched.single.url,
        'https://media.divine.video/watch/1',
      );
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('opens Divine Exit without confirmation', (tester) async {
      await tester.pumpWidget(
        const _Harness(link: 'https://divine.video/exit'),
      );

      await tester.tap(find.byKey(_Harness.openButtonKey));
      await tester.pump();

      expect(launcher.launched.single.url, 'https://divine.video/exit');
      expect(launcher.launched.single.useExternalApplication, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('normalizes bare email addresses to mailto', (tester) async {
      await tester.pumpWidget(const _Harness(link: 'creator@example.com'));

      await tester.tap(find.byKey(_Harness.openButtonKey));
      await tester.pump();

      expect(launcher.launched.single.url, 'mailto:creator@example.com');
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('prepends https for untrusted links when confirmation is off', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _Harness(
          link: 'example.com/support',
          requireConfirmationForUntrusted: false,
        ),
      );

      await tester.tap(find.byKey(_Harness.openButtonKey));
      await tester.pump();

      expect(launcher.launched.single.url, 'https://example.com/support');
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('asks before launching untrusted links', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.pumpWidget(const _Harness(link: 'https://example.com/pay'));

      await tester.tap(find.byKey(_Harness.openButtonKey));
      await tester.pumpAndSettle();

      expect(launcher.launched, isEmpty);
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(l10n.messageExternalLinkDialogOpen),
        ),
      );
      await tester.pumpAndSettle();

      expect(launcher.launched.single.url, 'https://example.com/pay');
    });
  });
}

class _Harness extends StatelessWidget {
  const _Harness({
    required this.link,
    this.requireConfirmationForUntrusted = true,
  });

  static const openButtonKey = Key('external-link-launcher-open-button');

  final String link;
  final bool requireConfirmationForUntrusted;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: VineTheme.theme,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: openButtonKey,
              onPressed: () => openExternalLink(
                context,
                link,
                requireConfirmationForUntrusted:
                    requireConfirmationForUntrusted,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }
}
