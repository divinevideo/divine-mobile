// ABOUTME: Widget tests for SupporterScreen — rendering and status display.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iap_repository/iap_repository.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/supporter/supporter_cubit.dart';
import 'package:openvine/blocs/supporter/supporter_state.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/supporter_providers.dart';
import 'package:openvine/screens/settings/supporter_screen.dart';
import 'package:openvine/services/supporter_api_client.dart';
import 'package:openvine/services/supporter_repository.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../helpers/l10n.dart';
import '../../helpers/url_launcher_test_double.dart';

/// A minimal fake repository exposing the surface the screen reads.
class _FakeRepository extends Fake implements SupporterRepository {
  _FakeRepository(
    this._controller, {
    this.initial = SupporterEntitlement.inactive,
    this.accountSnapshot,
    List<SupporterTier> tiers = const [],
  }) : validator = _EmptyValidator(tiers: tiers);

  final StreamController<SupporterEntitlement> _controller;
  final SupporterEntitlement initial;
  Completer<SupporterEntitlement>? purchaseCompleter;
  SupporterAccountSnapshot? accountSnapshot;
  bool? savedHalo;
  @override
  Future<SupporterAccountSnapshot> updateRecognition({
    required bool haloVisible,
    required bool discoveryVisible,
    required bool foundingHistoryVisible,
  }) async {
    savedHalo = haloVisible;
    return accountSnapshot = SupporterAccountSnapshot(
      entitlement: initial,
      status: SupporterServerStatus.active,
      haloVisible: haloVisible,
      discoveryVisible: discoveryVisible,
      foundingHistoryVisible: foundingHistoryVisible,
    );
  }

  @override
  SupporterEntitlement get current => initial;

  @override
  bool get hasServerClient => false;

  @override
  SupporterAccountSnapshot? get snapshot => accountSnapshot;

  @override
  Stream<SupporterEntitlement> get changes => _controller.stream;

  @override
  Future<SupporterEntitlement> purchase(String productId) =>
      purchaseCompleter?.future ?? validator.purchase(productId);

  @override
  Future<SupporterEntitlement> restorePurchases() =>
      validator.restorePurchases();

  @override
  final EntitlementValidator validator;
}

class _EmptyValidator extends Fake implements EntitlementValidator {
  _EmptyValidator({this.tiers = const []});

  final List<SupporterTier> tiers;

  @override
  void startListening() {}

  @override
  Future<bool> get isAvailable async => false;

  @override
  Future<List<SupporterTier>> fetchProducts() async => tiers;

  @override
  Future<SupporterEntitlement> purchase(
    String productId, {
    String? capturedPubkey,
    String? attemptId,
  }) async => SupporterEntitlement.inactive;

  @override
  Future<SupporterEntitlement> restorePurchases({
    String? capturedPubkey,
    String? attemptId,
    bool silent = false,
  }) async => SupporterEntitlement.inactive;

  @override
  Stream<SupporterEntitlement> get entitlementChanges =>
      const Stream<SupporterEntitlement>.empty();

  @override
  Stream<EntitlementLifecycle> get lifecycleChanges => const Stream.empty();

  @override
  Stream<SupporterPurchaseProof> get purchaseProofChanges =>
      const Stream.empty();

  @override
  Future<void> completePurchase(SupporterPurchaseProof proof) async {}
}

/// Whether the pumped build is offered store checkout; production derives it
/// from the install source, which these tests do not resolve.
Override _storeBilling({bool available = true}) =>
    supporterStoreBillingAvailableProvider.overrideWithValue(available);

void main() {
  group('checkout feedback', () {
    const tier = SupporterTier(
      productId: 'divine.supporter.monthly',
      title: 'Monthly Supporter',
      price: r'$6.99',
      billingPeriod: SupporterBillingPeriod.monthly,
    );

    testWidgets('shows progress immediately while checkout is starting', (
      tester,
    ) async {
      final controller = StreamController<SupporterEntitlement>.broadcast();
      addTearDown(controller.close);
      final purchase = Completer<SupporterEntitlement>();
      final repo = _FakeRepository(controller, tiers: const [tier])
        ..purchaseCompleter = purchase;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _storeBilling(),
            supporterRepositoryProvider.overrideWithValue(repo),
          ],
          child: buildLocalizedWidget(const SupporterScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.tap(find.textContaining('Monthly Supporter'));
      await tester.pump();

      expect(find.text(l10n.supporterPreparingCheckout), findsOneWidget);
      expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('Monthly Supporter'), findsOneWidget);
      final tierButton = tester.widget<DivineButton>(
        find.ancestor(
          of: find.textContaining('Monthly Supporter'),
          matching: find.byType(DivineButton),
        ),
      );
      expect(tierButton.onPressed, isNull);
      final restore = tester.widget<DivineButton>(
        find.widgetWithText(DivineButton, l10n.supporterRestorePurchases),
      );
      expect(restore.onPressed, isNull);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text(l10n.supporterPreparingCheckout), findsOneWidget);

      purchase.complete(SupporterEntitlement.inactive);
      await tester.pumpAndSettle();
      expect(find.text(l10n.supporterPreparingCheckout), findsNothing);
      expect(find.text(l10n.supporterPurchaseConfirming), findsOneWidget);

      controller.add(
        const SupporterEntitlement(
          productId: 'divine.supporter.monthly',
          source: EntitlementSource.server,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(l10n.supporterActiveBadge), findsOneWidget);
      expect(find.text(l10n.supporterPurchaseConfirming), findsNothing);
    });

    testWidgets('returns to purchase options when checkout is cancelled', (
      tester,
    ) async {
      final controller = StreamController<SupporterEntitlement>.broadcast();
      addTearDown(controller.close);
      final purchase = Completer<SupporterEntitlement>();
      final repo = _FakeRepository(controller, tiers: const [tier])
        ..purchaseCompleter = purchase;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _storeBilling(),
            supporterRepositoryProvider.overrideWithValue(repo),
          ],
          child: buildLocalizedWidget(const SupporterScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.textContaining('Monthly Supporter'));
      await tester.pump();
      expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);

      purchase.completeError(
        const PurchaseFailedException('cancelled', 'Purchase cancelled'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DivineCircularProgressIndicator), findsNothing);
      expect(find.text(l10n.supporterPreparingCheckout), findsNothing);
      final button = tester.widget<DivineButton>(
        find.ancestor(
          of: find.textContaining('Monthly Supporter'),
          matching: find.byType(DivineButton),
        ),
      );
      expect(button.onPressed, isNotNull);
      expect(
        find.textContaining(l10n.supporterErrorPurchaseFailed),
        findsOneWidget,
      );
    });

    testWidgets(
      'returns to purchase options when checkout fails unexpectedly',
      (
        tester,
      ) async {
        final controller = StreamController<SupporterEntitlement>.broadcast();
        addTearDown(controller.close);
        final purchase = Completer<SupporterEntitlement>();
        final repo = _FakeRepository(controller, tiers: const [tier])
          ..purchaseCompleter = purchase;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _storeBilling(),
              supporterRepositoryProvider.overrideWithValue(repo),
            ],
            child: buildLocalizedWidget(const SupporterScreen()),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.textContaining('Monthly Supporter'));
        await tester.pump();
        expect(find.text(l10n.supporterPreparingCheckout), findsOneWidget);

        purchase.completeError(StateError('store channel closed'));
        await tester.pumpAndSettle();

        expect(find.byType(DivineCircularProgressIndicator), findsNothing);
        expect(find.text(l10n.supporterPreparingCheckout), findsNothing);
        final button = tester.widget<DivineButton>(
          find.ancestor(
            of: find.textContaining('Monthly Supporter'),
            matching: find.byType(DivineButton),
          ),
        );
        expect(button.onPressed, isNotNull);
        final restore = tester.widget<DivineButton>(
          find.widgetWithText(DivineButton, l10n.supporterRestorePurchases),
        );
        expect(restore.onPressed, isNotNull);
        expect(find.textContaining(l10n.supporterErrorUnknown), findsOneWidget);
      },
    );
  });

  group('recognition interactions', () {
    testWidgets('thanks a newly confirmed purchase immediately', (
      tester,
    ) async {
      final controller = StreamController<SupporterEntitlement>.broadcast();
      addTearDown(controller.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _storeBilling(),
            supporterRepositoryProvider.overrideWithValue(
              _FakeRepository(controller),
            ),
          ],
          child: buildLocalizedWidget(const SupporterScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining("You're a Divine Supporter"), findsNothing);
      controller.add(
        const SupporterEntitlement(
          productId: 'divine.supporter.monthly',
          source: EntitlementSource.server,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining("You're a Divine Supporter"), findsOneWidget);
      expect(find.text('Explore verification'), findsOneWidget);
    });

    testWidgets('saves public badge opt-in without changing other consent', (
      tester,
    ) async {
      final controller = StreamController<SupporterEntitlement>.broadcast();
      addTearDown(controller.close);
      final repo = _FakeRepository(
        controller,
        initial: const SupporterEntitlement(
          productId: 'divine.supporter.monthly',
          source: EntitlementSource.server,
        ),
        accountSnapshot: const SupporterAccountSnapshot(
          entitlement: SupporterEntitlement(
            productId: 'divine.supporter.monthly',
            source: EntitlementSource.server,
          ),
          status: SupporterServerStatus.active,
          discoveryVisible: true,
          foundingHistoryVisible: true,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _storeBilling(),
            supporterRepositoryProvider.overrideWithValue(repo),
          ],
          child: buildLocalizedWidget(const SupporterScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show my Supporter badge publicly'));
      await tester.pumpAndSettle();
      expect(repo.savedHalo, isTrue);
      expect(repo.snapshot?.haloVisible, isTrue);
      expect(repo.snapshot?.discoveryVisible, isTrue);
      expect(repo.snapshot?.foundingHistoryVisible, isTrue);
      await tester.tap(find.text('Show my Supporter badge publicly'));
      await tester.pumpAndSettle();
      expect(repo.snapshot?.haloVisible, isFalse);
      expect(find.textContaining("You're a Divine Supporter"), findsOneWidget);
    });
  });

  group('renders', () {
    testWidgets('renders hero copy and restore button when not a supporter', (
      tester,
    ) async {
      final controller = StreamController<SupporterEntitlement>.broadcast();
      addTearDown(controller.close);
      final repo = _FakeRepository(controller);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _storeBilling(),
            supporterRepositoryProvider.overrideWithValue(repo),
          ],
          child: buildLocalizedWidget(const SupporterScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Keep Divine running'), findsOneWidget);
      expect(find.text('Restore purchases'), findsOneWidget);
      expect(
        find.text('Become a supporter to apply for verification'),
        findsOneWidget,
      );
    });

    testWidgets('shows active badge when entitlement is active', (
      tester,
    ) async {
      final controller = StreamController<SupporterEntitlement>.broadcast();
      addTearDown(controller.close);
      final repo = _FakeRepository(
        controller,
        initial: SupporterEntitlement(
          productId: 'divine.supporter.monthly',
          source: EntitlementSource.appStore,
          purchaseDate: DateTime.utc(2030),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _storeBilling(),
            supporterRepositoryProvider.overrideWithValue(repo),
          ],
          child: buildLocalizedWidget(const SupporterScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining("You're a Divine Supporter"), findsOneWidget);
      expect(find.text('Show my Supporter badge publicly'), findsOneWidget);
      expect(find.text('Explore verification'), findsOneWidget);
    });

    testWidgets('shows unavailable note when store has no tiers', (
      tester,
    ) async {
      final controller = StreamController<SupporterEntitlement>.broadcast();
      addTearDown(controller.close);
      final repo = _FakeRepository(controller);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _storeBilling(),
            supporterRepositoryProvider.overrideWithValue(repo),
          ],
          child: buildLocalizedWidget(const SupporterScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('not available here right now'),
        findsOneWidget,
      );
    });

    testWidgets(
      'replaces plans and restore with a note on a build no store bills',
      (tester) async {
        final controller = StreamController<SupporterEntitlement>.broadcast();
        addTearDown(controller.close);
        final repo = _FakeRepository(
          controller,
          tiers: const [
            SupporterTier(
              productId: 'divine.supporter.monthly',
              title: 'Monthly Supporter',
              price: r'$6.99',
              billingPeriod: SupporterBillingPeriod.monthly,
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _storeBilling(available: false),
              supporterRepositoryProvider.overrideWithValue(repo),
            ],
            child: buildLocalizedWidget(const SupporterScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.supporterStoreNotInThisBuild), findsOneWidget);
        expect(find.textContaining('Monthly Supporter'), findsNothing);
        expect(find.text(l10n.supporterRestorePurchases), findsNothing);
        expect(find.text(l10n.supporterUnavailable), findsNothing);
        expect(
          find.text(
            lookupAppLocalizations(
              const Locale('de'),
            ).supporterStoreNotInThisBuild,
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'still shows an active membership on a build no store bills',
      (tester) async {
        final controller = StreamController<SupporterEntitlement>.broadcast();
        addTearDown(controller.close);
        final repo = _FakeRepository(
          controller,
          initial: const SupporterEntitlement(
            productId: 'divine.supporter.monthly',
            source: EntitlementSource.server,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _storeBilling(available: false),
              supporterRepositoryProvider.overrideWithValue(repo),
            ],
            child: buildLocalizedWidget(const SupporterScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.textContaining(l10n.supporterActiveBadge), findsOneWidget);
        expect(find.text(l10n.supporterStoreNotInThisBuild), findsNothing);
        expect(find.text(l10n.supporterPublicRecognition), findsOneWidget);
      },
    );

    testWidgets('labels each tier with its own billing period', (tester) async {
      final controller = StreamController<SupporterEntitlement>.broadcast();
      addTearDown(controller.close);
      final repo = _FakeRepository(
        controller,
        tiers: const [
          SupporterTier(
            productId: 'divine.supporter.monthly',
            title: 'Monthly Supporter',
            price: r'$6.99',
            billingPeriod: SupporterBillingPeriod.monthly,
          ),
          SupporterTier(
            productId: 'divine.supporter.annual',
            title: 'Annual Supporter',
            price: r'$69.99',
            billingPeriod: SupporterBillingPeriod.annual,
          ),
          SupporterTier(
            productId: 'divine.supporter.unknown',
            title: 'Mystery Supporter',
            price: r'$1.00',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _storeBilling(),
            supporterRepositoryProvider.overrideWithValue(repo),
          ],
          child: buildLocalizedWidget(const SupporterScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.text(
          l10n.supporterTierMonthlyLabel('Monthly Supporter', r'$6.99'),
        ),
        findsOneWidget,
      );
      expect(
        find.text(l10n.supporterTierAnnualLabel('Annual Supporter', r'$69.99')),
        findsOneWidget,
      );
      expect(
        find.text(l10n.supporterTierLabel('Mystery Supporter', r'$1.00')),
        findsOneWidget,
      );
      expect(find.textContaining('/ month'), findsOneWidget);
    });

    testWidgets('renders failure banner for an error state', (tester) async {
      final controller = StreamController<SupporterEntitlement>.broadcast();
      addTearDown(controller.close);
      late SupporterCubit cubit;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _storeBilling(),
            supporterRepositoryProvider.overrideWithValue(
              _FakeRepository(controller),
            ),
          ],
          child: buildLocalizedWidget(
            BlocProvider<SupporterCubit>(
              create: (_) {
                return cubit = SupporterCubit(
                  repository: _FakeRepository(controller),
                );
              },
              child: const SupporterScreenView(),
            ),
          ),
        ),
      );
      // Let start() + loadTiers() settle to idle, then surface a failure.
      await tester.pumpAndSettle();
      cubit.emit(
        const SupporterState(failure: SupporterFailure.purchaseFailed),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('did not complete'), findsOneWidget);
    });
  });

  group('subscription terms', () {
    const tier = SupporterTier(
      productId: 'divine.supporter.monthly',
      title: 'Monthly Supporter',
      price: r'$6.99',
      billingPeriod: SupporterBillingPeriod.monthly,
    );
    final l10n = lookupAppLocalizations(const Locale('en'));

    late UrlLauncherTestDouble launcher;

    setUp(() {
      final original = UrlLauncherPlatform.instance;
      launcher = UrlLauncherTestDouble();
      UrlLauncherPlatform.instance = launcher;
      addTearDown(() => UrlLauncherPlatform.instance = original);
    });

    Future<void> pumpScreen(
      WidgetTester tester, {
      List<SupporterTier> tiers = const [tier],
      SupporterEntitlement initial = SupporterEntitlement.inactive,
    }) async {
      final controller = StreamController<SupporterEntitlement>.broadcast();
      addTearDown(controller.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supporterRepositoryProvider.overrideWithValue(
              _FakeRepository(controller, tiers: tiers, initial: initial),
            ),
          ],
          child: buildLocalizedWidget(const SupporterScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tapLink(WidgetTester tester, String label) async {
      final link = find.widgetWithText(DivineButton, label);
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      await tester.tap(link);
      await tester.pumpAndSettle();
    }

    testWidgets('shows renewal notice and legal links beside the plans', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await pumpScreen(tester);

      expect(
        find.text(l10n.supporterAutoRenewNoticeGooglePlay),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(DivineButton, l10n.supporterTermsOfUse),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(DivineButton, l10n.legalPrivacyPolicy),
        findsOneWidget,
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('names only the App Store on iOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await pumpScreen(tester);

      expect(find.text(l10n.supporterAutoRenewNoticeAppStore), findsOneWidget);
      expect(find.textContaining('Google Play'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('hides renewal notice when no plans are offered', (
      tester,
    ) async {
      await pumpScreen(tester, tiers: const []);

      expect(find.text(l10n.supporterAutoRenewNoticeGooglePlay), findsNothing);
      expect(find.text(l10n.supporterTermsOfUse), findsNothing);
    });

    testWidgets('hides renewal notice for an active supporter', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        initial: const SupporterEntitlement(
          productId: 'divine.supporter.monthly',
          source: EntitlementSource.server,
        ),
      );

      expect(find.text(l10n.supporterActiveBadge), findsOneWidget);
      expect(find.text(l10n.supporterAutoRenewNoticeGooglePlay), findsNothing);
    });

    testWidgets("opens Apple's standard EULA on iOS", (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await pumpScreen(tester);

      await tapLink(tester, l10n.supporterTermsOfUse);

      expect(
        launcher.launched.single.url,
        SupporterLegalLinks.appleStandardEula,
      );
      expect(launcher.launched.single.useExternalApplication, isTrue);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('opens Divine terms on Android', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await pumpScreen(tester);

      await tapLink(tester, l10n.supporterTermsOfUse);

      expect(launcher.launched.single.url, SupporterLegalLinks.divineTerms);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('opens the privacy policy', (tester) async {
      await pumpScreen(tester);

      await tapLink(tester, l10n.legalPrivacyPolicy);

      expect(launcher.launched.single.url, SupporterLegalLinks.privacyPolicy);
    });

    testWidgets('tells the user when a legal page cannot open', (
      tester,
    ) async {
      launcher = UrlLauncherTestDouble(launchResult: false);
      UrlLauncherPlatform.instance = launcher;
      await pumpScreen(tester);

      await tapLink(tester, l10n.legalPrivacyPolicy);

      expect(
        find.text(l10n.legalCouldNotOpenPage(l10n.legalPrivacyPolicy)),
        findsOneWidget,
      );
    });
  });
}
