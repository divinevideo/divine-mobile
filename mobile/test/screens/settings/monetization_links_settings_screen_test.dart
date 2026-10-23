// ABOUTME: Widget regressions for raw metadata gating in support-link settings.
// ABOUTME: Covers drafts, account/repository changes, and storefront preservation.

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/monetization/monetization_storefront_policy.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/settings/monetization_links_settings_screen.dart';
import 'package:openvine/services/auth/account_activation_coordinator.dart';
import 'package:openvine/services/auth_service.dart'
    show AuthService, AuthState;
import 'package:profile_repository/profile_repository.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockActivationReceipt extends Mock implements AccountActivationReceipt {}

const _pubkey =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
const _links = [
  MonetizationLink(
    provider: MonetizationLinkProvider.cashApp,
    category: MonetizationLinkCategory.tip,
    url: r'https://cash.app/$old',
    enabled: true,
  ),
  MonetizationLink(
    provider: MonetizationLinkProvider.patreon,
    category: MonetizationLinkCategory.subscription,
    url: 'https://www.patreon.com/creator',
    enabled: true,
  ),
];

UserProfile _profile({
  String pubkey = _pubkey,
  String eventId =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  List<MonetizationLink> links = const [],
}) => UserProfile(
  pubkey: pubkey,
  displayName: 'Creator',
  rawData: {
    'display_name': 'Creator',
    if (links.isNotEmpty)
      divineMonetizationLinksKey: [for (final link in links) link.toJson()],
  },
  createdAt: DateTime(2026),
  eventId: eventId,
);

_MockAuthService _auth({String? pubkey = _pubkey}) {
  final auth = _MockAuthService();
  when(() => auth.currentPublicKeyHex).thenReturn(pubkey);
  return auth;
}

Widget _app({
  required ProfileRepository repository,
  required AuthService auth,
  AccountActivationReceipt? receipt,
}) => ProviderScope(
  overrides: [
    authServiceProvider.overrideWithValue(auth),
    currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
    currentAccountActivationReceiptProvider.overrideWithValue(receipt),
    profileRepositoryProvider.overrideWithValue(repository),
    profileReadRepositoryProvider.overrideWithValue(repository),
    analyticsEventSinkProvider.overrideWithValue(
      const NoOpAnalyticsEventSink(),
    ),
  ],
  child: MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: VineTheme.theme,
    home: const MonetizationLinksSettingsScreen(),
  ),
);

void _stubRead(
  _MockProfileRepository repository,
  UserProfile? profile, {
  String pubkey = _pubkey,
}) {
  when(
    () => repository.fetchFreshProfile(
      pubkey: pubkey,
      requireRawKind0: true,
    ),
  ).thenAnswer((_) async => profile);
}

Future<void> _mount(
  WidgetTester tester, {
  required ProfileRepository repository,
  required AuthService auth,
  AccountActivationReceipt? receipt,
}) async {
  await tester.pumpWidget(
    _app(repository: repository, auth: auth, receipt: receipt),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  setUpAll(() {
    registerFallbackValue(_profile());
    registerFallbackValue(<MonetizationLink>[]);
  });
  tearDown(() => debugUsesAppleAppStoreTipPolicyOverride = null);

  group('raw metadata editor', () {
    for (final applePolicy in [true, false]) {
      testWidgets('REST-only cache cannot erase raw links '
          '(Apple policy: $applePolicy)', (tester) async {
        debugUsesAppleAppStoreTipPolicyOverride = applePolicy;
        final repository = _MockProfileRepository();
        final auth = _auth();
        final raw = Completer<UserProfile?>();
        // This is the production boundary: REST knows the profile identity,
        // but its projection carries no support-link metadata.
        when(() => repository.getCachedProfile(pubkey: _pubkey))
            .thenAnswer((_) async => _profile());
        when(() => repository.fetchFreshProfile(pubkey: _pubkey))
            .thenAnswer((_) async => _profile());
        when(() => repository.watchProfile(pubkey: _pubkey))
            .thenAnswer((_) => Stream.value(_profile()));
        when(
          () => repository.fetchFreshProfile(
            pubkey: _pubkey,
            requireRawKind0: true,
          ),
        ).thenAnswer((_) => raw.future);
        List<MonetizationLink>? published;
        when(
          () => repository.saveProfileEvent(
            displayName: any(named: 'displayName'),
            about: any(named: 'about'),
            website: any(named: 'website'),
            picture: any(named: 'picture'),
            banner: any(named: 'banner'),
            monetizationLinks: any(named: 'monetizationLinks'),
            currentProfile: any(named: 'currentProfile'),
          ),
        ).thenAnswer((invocation) async {
          published =
              (invocation.namedArguments[#monetizationLinks]
                      as Iterable<MonetizationLink>)
                  .toList();
          return _profile(links: published!);
        });
        await _mount(tester, repository: repository, auth: auth);
        expect(
          tester.widget<Switch>(find.byType(Switch).first).onChanged,
          isNull,
        );
        expect(
          tester.widget<DivineButton>(find.byType(DivineButton).last).onPressed,
          isNull,
        );
        expect(published, isNull);
        raw.complete(_profile(links: _links));
        await tester.pump();
        await tester.pump();
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          r'https://cash.app/$old',
        );
        await tester.enterText(find.byType(TextFormField).first, r'$updated');
        final save = applePolicy
            ? l10n.monetizationTipsSettingsSave
            : l10n.monetizationSettingsSave;
        await tester.ensureVisible(find.text(save));
        await tester.tap(find.text(save));
        await tester.pump();
        await tester.pump();
        expect(
          published,
          containsAll([
            const MonetizationLink(
              provider: MonetizationLinkProvider.cashApp,
              category: MonetizationLinkCategory.tip,
              url: r'https://cash.app/$updated',
              enabled: true,
            ),
            _links[1],
          ]),
        );
      });
    }

    testWidgets('failed raw load disables editing and offers safe retry', (
      tester,
    ) async {
      final repository = _MockProfileRepository();
      final auth = _auth();
      _stubRead(repository, null);
      await _mount(tester, repository: repository, auth: auth);
      expect(find.text(l10n.commonSomethingWentWrong), findsOneWidget);
      expect(
        tester.widget<Switch>(find.byType(Switch).first).onChanged,
        isNull,
      );
      expect(
        tester.widget<DivineButton>(find.byType(DivineButton).last).onPressed,
        isNull,
      );
      _stubRead(repository, _profile(links: _links));
      await tester.tap(find.text(l10n.commonRetry));
      await tester.pump();
      await tester.pump();
      expect(find.text(l10n.commonSomethingWentWrong), findsNothing);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        r'https://cash.app/$old',
      );
    });

    testWidgets('background profile updates preserve unsaved drafts', (
      tester,
    ) async {
      final repository = _MockProfileRepository();
      final auth = _auth();
      _stubRead(repository, _profile(links: _links));
      final updates = StreamController<UserProfile?>.broadcast();
      addTearDown(updates.close);
      when(() => repository.getCachedProfile(pubkey: _pubkey))
          .thenAnswer((_) async => _profile(links: _links));
      when(() => repository.watchProfile(pubkey: _pubkey))
          .thenAnswer((_) => updates.stream);
      await _mount(tester, repository: repository, auth: auth);
      await tester.enterText(find.byType(TextFormField).first, r'$draft');
      updates.add(_profile(eventId: 'b' * 64));
      final context = tester.element(
        find.byType(MonetizationLinksSettingsScreen),
      );
      ProviderScope.containerOf(context)
          .invalidate(userProfileReactiveProvider(_pubkey));
      await _mount(tester, repository: repository, auth: auth);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        r'$draft',
      );
    });

    for (final replaceAccount in [true, false]) {
      testWidgets('retires pending editor when '
          '${replaceAccount ? 'account' : 'repository'} changes', (
        tester,
      ) async {
        final oldRepository = _MockProfileRepository();
        final newRepository = replaceAccount
            ? oldRepository
            : _MockProfileRepository();
        final oldAuth = _auth();
        final newPubkey = replaceAccount ? 'b' * 64 : _pubkey;
        final newAuth = replaceAccount ? _auth(pubkey: newPubkey) : oldAuth;
        final oldRead = Completer<UserProfile?>();
        when(
          () => oldRepository.fetchFreshProfile(
            pubkey: _pubkey,
            requireRawKind0: true,
          ),
        ).thenAnswer((_) => oldRead.future);
        await _mount(tester, repository: oldRepository, auth: oldAuth);
        _stubRead(
          newRepository,
          _profile(pubkey: newPubkey),
          pubkey: newPubkey,
        );
        await _mount(tester, repository: newRepository, auth: newAuth);
        oldRead.complete(_profile(links: _links));
        await tester.pump();
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          isEmpty,
        );
        expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('account activation on the same auth service retires drafts', (
      tester,
    ) async {
      final repository = _MockProfileRepository();
      final auth = _auth();
      _stubRead(repository, _profile(links: _links));
      await _mount(tester, repository: repository, auth: auth);
      await tester.enterText(find.byType(TextFormField).first, r'$oldDraft');
      final newPubkey = 'b' * 64;
      when(() => auth.currentPublicKeyHex).thenReturn(newPubkey);
      _stubRead(repository, _profile(pubkey: newPubkey), pubkey: newPubkey);
      await _mount(
        tester,
        repository: repository,
        auth: auth,
        receipt: _MockActivationReceipt(),
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        isEmpty,
      );
    });

    testWidgets('storefront change retires drafts before changing providers', (
      tester,
    ) async {
      debugUsesAppleAppStoreTipPolicyOverride = false;
      final repository = _MockProfileRepository();
      final auth = _auth();
      _stubRead(repository, _profile(links: _links));
      await _mount(tester, repository: repository, auth: auth);
      await tester.enterText(find.byType(TextFormField).first, r'$draft');
      debugUsesAppleAppStoreTipPolicyOverride = true;
      await _mount(
        tester,
        repository: repository,
        auth: auth,
        receipt: _MockActivationReceipt(),
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        r'https://cash.app/$old',
      );
      expect(find.text('Patreon', skipOffstage: false), findsNothing);
    });

    testWidgets('Apple storefront displays only tip providers', (tester) async {
      debugUsesAppleAppStoreTipPolicyOverride = true;
      final repository = _MockProfileRepository();
      _stubRead(repository, _profile(links: _links));
      await _mount(tester, repository: repository, auth: _auth());
      expect(find.text(l10n.monetizationTipsSettingsTitle), findsOneWidget);
      expect(find.text('Cash App', skipOffstage: false), findsOneWidget);
      expect(find.text('Patreon', skipOffstage: false), findsNothing);
      expect(find.text('Substack', skipOffstage: false), findsNothing);
      expect(
        find.text(l10n.monetizationSettingsSubscriptionSection),
        findsNothing,
      );
    });
  });
}
