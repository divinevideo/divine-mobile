// ABOUTME: Widget tests for interactive and informational verified-account chips.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/profile/verified_account_chip.dart';
import 'package:profile_repository/profile_repository.dart';

const _hex64 =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group(VerifiedAccountChip, () {
    testWidgets('renders platform and identity text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          VerifiedAccountChip(
            claim: const IdentityClaim(
              pubkey: _hex64,
              platform: 'github',
              identity: 'octocat',
              proof: 'abc',
            ),
            launcher: (_) async => true,
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('github'), findsOneWidget);
      expect(find.textContaining('octocat'), findsOneWidget);
    });

    testWidgets('taps launch a github URL for github claims', (tester) async {
      Uri? launched;
      await tester.pumpWidget(
        _wrap(
          VerifiedAccountChip(
            claim: const IdentityClaim(
              pubkey: _hex64,
              platform: 'github',
              identity: 'octocat',
              proof: 'abc',
            ),
            launcher: (uri) async {
              launched = uri;
              return true;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(launched.toString(), equals('https://github.com/octocat'));
    });

    testWidgets('mastodon claims launch the public profile', (
      tester,
    ) async {
      Uri? launched;
      await tester.pumpWidget(
        _wrap(
          VerifiedAccountChip(
            claim: const IdentityClaim(
              pubkey: _hex64,
              platform: 'mastodon',
              identity: 'fosstodon.org/@alice',
              proof: 'abc',
            ),
            launcher: (uri) async {
              launched = uri;
              return true;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(launched, Uri.parse('https://fosstodon.org/@alice'));
    });

    testWidgets('youtube channel claims launch the channel profile', (
      tester,
    ) async {
      Uri? launched;
      await tester.pumpWidget(
        _wrap(
          VerifiedAccountChip(
            claim: const IdentityClaim(
              pubkey: _hex64,
              platform: 'youtube',
              identity: 'UC_x5XG1OV2P6uZZ5FSM9Ttw',
              proof: 'abc',
            ),
            launcher: (uri) async {
              launched = uri;
              return true;
            },
          ),
        ),
      );
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(
        launched,
        Uri.parse(
          'https://www.youtube.com/channel/UC_x5XG1OV2P6uZZ5FSM9Ttw',
        ),
      );
    });

    testWidgets('discord claims are visible but not interactive', (
      tester,
    ) async {
      var launches = 0;
      await tester.pumpWidget(
        _wrap(
          VerifiedAccountChip(
            claim: const IdentityClaim(
              pubkey: _hex64,
              platform: 'discord',
              identity: 'alice',
              proof: 'abc',
            ),
            launcher: (_) async {
              launches++;
              return true;
            },
          ),
        ),
      );

      expect(find.textContaining('discord'), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
      expect(find.byType(DivineIcon), findsNothing);

      final semantics = tester.getSemantics(find.byType(VerifiedAccountChip));
      expect(
        semantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );
      expect(launches, isZero);
    });
  });
}
