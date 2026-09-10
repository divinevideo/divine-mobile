// ABOUTME: Widget tests for NostrConnectScreen.
// ABOUTME: Route constants plus the skeleton-loading vs real-QR state contract.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/auth/nostr_connect_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockAuthService extends Mock implements AuthService {}

/// The [GestureDetector] wrapping the action-bar button labelled [label].
/// `onTap` is `null` while the session is loading, so this reads the fix that
/// keeps the button inert to both touch and screen readers.
GestureDetector _actionButton(WidgetTester tester, String label) {
  return tester.widget<GestureDetector>(
    find
        .ancestor(of: find.text(label), matching: find.byType(GestureDetector))
        .first,
  );
}

void main() {
  group('NostrConnectScreen route constants', () {
    test('has correct path', () {
      expect(NostrConnectScreen.path, equals('/nostr-connect'));
    });

    test('has correct route name', () {
      expect(NostrConnectScreen.routeName, equals('nostr-connect'));
    });
  });

  group('NostrConnectScreen loading contract', () {
    late _MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = _MockAuthService();
      // dispose() reads this before deciding whether to cancel the session.
      when(
        () => mockAuthService.isNostrConnectCallbackHandoffActive,
      ).thenReturn(false);
    });

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          ...getStandardTestOverrides(mockAuthService: mockAuthService),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          routerConfig: GoRouter(
            initialLocation: NostrConnectScreen.path,
            routes: [
              GoRoute(path: '/', builder: (_, _) => const Scaffold()),
              GoRoute(
                path: NostrConnectScreen.path,
                builder: (_, _) => const NostrConnectScreen(),
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('generating state skeletonizes and omits the real QR encoder', (
      tester,
    ) async {
      when(() => mockAuthService.nostrConnectUrl).thenReturn(null);
      when(() => mockAuthService.nostrConnectState).thenReturn(null);
      // Never resolves, so the screen stays in the generating state.
      when(
        () => mockAuthService.initiateNostrConnect(),
      ).thenAnswer((_) => Completer<NostrConnectSession>().future);

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));

      // Skeleton.replace must swap the QR out entirely — otherwise the
      // encoder would run over the empty placeholder payload.
      expect(find.byType(QrImageView), findsNothing);
      expect(
        tester.widget<Skeletonizer>(find.bySubtype<Skeletonizer>()).enabled,
        isTrue,
      );
      expect(find.text(l10n.authGeneratingConnection), findsOneWidget);

      // The action bar is inert: skeletonizer's ignorePointers stops touch,
      // and the null callbacks stop screen-reader taps.
      expect(_actionButton(tester, l10n.authCopyUrl).onTap, isNull);
      expect(_actionButton(tester, l10n.authShare).onTap, isNull);
      expect(_actionButton(tester, l10n.authAddBunker).onTap, isNull);

      // Unmount to run dispose() and cancel any pending timers.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('listening state renders the real QR and a live action bar', (
      tester,
    ) async {
      const connectUrl =
          'nostrconnect://abc123?relay=wss://relay.example.com&secret=xyz';
      when(() => mockAuthService.nostrConnectUrl).thenReturn(connectUrl);
      when(
        () => mockAuthService.nostrConnectState,
      ).thenReturn(NostrConnectState.listening);
      // Never resolves, so the screen stays in the listening state.
      when(
        () => mockAuthService.waitForNostrConnectResponse(),
      ).thenAnswer((_) => Completer<AuthResult>().future);

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));

      // Skeleton.replace is off, so the real QR encoder is built (not the
      // shimmer placeholder shown while generating).
      expect(find.byType(QrImageView), findsOneWidget);
      expect(
        tester.widget<Skeletonizer>(find.bySubtype<Skeletonizer>()).enabled,
        isFalse,
      );
      // The action bar is live again once loaded.
      expect(_actionButton(tester, l10n.authCopyUrl).onTap, isNotNull);
      expect(_actionButton(tester, l10n.authAddBunker).onTap, isNotNull);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('does not render bunker service exception text on failure', (
      tester,
    ) async {
      const connectUrl =
          'nostrconnect://abc123?relay=wss://relay.example.com&secret=xyz';
      const bunkerUrl =
          'bunker://aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
          '?relay=wss://relay.example.com';
      const serviceError =
          'Bunker connection failed: SocketException(secret details)';
      when(() => mockAuthService.nostrConnectUrl).thenReturn(connectUrl);
      when(
        () => mockAuthService.nostrConnectState,
      ).thenReturn(NostrConnectState.listening);
      when(
        () => mockAuthService.waitForNostrConnectResponse(),
      ).thenAnswer((_) => Completer<AuthResult>().future);
      when(() => mockAuthService.cancelNostrConnect()).thenReturn(null);
      when(
        () => mockAuthService.connectWithBunker(bunkerUrl),
      ).thenAnswer((_) async => AuthResult.failure(serviceError));

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.ensureVisible(find.text(l10n.authAddBunker));
      await tester.tap(find.text(l10n.authAddBunker));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(find.byType(TextField), bunkerUrl);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(l10n.authFailedToConnect), findsOneWidget);
      expect(find.text(serviceError), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('connected state stays skeletonized with an inert action bar', (
      tester,
    ) async {
      const connectUrl =
          'nostrconnect://abc123?relay=wss://relay.example.com&secret=xyz';
      when(() => mockAuthService.nostrConnectUrl).thenReturn(connectUrl);
      when(
        () => mockAuthService.nostrConnectState,
      ).thenReturn(NostrConnectState.listening);
      // Resume subscribes to this stream; emitting `connected` drives the
      // screen into the authenticating branch this PR converted.
      when(() => mockAuthService.nostrConnectStateStream).thenAnswer(
        (_) => Stream<NostrConnectState>.value(NostrConnectState.connected),
      );
      when(
        () => mockAuthService.waitForNostrConnectResponse(),
      ).thenAnswer((_) => Completer<AuthResult>().future);

      await tester.pumpWidget(createTestWidget());
      await tester.pump(); // resume -> listening
      await tester.pump(); // stream emits connected -> rebuild
      await tester.pump(const Duration(seconds: 1)); // finish skeleton switch

      final l10n = lookupAppLocalizations(const Locale('en'));

      // The authenticating branch must keep isLoading: true — otherwise the
      // screen paints a live QR (and a tappable action bar) for a session that
      // has already been consumed.
      expect(find.text(l10n.authConnectedAuthenticating), findsOneWidget);
      expect(
        tester.widget<Skeletonizer>(find.bySubtype<Skeletonizer>()).enabled,
        isTrue,
      );
      expect(find.byType(QrImageView), findsNothing);
      // The dangerous one: a screen-reader tap here runs cancelNostrConnect().
      expect(_actionButton(tester, l10n.authAddBunker).onTap, isNull);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('chrome does not shift between loading and loaded', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final header = find.text(l10n.authCompatibleSignerApps);

      // Generating (loading): record the compatibility header offset.
      when(() => mockAuthService.nostrConnectUrl).thenReturn(null);
      when(() => mockAuthService.nostrConnectState).thenReturn(null);
      when(
        () => mockAuthService.initiateNostrConnect(),
      ).thenAnswer((_) => Completer<NostrConnectSession>().future);
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      final loadingOffset = tester.getTopLeft(header);
      await tester.pumpWidget(const SizedBox());

      // Listening (loaded): the same header must sit at the same offset —
      // the whole point of reusing one layout instead of two.
      when(() => mockAuthService.nostrConnectUrl).thenReturn(
        'nostrconnect://abc123?relay=wss://relay.example.com&secret=xyz',
      );
      when(
        () => mockAuthService.nostrConnectState,
      ).thenReturn(NostrConnectState.listening);
      when(
        () => mockAuthService.waitForNostrConnectResponse(),
      ).thenAnswer((_) => Completer<AuthResult>().future);
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      final loadedOffset = tester.getTopLeft(header);

      expect(loadedOffset, loadingOffset);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
