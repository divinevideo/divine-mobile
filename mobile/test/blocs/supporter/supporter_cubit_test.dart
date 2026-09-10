// ABOUTME: Tests for SupporterCubit — tier loading, subscribe, restore, failures.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iap_repository/iap_repository.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/supporter/supporter_cubit.dart';
import 'package:openvine/blocs/supporter/supporter_state.dart';
import 'package:openvine/services/supporter_api_client.dart';
import 'package:openvine/services/supporter_repository.dart';

class _FakeRepository extends Fake implements SupporterRepository {
  _FakeRepository(this._controller);

  final StreamController<SupporterEntitlement> _controller;

  /// Typed validator so tests can configure fakes directly.
  @override
  final _FakeValidator validator = _FakeValidator();

  @override
  SupporterEntitlement get current => SupporterEntitlement.inactive;

  @override
  bool get hasServerClient => false;

  Object? purchaseError;
  Completer<SupporterEntitlement>? purchaseCompleter;

  @override
  Stream<SupporterEntitlement> get changes => _controller.stream;

  @override
  Future<SupporterEntitlement> purchase(String productId) async {
    if (purchaseError != null) throw purchaseError!;
    return purchaseCompleter?.future ?? validator.purchase(productId);
  }

  @override
  Future<SupporterEntitlement> restorePurchases() =>
      validator.restorePurchases();
}

class _FakeValidator extends Fake implements EntitlementValidator {
  List<SupporterTier> products = const [];
  Completer<List<SupporterTier>>? fetchCompleter;
  Object? fetchError;
  Object? purchaseError;
  SupporterEntitlement purchaseResult = SupporterEntitlement.inactive;
  Object? restoreError;
  Stream<EntitlementLifecycle> lifecycleStream = const Stream.empty();

  @override
  void startListening() {}

  @override
  Stream<EntitlementLifecycle> get lifecycleChanges => lifecycleStream;

  @override
  Future<List<SupporterTier>> fetchProducts() async {
    if (fetchError != null) throw fetchError!;
    if (fetchCompleter != null) return fetchCompleter!.future;
    return products;
  }

  @override
  Future<SupporterEntitlement> purchase(
    String productId, {
    String? capturedPubkey,
    String? attemptId,
  }) async {
    if (purchaseError != null) throw purchaseError!;
    return purchaseResult;
  }

  @override
  Future<SupporterEntitlement> restorePurchases({
    String? capturedPubkey,
    String? attemptId,
    bool silent = false,
  }) async {
    if (restoreError != null) throw restoreError!;
    return SupporterEntitlement.inactive;
  }

  @override
  Stream<SupporterPurchaseProof> get purchaseProofChanges =>
      const Stream.empty();

  @override
  Future<void> completePurchase(SupporterPurchaseProof proof) async {}
}

void main() {
  late StreamController<SupporterEntitlement> controller;

  setUp(() {
    controller = StreamController<SupporterEntitlement>.broadcast();
  });

  tearDown(() => controller.close());

  group('loadTiers', () {
    blocTest<SupporterCubit, SupporterState>(
      'loadTiers emits loading then tiers',
      build: () {
        final repo = _FakeRepository(controller);
        repo.validator.products = [
          const SupporterTier(
            productId: 'divine.supporter.monthly',
            title: 'Supporter',
            price: r'$4.99',
          ),
        ];
        return SupporterCubit(repository: repo);
      },
      act: (cubit) => cubit.loadTiers(),
      expect: () => [
        isA<SupporterState>().having(
          (s) => s.status,
          'status',
          SupporterStatus.loading,
        ),
        isA<SupporterState>()
            .having((s) => s.tiers, 'tiers', hasLength(1))
            .having((s) => s.status, 'status', SupporterStatus.idle),
      ],
    );

    blocTest<SupporterCubit, SupporterState>(
      'loadTiers maps StoreUnavailableException to failure',
      build: () {
        final repo = _FakeRepository(controller);
        repo.validator.products = [];
        repo.validator.fetchError = const StoreUnavailableException();
        return SupporterCubit(repository: repo);
      },
      act: (cubit) => cubit.loadTiers(),
      skip: 1,
      expect: () => [
        isA<SupporterState>()
            .having((s) => s.status, 'status', SupporterStatus.error)
            .having(
              (s) => s.failure,
              'failure',
              SupporterFailure.storeUnavailable,
            ),
      ],
    );
  });

  group('subscribe', () {
    blocTest<SupporterCubit, SupporterState>(
      'maps unavailable verification to a non-busy error',
      build: () {
        final repo = _FakeRepository(controller)
          ..purchaseError = const SupporterApiException(
            SupporterApiFailureKind.unavailable,
            'Supporter verification is not configured.',
          );
        return SupporterCubit(repository: repo);
      },
      act: (cubit) => cubit.subscribe('divine.supporter.monthly'),
      expect: () => [
        isA<SupporterState>().having(
          (s) => s.status,
          'status',
          SupporterStatus.purchasing,
        ),
        isA<SupporterState>()
            .having((s) => s.status, 'status', SupporterStatus.error)
            .having(
              (s) => s.failure,
              'failure',
              SupporterFailure.verificationUnavailable,
            )
            .having((s) => s.isBusy, 'isBusy', isFalse),
      ],
    );

    blocTest<SupporterCubit, SupporterState>(
      'subscribe emits purchasing then active on success',
      build: () {
        final repo = _FakeRepository(controller);
        repo.validator.purchaseResult = SupporterEntitlement(
          productId: 'divine.supporter.monthly',
          source: EntitlementSource.appStore,
          purchaseDate: DateTime.utc(2030),
        );
        return SupporterCubit(repository: repo);
      },
      act: (cubit) => cubit.subscribe('divine.supporter.monthly'),
      expect: () => [
        isA<SupporterState>().having(
          (s) => s.status,
          'status',
          SupporterStatus.purchasing,
        ),
        isA<SupporterState>()
            .having((s) => s.status, 'status', SupporterStatus.active)
            .having((s) => s.isSupporter, 'isSupporter', isTrue),
      ],
    );

    blocTest<SupporterCubit, SupporterState>(
      'subscribe maps PurchaseFailedException to failure',
      build: () {
        final repo = _FakeRepository(controller);
        repo.validator.purchaseError = const PurchaseFailedException(
          'cancel',
          'cancelled',
        );
        return SupporterCubit(repository: repo);
      },
      act: (cubit) => cubit.subscribe('divine.supporter.monthly'),
      skip: 1,
      expect: () => [
        isA<SupporterState>()
            .having((s) => s.status, 'status', SupporterStatus.idle)
            .having(
              (s) => s.failure,
              'failure',
              SupporterFailure.purchaseFailed,
            ),
      ],
    );
  });

  group('restore', () {
    blocTest<SupporterCubit, SupporterState>(
      'restore emits restoring then idle on success',
      build: () {
        final repo = _FakeRepository(controller);
        return SupporterCubit(repository: repo);
      },
      act: (cubit) => cubit.restore(),
      expect: () => [
        isA<SupporterState>().having(
          (s) => s.status,
          'status',
          SupporterStatus.restoring,
        ),
        isA<SupporterState>().having(
          (s) => s.status,
          'status',
          SupporterStatus.idle,
        ),
      ],
    );

    blocTest<SupporterCubit, SupporterState>(
      'restore maps RestoreFailedException to failure',
      build: () {
        final repo = _FakeRepository(controller);
        repo.validator.restoreError = const RestoreFailedException();
        return SupporterCubit(repository: repo);
      },
      act: (cubit) => cubit.restore(),
      skip: 1,
      expect: () => [
        isA<SupporterState>()
            .having((s) => s.status, 'status', SupporterStatus.idle)
            .having(
              (s) => s.failure,
              'failure',
              SupporterFailure.restoreFailed,
            ),
      ],
    );
  });

  group('SupporterFailure.fromMessage', () {
    test('SupporterFailure.fromMessage maps known substrings', () {
      expect(
        SupporterFailure.fromMessage('Store is unavailable.'),
        SupporterFailure.storeUnavailable,
      );
      expect(
        SupporterFailure.fromMessage('Purchase is pending.'),
        SupporterFailure.purchasePending,
      );
      expect(
        SupporterFailure.fromMessage('No subscription to restore.'),
        SupporterFailure.restoreFailed,
      );
      expect(
        SupporterFailure.fromMessage('Purchase was cancelled.'),
        SupporterFailure.purchaseFailed,
      );
      expect(
        SupporterFailure.fromMessage('something unexpected'),
        SupporterFailure.unknown,
      );
    });
  });

  group('close safety', () {
    test(
      'does not emit after close when tier loading completes late',
      () async {
        final repo = _FakeRepository(controller);
        final completer = Completer<List<SupporterTier>>();
        repo.validator.fetchCompleter = completer;
        final cubit = SupporterCubit(repository: repo);

        final load = cubit.loadTiers();
        await Future<void>.delayed(Duration.zero);
        await cubit.close();
        completer.complete(const <SupporterTier>[]);

        await expectLater(load, completes);
      },
    );
  });

  group('purchase lifecycle', () {
    test('late store completion does not overwrite verified status', () async {
      final events = <String>[];
      final repo = _FakeRepository(controller)
        ..purchaseCompleter = Completer<SupporterEntitlement>();
      final cubit = SupporterCubit(repository: repo, trackEvent: events.add);
      addTearDown(cubit.close);
      cubit.start();
      await pumpEventQueue();
      final purchase = cubit.subscribe('divine.supporter.monthly');
      controller.add(
        const SupporterEntitlement(
          productId: 'divine.supporter.monthly',
          source: EntitlementSource.server,
        ),
      );
      await pumpEventQueue();
      repo.purchaseCompleter!.complete(SupporterEntitlement.inactive);
      await purchase;

      expect(cubit.state.isSupporter, isTrue);
      expect(cubit.state.status, SupporterStatus.active);
      expect(
        events.where((event) => event == 'supporter_subscribe_succeeded'),
        hasLength(1),
      );
    });

    test('records success only after canonical activation', () async {
      final events = <String>[];
      final repo = _FakeRepository(controller);
      final cubit = SupporterCubit(repository: repo, trackEvent: events.add);
      addTearDown(cubit.close);
      cubit.start();
      await pumpEventQueue();

      await cubit.subscribe('divine.supporter.monthly');

      expect(cubit.state.status, SupporterStatus.confirming);
      expect(events, ['supporter_subscribe_tapped']);

      controller.add(
        const SupporterEntitlement(
          productId: 'divine.supporter.monthly',
          source: EntitlementSource.server,
        ),
      );
      await pumpEventQueue();

      expect(cubit.state.isSupporter, isTrue);
      expect(events, [
        'supporter_subscribe_tapped',
        'supporter_subscribe_succeeded',
      ]);
    });

    test('records failed verification instead of purchase success', () async {
      final events = <String>[];
      final cubit = SupporterCubit(
        repository: _FakeRepository(controller),
        trackEvent: events.add,
      );
      addTearDown(cubit.close);
      cubit.start();
      await pumpEventQueue();
      await cubit.subscribe('divine.supporter.monthly');
      controller.addError(
        const SupporterApiException(
          SupporterApiFailureKind.unavailable,
          'Verification unavailable.',
        ),
      );
      await pumpEventQueue();

      expect(cubit.state.isBusy, isFalse);
      expect(events, [
        'supporter_subscribe_tapped',
        'supporter_subscribe_failed',
      ]);
    });

    test('analytics failures cannot prevent a purchase', () async {
      final repo = _FakeRepository(controller);
      repo.validator.purchaseResult = const SupporterEntitlement(
        productId: 'divine.supporter.monthly',
        source: EntitlementSource.server,
      );
      final cubit = SupporterCubit(
        repository: repo,
        trackEvent: (_) => throw StateError('Analytics unavailable'),
      );
      addTearDown(cubit.close);

      await cubit.subscribe('divine.supporter.monthly');

      expect(cubit.state.isSupporter, isTrue);
    });

    test(
      'surfaces verification failure received from the proof stream',
      () async {
        final repo = _FakeRepository(controller);
        final cubit = SupporterCubit(repository: repo);
        addTearDown(cubit.close);

        cubit.start();
        await pumpEventQueue();
        controller.addError(
          const SupporterApiException(
            SupporterApiFailureKind.unavailable,
            'Supporter verification is not configured.',
          ),
        );
        await pumpEventQueue();

        expect(cubit.state.status, SupporterStatus.error);
        expect(
          cubit.state.failure,
          SupporterFailure.verificationUnavailable,
        );
        expect(cubit.state.isBusy, isFalse);
      },
    );

    test('surfaces pending and confirming purchase lifecycle', () async {
      final lifecycle = StreamController<EntitlementLifecycle>.broadcast();
      addTearDown(lifecycle.close);
      final repo = _FakeRepository(controller);
      repo.validator.lifecycleStream = lifecycle.stream;
      final cubit = SupporterCubit(repository: repo);
      addTearDown(cubit.close);

      cubit.start();
      lifecycle.add(EntitlementLifecycle.pending);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.status, SupporterStatus.pending);

      lifecycle.add(EntitlementLifecycle.confirming);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.status, SupporterStatus.confirming);
    });
  });
}
