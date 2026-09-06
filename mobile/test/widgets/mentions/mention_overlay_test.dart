// ABOUTME: Tests for comment mention autocomplete overlay rendering
// ABOUTME: Verifies server suggestion data renders before profile cache catches up

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mentions/mention_suggestion.dart';
import 'package:openvine/services/nip05_verification_service.dart';
import 'package:openvine/widgets/mentions/mention_overlay.dart';

void main() {
  const pubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  group('renders', () {
    testWidgets(
      'renders suggestion display name before profile cache resolves',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: MentionOverlay(
                  suggestions: const [
                    MentionSuggestion(pubkey: pubkey, displayName: 'GaryVee'),
                  ],
                  onSelect: (_, _) {},
                ),
              ),
            ),
          ),
        );

        expect(find.text('GaryVee'), findsOneWidget);
      },
    );

    testWidgets(
      'shows verified NIP-05 instead of npub when suggestion has one',
      (tester) async {
        const claim = MentionNip05Claim(
          pubkey: pubkey,
          nip05: 'garyvee@example.com',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mentionNip05VerificationProvider(
                claim,
              ).overrideWith((ref) async => Nip05VerificationStatus.verified),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: MentionOverlay(
                  suggestions: const [
                    MentionSuggestion(
                      pubkey: pubkey,
                      displayName: 'GaryVee',
                      nip05: 'garyvee@example.com',
                    ),
                  ],
                  onSelect: (_, _) {},
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.text('garyvee@example.com'), findsOneWidget);
        expect(find.textContaining('npub'), findsNothing);
      },
    );

    testWidgets('falls back to npub when NIP-05 verification fails', (
      tester,
    ) async {
      const claim = MentionNip05Claim(
        pubkey: pubkey,
        nip05: 'garyvee@example.com',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mentionNip05VerificationProvider(
              claim,
            ).overrideWith((ref) async => Nip05VerificationStatus.failed),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MentionOverlay(
                suggestions: const [
                  MentionSuggestion(
                    pubkey: pubkey,
                    displayName: 'GaryVee',
                    nip05: 'garyvee@example.com',
                  ),
                ],
                onSelect: (_, _) {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('garyvee@example.com'), findsNothing);
      expect(find.textContaining('npub'), findsOneWidget);
    });
  });

  group('interactions', () {
    testWidgets('selecting a suggestion returns its full hex pubkey', (
      tester,
    ) async {
      String? selectedPubkey;
      String? selectedDisplayName;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MentionOverlay(
                suggestions: const [
                  MentionSuggestion(pubkey: pubkey, displayName: 'GaryVee'),
                ],
                onSelect: (pubkey, displayName) {
                  selectedPubkey = pubkey;
                  selectedDisplayName = displayName;
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('GaryVee'));
      await tester.pump();

      expect(selectedPubkey, pubkey);
      expect(selectedDisplayName, 'GaryVee');
    });
  });
}
