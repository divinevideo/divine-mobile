// ABOUTME: Widget tests for the post-publish crossposting prompt in each
// ABOUTME: crossposting state, and for the gate that decides it may load.

import 'package:analytics/analytics.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/post_publish/view/post_publish_crosspost.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/authentication_source.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/crossposting_providers.dart';
import 'package:openvine/repositories/crossposting_repository.dart';
import 'package:openvine/services/crossposting_api_client.dart';

class _MockCrosspostingRepository extends Mock
    implements CrosspostingRepository {}

class _RecordingSink implements AnalyticsEventSink {
  final events = <({String name, Map<String, Object> parameters})>[];

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    events.add((name: name, parameters: parameters));
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> setUserId(String? userId) async {}
}

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

const _instagramConnected = CrosspostingConnection(
  id: 'conn-instagram',
  platform: CrosspostingPlatform.instagram,
  status: CrosspostingConnectionStatus.connected,
);
const _instagramNeedsReauth = CrosspostingConnection(
  id: 'conn-instagram',
  platform: CrosspostingPlatform.instagram,
  status: CrosspostingConnectionStatus.needsReauth,
);

CrosspostingPlatformSettings _instagram({
  CrosspostingConnection? connection,
  CrosspostingMode mode = CrosspostingMode.disabled,
}) => CrosspostingPlatformSettings(
  platform: CrosspostingPlatform.instagram,
  supportsAutomatic: true,
  mode: mode,
  connection: connection,
);

void main() {
  group(PostPublishCrosspost, () {
    late _MockCrosspostingRepository repository;
    late _RecordingSink analytics;
    late List<List<CrosspostingConnection>> crossposted;
    late int setUps;
    late int reconnects;

    setUp(() {
      repository = _MockCrosspostingRepository();
      analytics = _RecordingSink();
      crossposted = [];
      setUps = 0;
      reconnects = 0;
    });

    Future<void> pump(
      WidgetTester tester, {
      required List<CrosspostingPlatformSettings> settings,
      ThemeData? theme,
    }) async {
      when(() => repository.loadSettings()).thenAnswer((_) async => settings);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            crosspostingRepositoryProvider.overrideWithValue(repository),
            analyticsEventSinkProvider.overrideWithValue(analytics),
          ],
          child: MaterialApp(
            theme: theme ?? VineTheme.theme,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: PostPublishCrosspost(
                onCrosspost: crossposted.add,
                onSetUp: () => setUps++,
                onReconnect: () => reconnects++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    group('renders', () {
      testWidgets('a crosspost suggestion for a manual-mode platform', (
        tester,
      ) async {
        await pump(
          tester,
          settings: [
            _instagram(
              connection: _instagramConnected,
              mode: CrosspostingMode.manual,
            ),
          ],
        );

        expect(
          find.text(_l10n.postPublishCrosspostSuggest('Instagram')),
          findsOneWidget,
        );
        expect(find.text(_l10n.crosspostSubmit), findsOneWidget);
      });

      testWidgets('the suggestion in the light appearance too', (
        tester,
      ) async {
        await pump(
          tester,
          theme: VineTheme.lightTheme,
          settings: [
            _instagram(
              connection: _instagramConnected,
              mode: CrosspostingMode.manual,
            ),
          ],
        );

        expect(
          find.text(_l10n.postPublishCrosspostSuggest('Instagram')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('a setup call to action when nothing is connected', (
        tester,
      ) async {
        await pump(tester, settings: [_instagram()]);

        expect(
          find.text(_l10n.postPublishCrosspostSetUp('Instagram')),
          findsOneWidget,
        );
        expect(
          find.text(_l10n.crosspostingBenefitConnect('Instagram')),
          findsOneWidget,
        );
      });

      testWidgets('only a note, with no call to action, in automatic mode', (
        tester,
      ) async {
        await pump(
          tester,
          settings: [
            _instagram(
              connection: _instagramConnected,
              mode: CrosspostingMode.automatic,
            ),
          ],
        );

        expect(
          find.text(_l10n.postPublishCrosspostAutomatic('Instagram')),
          findsOneWidget,
        );
        expect(find.byType(DivineButton), findsNothing);
      });

      testWidgets('a reconnect prompt when authorization lapsed', (
        tester,
      ) async {
        await pump(
          tester,
          settings: [
            _instagram(
              connection: _instagramNeedsReauth,
              mode: CrosspostingMode.manual,
            ),
          ],
        );

        expect(
          find.text(_l10n.crosspostReconnectPrompt('Instagram')),
          findsOneWidget,
        );
        expect(find.text(_l10n.crosspostReconnect), findsOneWidget);
      });

      testWidgets('nothing when no platform is available', (tester) async {
        await pump(tester, settings: []);

        expect(find.byType(DivineInfoCard), findsNothing);
      });
    });

    group('interactions', () {
      testWidgets('crosspost opens the flow with the manual connections', (
        tester,
      ) async {
        await pump(
          tester,
          settings: [
            _instagram(
              connection: _instagramConnected,
              mode: CrosspostingMode.manual,
            ),
          ],
        );

        await tester.tap(find.text(_l10n.crosspostSubmit));
        await tester.pump();

        expect(
          crossposted,
          equals([
            [_instagramConnected],
          ]),
        );
        expect(
          analytics.events.map((event) => event.name),
          equals(['crosspost_cta_shown', 'crosspost_cta_tapped']),
        );
        expect(
          analytics.events.last.parameters,
          equals({'surface': 'post_publish', 'cta': 'crosspost_video'}),
        );
      });

      testWidgets('connect opens crossposting setup', (tester) async {
        await pump(tester, settings: [_instagram()]);

        await tester.tap(
          find.text(_l10n.crosspostingBenefitConnect('Instagram')),
        );
        await tester.pump();

        expect(setUps, equals(1));
        expect(reconnects, equals(0));
      });

      testWidgets('reconnect opens the reconnect route', (tester) async {
        await pump(
          tester,
          settings: [
            _instagram(
              connection: _instagramNeedsReauth,
              mode: CrosspostingMode.manual,
            ),
          ],
        );

        await tester.tap(find.text(_l10n.crosspostReconnect));
        await tester.pump();

        expect(reconnects, equals(1));
        expect(setUps, equals(0));
      });
    });
  });

  group('shouldOfferPostPublishCrosspost', () {
    test('offers for a silent signer when crossposting is available', () {
      for (final availability in [
        CrosspostingAvailability.native,
        CrosspostingAvailability.webOnly,
      ]) {
        for (final source in [
          AuthenticationSource.divineOAuth,
          AuthenticationSource.importedKeys,
          AuthenticationSource.automatic,
        ]) {
          expect(
            shouldOfferPostPublishCrosspost(
              availability: availability,
              source: source,
            ),
            isTrue,
            reason: '$availability / $source',
          );
        }
      }
    });

    test('never offers to an ineligible account', () {
      expect(
        shouldOfferPostPublishCrosspost(
          availability: CrosspostingAvailability.unavailable,
          source: AuthenticationSource.divineOAuth,
        ),
        isFalse,
      );
    });

    test('never signs unprompted through a signer that may ask the user', () {
      for (final source in [
        AuthenticationSource.amber,
        AuthenticationSource.bunker,
        AuthenticationSource.nip07,
        AuthenticationSource.none,
      ]) {
        expect(
          shouldOfferPostPublishCrosspost(
            availability: CrosspostingAvailability.native,
            source: source,
          ),
          isFalse,
          reason: '$source',
        );
      }
    });
  });
}
