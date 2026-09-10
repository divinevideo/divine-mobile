// ABOUTME: Tests for SupporterRepository caching + stream bridging.
// ABOUTME: Uses a fake EntitlementValidator to drive entitlement changes.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iap_repository/iap_repository.dart';
import 'package:models/models.dart';
import 'package:openvine/services/supporter_api_client.dart';
import 'package:openvine/services/supporter_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A controllable fake validator that emits on a stream we own.
class _FakeValidator implements EntitlementValidator {
  _FakeValidator(this._controller);

  final StreamController<SupporterEntitlement> _controller;
  final StreamController<SupporterPurchaseProof> proofController =
      StreamController<SupporterPurchaseProof>.broadcast();
  List<SupporterTier> products = const [];
  SupporterEntitlement purchaseResult = SupporterEntitlement.inactive;
  int restoreCallCount = 0;
  String? restoredPubkey;
  bool? restoredSilently;
  int purchaseCallCount = 0;
  int completePurchaseCallCount = 0;
  Completer<void>? completionObserved;
  void Function()? onRestore;
  Object? completionError;
  Object? restoreError;
  Object? purchaseError;
  Completer<void>? restoreCompleter;

  @override
  void startListening() {}

  @override
  Future<bool> get isAvailable async => true;

  @override
  Future<List<SupporterTier>> fetchProducts() async => products;

  @override
  Future<SupporterEntitlement> purchase(
    String productId, {
    String? capturedPubkey,
    String? attemptId,
  }) async {
    purchaseCallCount++;
    if (purchaseError != null) throw purchaseError!;
    return purchaseResult;
  }

  @override
  Future<SupporterEntitlement> restorePurchases({
    String? capturedPubkey,
    String? attemptId,
    bool silent = false,
  }) async {
    restoreCallCount++;
    restoredPubkey = capturedPubkey;
    restoredSilently = silent;
    if (restoreError != null) throw restoreError!;
    onRestore?.call();
    await restoreCompleter?.future;
    return purchaseResult;
  }

  @override
  Stream<SupporterEntitlement> get entitlementChanges => _controller.stream;

  @override
  Stream<EntitlementLifecycle> get lifecycleChanges => const Stream.empty();

  @override
  Stream<SupporterPurchaseProof> get purchaseProofChanges =>
      proofController.stream;

  @override
  Future<void> completePurchase(SupporterPurchaseProof proof) async {
    completePurchaseCallCount++;
    if (completionError != null) throw completionError!;
    completionObserved?.complete();
  }

  void emit(SupporterEntitlement e) => _controller.add(e);

  void emitError(Object error, [StackTrace? stackTrace]) =>
      _controller.addError(error, stackTrace);

  @override
  void dispose() {
    unawaited(proofController.close());
  }
}

void main() {
  const pubkeyA =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const pubkeyB =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  SupporterApiClient buildApiClient({
    bool active = false,
    String pubkey = pubkeyA,
    int? claimStatus,
    String? claimErrorCode,
    Completer<void>? claimObserved,
  }) {
    return SupporterApiClient(
      baseUri: Uri.parse('https://supporters.test'),
      httpClient: MockClient((request) async {
        if (request.method == 'POST' && claimStatus != null) {
          claimObserved?.complete();
          return http.Response(
            jsonEncode({
              'error': {'code': claimErrorCode},
            }),
            claimStatus,
          );
        }
        return http.Response(
          jsonEncode({
            'status': active ? 'active' : 'inactive',
            'entitlement': {
              if (active) 'productId': 'divine.supporter.monthly',
              'source': 'server',
              'isActive': active,
            },
            'recognition': <String, dynamic>{},
          }),
          200,
        );
      }),
      authHeaderProvider: ({required url, required method, payload}) async =>
          (authorizationHeader: 'Nostr test-token', pubkey: pubkey),
    );
  }

  SharedPreferences.setMockInitialValues({});

  group(SupporterRepository, () {
    late _FakeValidator validator;
    late StreamController<SupporterEntitlement> controller;

    setUp(() {
      // Reset the in-memory SharedPreferences between tests so writes in one
      // test do not leak into the next (the mock persists across getInstance
      // calls within a test process).
      SharedPreferences.setMockInitialValues({});
      controller = StreamController<SupporterEntitlement>.broadcast();
      validator = _FakeValidator(controller);
    });

    tearDown(() {
      controller.close();
    });

    for (final error in <Object>[
      const StoreUnavailableException(),
      const PurchaseFailedException('not_started', 'Store did not start.'),
      const PurchaseFailedException('cancelled', 'Canceled.'),
    ]) {
      test('releases pending ownership after $error', () async {
        final prefs = await SharedPreferences.getInstance();
        final clientA = buildApiClient();
        final clientB = buildApiClient(pubkey: pubkeyB);
        addTearDown(clientA.dispose);
        addTearDown(clientB.dispose);
        final repoA = SupporterRepository(
          pubkey: pubkeyA,
          validator: validator,
          prefs: prefs,
          apiClient: clientA,
        );
        validator.purchaseError = error;
        await expectLater(
          repoA.purchase('divine.supporter.monthly'),
          throwsA(same(error)),
        );
        repoA.dispose();
        validator.purchaseError = null;
        final repoB = SupporterRepository(
          pubkey: pubkeyB,
          validator: validator,
          prefs: prefs,
          apiClient: clientB,
        );
        addTearDown(repoB.dispose);
        await repoB.purchase('divine.supporter.monthly');
        expect(validator.purchaseCallCount, 2);
      });
    }

    test('rejected legacy restore does not block the rightful owner', () async {
      final prefs = await SharedPreferences.getInstance();
      final clientB = buildApiClient(
        pubkey: pubkeyB,
        claimStatus: 409,
        claimErrorCode: 'ownership_conflict',
      );
      final repoB = SupporterRepository(
        pubkey: pubkeyB,
        validator: validator,
        prefs: prefs,
        apiClient: clientB,
      );
      addTearDown(clientB.dispose);
      final errors = <Object>[];
      repoB.changes.listen((_) {}, onError: errors.add);
      validator.proofController.add(
        const SupporterPurchaseProof(
          attemptId: 'legacy-proof',
          store: 'apple',
          productId: 'divine.supporter.monthly',
          serverVerificationData: 'opaque-proof',
          localVerificationData: '',
          capturedPubkey: pubkeyB,
        ),
      );
      await pumpEventQueue();
      expect(errors, hasLength(1));
      repoB.dispose();
      final clientA = buildApiClient(active: true);
      addTearDown(clientA.dispose);
      final repoA = SupporterRepository(
        pubkey: pubkeyA,
        validator: validator,
        prefs: prefs,
        apiClient: clientA,
      );
      addTearDown(repoA.dispose);
      repoA.changes.listen((_) {}, onError: errors.add);
      validator.proofController.add(
        const SupporterPurchaseProof(
          attemptId: 'legacy-proof',
          store: 'apple',
          productId: 'divine.supporter.monthly',
          serverVerificationData: 'opaque-proof',
          localVerificationData: '',
          capturedPubkey: pubkeyA,
        ),
      );
      await pumpEventQueue();
      expect(repoA.isSupporter, isTrue);
      expect(validator.completePurchaseCallCount, 1);
      expect(errors, hasLength(1));
    });

    test(
      'failed retry preserves ownership of an earlier unfinished purchase',
      () async {
        final prefs = await SharedPreferences.getInstance();
        const pendingKey =
            'divine_supporter_pending_owner:divine.supporter.monthly';
        await prefs.setString(pendingKey, pubkeyA);
        final client = buildApiClient();
        addTearDown(client.dispose);
        final repo = SupporterRepository(
          pubkey: pubkeyA,
          validator: validator,
          prefs: prefs,
          apiClient: client,
        );
        addTearDown(repo.dispose);
        validator.purchaseError = const StoreUnavailableException();
        await expectLater(
          repo.purchase('divine.supporter.monthly'),
          throwsA(isA<StoreUnavailableException>()),
        );
        expect(prefs.getString(pendingKey), pubkeyA);
      },
    );

    test(
      'legacy restore stays unbound through transient and ownership failures',
      () async {
        final prefs = await SharedPreferences.getInstance();
        var status = 503;
        final client = SupporterApiClient(
          baseUri: Uri.parse('https://supporters.test'),
          httpClient: MockClient(
            (request) async => http.Response(
              jsonEncode({
                'error': {
                  'code': status == 409
                      ? 'ownership_conflict'
                      : 'verification_unavailable',
                },
              }),
              status,
            ),
          ),
          authHeaderProvider:
              ({required url, required method, payload}) async =>
                  (authorizationHeader: 'Nostr test-token', pubkey: pubkeyB),
        );
        addTearDown(client.dispose);
        final repo = SupporterRepository(
          pubkey: pubkeyB,
          validator: validator,
          prefs: prefs,
          apiClient: client,
        );
        addTearDown(repo.dispose);
        final errors = <Object>[];
        repo.changes.listen((_) {}, onError: errors.add);
        const proof = SupporterPurchaseProof(
          attemptId: 'legacy-retry-proof',
          store: 'apple',
          productId: 'divine.supporter.monthly',
          serverVerificationData: 'opaque-proof',
          localVerificationData: '',
          capturedPubkey: pubkeyB,
        );
        validator.proofController.add(proof);
        await pumpEventQueue();
        expect(errors, hasLength(1));
        status = 409;
        validator.proofController.add(proof);
        await pumpEventQueue();
        expect(errors, hasLength(2));
        expect(
          prefs.getString('divine_supporter_proof_owner:legacy-retry-proof'),
          isNull,
        );
      },
    );

    test('loads inactive when no cache present', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = SupporterRepository(
        pubkey: pubkeyA,
        validator: validator,
        prefs: prefs,
      );
      addTearDown(repo.dispose);
      expect(repo.current, equals(SupporterEntitlement.inactive));
      expect(repo.isSupporter, isFalse);
    });

    test('hydrates cached entitlement on construction', () async {
      final cached = SupporterEntitlement(
        productId: 'divine.supporter.monthly',
        source: EntitlementSource.appStore,
        purchaseDate: DateTime.utc(2030),
      ).toJson();
      SharedPreferences.setMockInitialValues({
        'divine_supporter_entitlement:$pubkeyA': jsonEncode(cached),
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = SupporterRepository(
        pubkey: pubkeyA,
        validator: validator,
        prefs: prefs,
      );
      addTearDown(repo.dispose);
      expect(repo.current.productId, 'divine.supporter.monthly');
      expect(repo.isSupporter, isTrue);
    });

    test('marks expired cached entitlement inactive on load', () async {
      final cached = SupporterEntitlement(
        productId: 'divine.supporter.monthly',
        source: EntitlementSource.appStore,
        purchaseDate: DateTime.utc(2000),
        expirationDate: DateTime.utc(2000, 2),
      ).toJson();
      SharedPreferences.setMockInitialValues({
        'divine_supporter_entitlement:$pubkeyA': jsonEncode(cached),
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = SupporterRepository(
        pubkey: pubkeyA,
        validator: validator,
        prefs: prefs,
      );
      addTearDown(repo.dispose);
      expect(repo.isSupporter, isFalse);
    });

    test('updates current and persists when validator emits', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = SupporterRepository(
        pubkey: pubkeyA,
        validator: validator,
        prefs: prefs,
      );
      addTearDown(repo.dispose);

      final emitted = <SupporterEntitlement>[];
      repo.changes.listen(emitted.add);

      validator.emit(
        SupporterEntitlement(
          productId: 'divine.supporter.monthly',
          source: EntitlementSource.playStore,
          purchaseDate: DateTime.utc(2030),
        ),
      );
      // Allow the stream listener to fire.
      await Future<void>.delayed(Duration.zero);

      expect(repo.isSupporter, isTrue);
      expect(emitted.last.isSupporter, isTrue);

      final stored = prefs.getString('divine_supporter_entitlement:$pubkeyA');
      expect(stored, isNotNull);
      expect(stored, contains('divine.supporter.monthly'));
    });

    test('ignores duplicate emissions', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = SupporterRepository(
        pubkey: pubkeyA,
        validator: validator,
        prefs: prefs,
      );
      addTearDown(repo.dispose);

      var emissions = 0;
      repo.changes.listen((_) => emissions++);

      validator.emit(SupporterEntitlement.inactive);
      validator.emit(SupporterEntitlement.inactive);
      await Future<void>.delayed(Duration.zero);

      expect(emissions, 0);
    });

    test('forwards validator stream errors to repository listeners', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = SupporterRepository(
        pubkey: pubkeyA,
        validator: validator,
        prefs: prefs,
      );
      addTearDown(repo.dispose);

      const error = StoreUnavailableException();
      final errorFuture = expectLater(
        repo.changes,
        emitsError(isA<StoreUnavailableException>()),
      );
      validator.emitError(error);

      await errorFuture;
    });

    test('clearLocalEntitlement sets inactive and removes cache', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'divine_supporter_entitlement:$pubkeyA',
        jsonEncode(
          SupporterEntitlement(
            productId: 'p',
            source: EntitlementSource.appStore,
            purchaseDate: DateTime.utc(2030),
          ).toJson(),
        ),
      );
      final repo = SupporterRepository(
        pubkey: pubkeyA,
        validator: validator,
        prefs: prefs,
      );
      addTearDown(repo.dispose);

      await repo.clearLocalEntitlement();
      expect(repo.isSupporter, isFalse);
      expect(prefs.getString('divine_supporter_entitlement:$pubkeyA'), isNull);
    });

    test('loads only the cache belonging to the active pubkey', () async {
      final active = SupporterEntitlement(
        productId: 'divine.supporter.monthly',
        source: EntitlementSource.appStore,
        purchaseDate: DateTime.utc(2030),
      );
      SharedPreferences.setMockInitialValues({
        'divine_supporter_entitlement:$pubkeyA': jsonEncode(active.toJson()),
        'divine_supporter_entitlement:$pubkeyB': jsonEncode(
          SupporterEntitlement.inactive.toJson(),
        ),
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = SupporterRepository(
        pubkey: pubkeyB,
        validator: validator,
        prefs: prefs,
      );
      addTearDown(repo.dispose);

      expect(repo.isSupporter, isFalse);
    });

    test(
      'silently restores configured purchases for the signed-in account',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final apiClient = buildApiClient();
        final repo = SupporterRepository(
          pubkey: pubkeyA,
          validator: validator,
          prefs: prefs,
          apiClient: apiClient,
        );
        addTearDown(repo.dispose);
        addTearDown(apiClient.dispose);

        await repo.recoverPurchases();

        expect(validator.restoreCallCount, 1);
        expect(validator.restoredPubkey, pubkeyA);
        expect(validator.restoredSilently, isTrue);
      },
    );

    test('coalesces concurrent automatic recovery attempts', () async {
      final prefs = await SharedPreferences.getInstance();
      final apiClient = buildApiClient();
      final repo = SupporterRepository(
        pubkey: pubkeyA,
        validator: validator,
        prefs: prefs,
        apiClient: apiClient,
      );
      addTearDown(repo.dispose);
      addTearDown(apiClient.dispose);
      validator.restoreCompleter = Completer<void>();

      final first = repo.recoverPurchases();
      final second = repo.recoverPurchases();
      await Future<void>.delayed(Duration.zero);

      expect(validator.restoreCallCount, 1);
      validator.restoreCompleter!.complete();
      await Future.wait([first, second]);
    });

    test(
      'skips automatic recovery when no Worker client is configured',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final repo = SupporterRepository(
          pubkey: pubkeyA,
          validator: validator,
          prefs: prefs,
        );
        addTearDown(repo.dispose);

        await repo.recoverPurchases();

        expect(validator.restoreCallCount, 0);
      },
    );

    test(
      'restores once to acknowledge purchases even when already active',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final apiClient = buildApiClient(active: true);
        final repo = SupporterRepository(
          pubkey: pubkeyA,
          validator: validator,
          prefs: prefs,
          apiClient: apiClient,
        );
        addTearDown(repo.dispose);
        addTearDown(apiClient.dispose);

        await repo.recoverPurchases();
        await repo.recoverPurchases();

        expect(repo.isSupporter, isTrue);
        expect(validator.restoreCallCount, 1);
      },
    );

    test('does not repeat a successful recovery in the same process', () async {
      final prefs = await SharedPreferences.getInstance();
      final apiClient = buildApiClient();
      final repo = SupporterRepository(
        pubkey: pubkeyA,
        validator: validator,
        prefs: prefs,
        apiClient: apiClient,
      );
      addTearDown(repo.dispose);
      addTearDown(apiClient.dispose);

      await repo.recoverPurchases();
      await repo.recoverPurchases();

      expect(validator.restoreCallCount, 1);
    });

    test(
      'retries a failed background restore without surfacing its error',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final apiClient = buildApiClient();
        final repo = SupporterRepository(
          pubkey: pubkeyA,
          validator: validator,
          prefs: prefs,
          apiClient: apiClient,
        );
        addTearDown(repo.dispose);
        addTearDown(apiClient.dispose);
        validator.restoreError = const StoreUnavailableException();
        final errors = <Object>[];
        repo.changes.listen((_) {}, onError: errors.add);

        await repo.recoverPurchases();
        await repo.recoverPurchases();

        expect(validator.restoreCallCount, 2);
        expect(errors, isEmpty);
      },
    );

    test('does not retry a purchase owned by another account', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'divine_supporter_proof_owner:stable-attempt-1234',
        pubkeyA,
      );
      final claimObserved = Completer<void>();
      final apiClient = buildApiClient(
        claimStatus: 409,
        claimErrorCode: 'ownership_conflict',
        claimObserved: claimObserved,
      );
      final repo = SupporterRepository(
        pubkey: pubkeyA,
        validator: validator,
        prefs: prefs,
        apiClient: apiClient,
      );
      addTearDown(repo.dispose);
      addTearDown(apiClient.dispose);

      await repo.recoverPurchases();
      validator.proofController.add(
        const SupporterPurchaseProof(
          attemptId: 'stable-attempt-1234',
          store: 'apple',
          productId: 'divine.supporter.monthly',
          serverVerificationData: 'opaque-proof',
          localVerificationData: '',
          capturedPubkey: pubkeyA,
          silent: true,
        ),
      );
      await claimObserved.future;
      await Future<void>.delayed(Duration.zero);
      await repo.recoverPurchases();

      expect(validator.restoreCallCount, 1);
      expect(validator.completePurchaseCallCount, 0);
    });

    test('retries store acknowledgement after canonical activation', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'divine_supporter_proof_owner:stable-attempt-1234',
        pubkeyA,
      );
      final apiClient = buildApiClient(active: true);
      final repo = SupporterRepository(
        pubkey: pubkeyA,
        validator: validator,
        prefs: prefs,
        apiClient: apiClient,
      );
      addTearDown(repo.dispose);
      addTearDown(apiClient.dispose);
      validator.completionError = StateError('Store disconnected');
      const proof = SupporterPurchaseProof(
        attemptId: 'stable-attempt-1234',
        store: 'google',
        productId: 'divine.supporter.monthly',
        serverVerificationData: 'opaque-proof',
        localVerificationData: '',
        capturedPubkey: pubkeyA,
        silent: true,
      );
      validator.proofController.add(proof);
      await pumpEventQueue();
      expect(repo.isSupporter, isTrue);
      expect(validator.completePurchaseCallCount, 1);
      validator.completionError = null;
      validator.completionObserved = Completer<void>();
      validator.onRestore = () => validator.proofController.add(proof);

      await repo.recoverPurchases();
      await validator.completionObserved!.future;

      expect(validator.completePurchaseCallCount, 2);
    });

    test('failed claim during restore remains retryable', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'divine_supporter_proof_owner:stable-attempt-1234',
        pubkeyA,
      );
      final claimObserved = Completer<void>();
      final apiClient = buildApiClient(
        claimStatus: 503,
        claimObserved: claimObserved,
      );
      final repo = SupporterRepository(
        pubkey: pubkeyA,
        validator: validator,
        prefs: prefs,
        apiClient: apiClient,
      );
      addTearDown(repo.dispose);
      addTearDown(apiClient.dispose);
      validator.restoreCompleter = Completer<void>();
      final recovery = repo.recoverPurchases();
      await pumpEventQueue();
      validator.proofController.add(
        const SupporterPurchaseProof(
          attemptId: 'stable-attempt-1234',
          store: 'apple',
          productId: 'divine.supporter.monthly',
          serverVerificationData: 'opaque-proof',
          localVerificationData: '',
          capturedPubkey: pubkeyA,
          silent: true,
        ),
      );
      await claimObserved.future;
      await pumpEventQueue();
      validator.restoreCompleter!.complete();
      await recovery;
      await repo.recoverPurchases();

      expect(validator.restoreCallCount, 2);
      expect(validator.completePurchaseCallCount, 0);
    });

    test('acknowledges a purchase once after a successful claim', () async {
      final prefs = await SharedPreferences.getInstance();
      final apiClient = buildApiClient(active: true);
      final repo = SupporterRepository(
        pubkey: pubkeyA,
        validator: validator,
        prefs: prefs,
        apiClient: apiClient,
      );
      addTearDown(repo.dispose);
      addTearDown(apiClient.dispose);
      validator.completionObserved = Completer<void>();

      validator.proofController.add(
        const SupporterPurchaseProof(
          attemptId: 'stable-attempt-1234',
          store: 'google',
          productId: 'divine.supporter.monthly',
          serverVerificationData: 'opaque-proof',
          localVerificationData: '',
          capturedPubkey: pubkeyA,
        ),
      );
      await validator.completionObserved!.future;

      expect(validator.completePurchaseCallCount, 1);
      expect(repo.isSupporter, isTrue);
    });

    test('leaves a redelivered proof unacknowledged and surfaces unavailable '
        'when no verification client is configured', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = SupporterRepository(
        pubkey: pubkeyA,
        validator: validator,
        prefs: prefs,
      );
      addTearDown(repo.dispose);

      final errorFuture = expectLater(
        repo.changes,
        emitsError(
          isA<SupporterApiException>().having(
            (error) => error.kind,
            'kind',
            SupporterApiFailureKind.unavailable,
          ),
        ),
      );

      validator.proofController.add(
        const SupporterPurchaseProof(
          attemptId: 'stable-attempt-1234',
          store: 'apple',
          productId: 'divine.supporter.monthly',
          serverVerificationData: 'opaque-proof',
          localVerificationData: '',
          capturedPubkey: pubkeyA,
        ),
      );

      await errorFuture;
      // The store proof must stay unacknowledged so it can be redelivered once
      // a verification client is configured.
      expect(validator.completePurchaseCallCount, 0);
      expect(repo.isSupporter, isFalse);
    });

    test(
      'preserves purchase ownership across account switch and restart',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final apiClientA = buildApiClient();
        addTearDown(apiClientA.dispose);
        final original = SupporterRepository(
          pubkey: pubkeyA,
          validator: validator,
          prefs: prefs,
          apiClient: apiClientA,
        );
        await original.purchase('divine.supporter.monthly');
        original.dispose();
        var claims = 0;
        final apiClientB = SupporterApiClient(
          baseUri: Uri.parse('https://supporters.test'),
          httpClient: MockClient((_) async {
            claims++;
            return http.Response('{}', 200);
          }),
          authHeaderProvider:
              ({required url, required method, payload}) async =>
                  (authorizationHeader: 'Nostr test-token', pubkey: pubkeyB),
        );
        addTearDown(apiClientB.dispose);
        final switched = SupporterRepository(
          pubkey: pubkeyB,
          validator: validator,
          prefs: prefs,
          apiClient: apiClientB,
        );
        addTearDown(switched.dispose);
        validator.proofController.add(
          const SupporterPurchaseProof(
            attemptId: 'stable-attempt-1234',
            store: 'apple',
            productId: 'divine.supporter.monthly',
            serverVerificationData: 'opaque-proof',
            localVerificationData: '',
            capturedPubkey: pubkeyB,
            silent: true,
          ),
        );
        await pumpEventQueue();

        expect(claims, 0);
        expect(switched.isSupporter, isFalse);
        expect(validator.completePurchaseCallCount, 0);
      },
    );

    for (final status in [404, 503]) {
      test(
        'unbound automatic restore uses only the owned endpoint ($status)',
        () async {
          final prefs = await SharedPreferences.getInstance();
          final paths = <String>[];
          final apiClient = SupporterApiClient(
            baseUri: Uri.parse('https://supporters.test'),
            httpClient: MockClient((request) async {
              paths.add(request.url.path);
              return http.Response('{}', status);
            }),
            authHeaderProvider:
                ({required url, required method, payload}) async =>
                    (authorizationHeader: 'Nostr test-token', pubkey: pubkeyA),
          );
          addTearDown(apiClient.dispose);
          final repo = SupporterRepository(
            pubkey: pubkeyA,
            validator: validator,
            prefs: prefs,
            apiClient: apiClient,
          );
          addTearDown(repo.dispose);
          final errors = <Object>[];
          repo.changes.listen((_) {}, onError: errors.add);
          validator.proofController.add(
            const SupporterPurchaseProof(
              attemptId: 'unbound-legacy-attempt',
              store: 'apple',
              productId: 'divine.supporter.monthly',
              serverVerificationData: 'opaque-proof',
              localVerificationData: '',
              capturedPubkey: pubkeyA,
              silent: true,
            ),
          );
          await pumpEventQueue();
          expect(paths, ['/v1/purchases/restore']);
          expect(validator.completePurchaseCallCount, 0);
          expect(errors, isEmpty);
          expect(
            prefs.getString(
              'divine_supporter_proof_owner:unbound-legacy-attempt',
            ),
            isNull,
          );
        },
      );
    }

    for (final passive in [false, true]) {
      test(
        'recovers a server-owned renewal with a new transaction ID (passive=$passive)',
        () async {
          final prefs = await SharedPreferences.getInstance();
          final paths = <String>[];
          final apiClient = SupporterApiClient(
            baseUri: Uri.parse('https://supporters.test'),
            httpClient: MockClient((request) async {
              paths.add(request.url.path);
              return http.Response(
                jsonEncode({
                  'status': 'active',
                  'entitlement': {
                    'productId': 'divine.supporter.monthly',
                    'source': 'server',
                    'isActive': true,
                  },
                }),
                200,
              );
            }),
            authHeaderProvider:
                ({required url, required method, payload}) async =>
                    (authorizationHeader: 'Nostr test-token', pubkey: pubkeyA),
          );
          addTearDown(apiClient.dispose);
          final repo = SupporterRepository(
            pubkey: pubkeyA,
            validator: validator,
            prefs: prefs,
            apiClient: apiClient,
          );
          addTearDown(repo.dispose);
          validator.proofController.add(
            SupporterPurchaseProof(
              attemptId: 'new-renewal-transaction',
              store: 'apple',
              productId: 'divine.supporter.monthly',
              serverVerificationData: 'opaque-proof',
              localVerificationData: '',
              capturedPubkey: passive ? null : pubkeyA,
              silent: !passive,
            ),
          );
          await pumpEventQueue();
          expect(paths, ['/v1/purchases/restore']);
          expect(repo.isSupporter, isTrue);
          expect(validator.completePurchaseCallCount, 1);
          expect(
            prefs.getString(
              'divine_supporter_proof_owner:new-renewal-transaction',
            ),
            pubkeyA,
          );
        },
      );
    }

    test('checks authenticated server state before starting billing', () async {
      final prefs = await SharedPreferences.getInstance();
      final apiClient = SupporterApiClient(
        baseUri: Uri.parse('https://supporters.test'),
        httpClient: MockClient((_) async => http.Response('', 503)),
        authHeaderProvider: ({required url, required method, payload}) async =>
            (authorizationHeader: 'Nostr test-token', pubkey: pubkeyA),
      );
      addTearDown(apiClient.dispose);
      final repo = SupporterRepository(
        pubkey: pubkeyA,
        validator: validator,
        prefs: prefs,
        apiClient: apiClient,
      );
      addTearDown(repo.dispose);

      await expectLater(
        repo.purchase('divine.supporter.monthly'),
        throwsA(isA<SupporterApiException>()),
      );
      expect(validator.purchaseCallCount, 0);
    });

    test('does not charge an already active supporter again', () async {
      final prefs = await SharedPreferences.getInstance();
      final apiClient = buildApiClient(active: true);
      addTearDown(apiClient.dispose);
      final repo = SupporterRepository(
        pubkey: pubkeyA,
        validator: validator,
        prefs: prefs,
        apiClient: apiClient,
      );
      addTearDown(repo.dispose);

      final entitlement = await repo.purchase('divine.supporter.monthly');

      expect(entitlement.isSupporter, isTrue);
      expect(validator.purchaseCallCount, 0);
    });

    test('refuses to start billing without a verification client', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = SupporterRepository(
        pubkey: pubkeyA,
        validator: validator,
        prefs: prefs,
      );
      addTearDown(repo.dispose);

      await expectLater(
        repo.purchase('divine.supporter.monthly'),
        throwsA(
          isA<SupporterApiException>().having(
            (error) => error.kind,
            'kind',
            SupporterApiFailureKind.unavailable,
          ),
        ),
      );
      expect(validator.purchaseCallCount, 0);
    });

    test(
      'does not claim another account unfinished redelivery under the pending '
      'account',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final posts = <String>[];
        final clientB = SupporterApiClient(
          baseUri: Uri.parse('https://supporters.test'),
          httpClient: MockClient((request) async {
            if (request.method == 'POST') posts.add(request.url.path);
            return http.Response(
              jsonEncode({
                'status': 'inactive',
                'entitlement': {
                  'source': 'server',
                  'isActive': false,
                },
                'recognition': <String, dynamic>{},
              }),
              200,
            );
          }),
          authHeaderProvider:
              ({required url, required method, payload}) async =>
                  (authorizationHeader: 'Nostr test-token', pubkey: pubkeyB),
        );
        addTearDown(clientB.dispose);
        final repoB = SupporterRepository(
          pubkey: pubkeyB,
          validator: validator,
          prefs: prefs,
          apiClient: clientB,
        );
        addTearDown(repoB.dispose);

        // B starts a purchase, setting the product-scoped pending marker to B.
        await repoB.purchase('divine.supporter.monthly');
        // Account A's paid-but-unclaimed transaction redelivers unsolicited:
        // no proof-owner marker, no captured pubkey, silent.
        validator.proofController.add(
          const SupporterPurchaseProof(
            attemptId: 'account-a-unfinished',
            store: 'apple',
            productId: 'divine.supporter.monthly',
            serverVerificationData: 'account-a-receipt',
            localVerificationData: '',
            silent: true,
          ),
        );
        await pumpEventQueue();

        // The redelivery must not first-time-claim A's receipt under B. It may
        // only reach the restore endpoint, which the server fails closed.
        expect(posts, isNot(contains('/v1/purchases/claim')));
        expect(repoB.isSupporter, isFalse);
      },
    );

    test('preflight rejects a purchase when another account holds the pending '
        'marker', () async {
      final prefs = await SharedPreferences.getInstance();
      final clientA = buildApiClient();
      final clientB = buildApiClient(pubkey: pubkeyB);
      addTearDown(clientA.dispose);
      addTearDown(clientB.dispose);
      // Account A leaves a pending marker by starting (not finishing) a buy.
      final repoA = SupporterRepository(
        pubkey: pubkeyA,
        validator: validator,
        prefs: prefs,
        apiClient: clientA,
      );
      await repoA.purchase('divine.supporter.monthly');
      repoA.dispose();
      final purchasesBefore = validator.purchaseCallCount;

      final repoB = SupporterRepository(
        pubkey: pubkeyB,
        validator: validator,
        prefs: prefs,
        apiClient: clientB,
      );
      addTearDown(repoB.dispose);
      await expectLater(
        repoB.purchase('divine.supporter.monthly'),
        throwsA(
          isA<SupporterApiException>().having(
            (error) => error.kind,
            'kind',
            SupporterApiFailureKind.ownershipConflict,
          ),
        ),
      );
      // B never reached the store: preflight refused before billing started.
      expect(validator.purchaseCallCount, purchasesBefore);
    });
  });
}
