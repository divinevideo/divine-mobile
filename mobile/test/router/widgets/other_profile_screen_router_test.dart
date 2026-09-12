// ABOUTME: Tests the blockee-side gate on OtherProfileScreenRouter — a block
// ABOUTME: now arrives as a kind 10000 mute, so hasMutedUs must gate too.

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/router/widgets/other_profile_screen_router.dart';
import 'package:openvine/screens/user_not_available_screen.dart';

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  // npub1424242… decodes to a hex pubkey distinct from the viewer's.
  const targetNpub =
      'npub1424242424242424242424242424242424242424242424242424qamrcaj';
  const viewerHex =
      '0000000000000000000000000000000000000000000000000000000000000001';

  late _MockContentBlocklistRepository blocklist;
  late _MockNostrClient nostrClient;

  setUp(() {
    blocklist = _MockContentBlocklistRepository();
    nostrClient = _MockNostrClient();
    when(() => nostrClient.publicKey).thenReturn(viewerHex);
    when(() => blocklist.hasMutedUs(any())).thenReturn(false);
    when(() => blocklist.hasBlockedUs(any())).thenReturn(false);
  });

  Future<void> pumpRouter(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentBlocklistRepositoryProvider.overrideWithValue(blocklist),
          nostrServiceProvider.overrideWithValue(nostrClient),
        ],
        child: const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OtherProfileScreenRouter(npub: targetNpub),
        ),
      ),
    );
    await tester.pump();
  }

  group(OtherProfileScreenRouter, () {
    testWidgets('hides the profile when the target muted us', (tester) async {
      when(() => blocklist.hasMutedUs(any())).thenReturn(true);

      await pumpRouter(tester);

      expect(find.byType(UserNotAvailableScreen), findsOneWidget);
    });

    testWidgets('hides the profile when the target blocked us', (tester) async {
      when(() => blocklist.hasBlockedUs(any())).thenReturn(true);

      await pumpRouter(tester);

      expect(find.byType(UserNotAvailableScreen), findsOneWidget);
    });

    testWidgets('renders the profile when neither signal is set', (
      tester,
    ) async {
      await pumpRouter(tester);

      expect(find.byType(UserNotAvailableScreen), findsNothing);
      // OtherProfileScreen needs the full app provider graph, which this
      // test deliberately does not wire — the assertion above is about
      // which branch the router chose, so its build error is discarded.
      tester.takeException();
    });
  });
}
