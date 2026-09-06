// ABOUTME: Tests for NIP17MessageService encrypted message sending.
// ABOUTME: Covers NIP-17 gift wrap creation, encryption, publishing,
// ABOUTME: self-wrap fallback, and error handling paths.

import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart'
    show NIP17BlockedSendDisposition, NIP17SendFailure, NIP17SendResult;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nip59/gift_wrap_batch_wrap.dart';
import 'package:nostr_sdk/nip59/gift_wrap_util.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/signer/isolate_decrypt_signer.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:nostr_sdk/signer/signer_failure.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockNostrSigner extends Mock implements NostrSigner {}

class _FakeEvent extends Fake implements Event {}

/// Reproduces the `toString()` shape of `keycast_flutter`'s `RpcException`
/// (`'RpcException: <message>'`) so the policy-denial classification test
/// exercises the real Keycast 403 surface, not a generic `Exception`.
/// `dm_repository` cannot depend on `keycast_flutter`, so this pins the
/// cross-package error-body contract locally: if Keycast's wording drifts,
/// the marker in `nip17_message_service.dart` must be updated in lockstep.
class _RpcExceptionDouble implements Exception {
  _RpcExceptionDouble(this.message);

  final String message;

  @override
  String toString() => 'RpcException: $message';
}

/// Reproduces `keycast_flutter`'s `RpcTimeoutException`: the exception raised
/// when Keycast answers a signing RPC with HTTP 504 because it hit its own
/// handler bound. What matters to `NIP17MessageService` is the
/// [TransientSignerFailure] marker, not the type or the wording — the marker
/// is the cross-package contract, and unlike the 403 double below it survives
/// any rewording of Keycast's error body.
class _TransientRpcExceptionDouble
    implements Exception, TransientSignerFailure {
  _TransientRpcExceptionDouble(this.message);

  final String message;

  @override
  String toString() => 'RpcTimeoutException: $message';
}

/// Encrypts normally but returns `null` from [signEvent], reproducing what
/// every remote signer does when signing is declined: an Amber user dismissing
/// the approval prompt, a NIP-46 bunker RPC timing out, a NIP-07 rejection.
class _RefusesToSignSigner implements NostrSigner {
  _RefusesToSignSigner(this._delegate);

  final LocalNostrSigner _delegate;

  @override
  Future<Event?> signEvent(Event event) async => null;

  @override
  Future<String?> getPublicKey() => _delegate.getPublicKey();

  @override
  Future<Map<dynamic, dynamic>?> getRelays() => _delegate.getRelays();

  @override
  Future<String?> encrypt(String pubkey, String plaintext) =>
      _delegate.encrypt(pubkey, plaintext);

  @override
  Future<String?> decrypt(String pubkey, String ciphertext) =>
      _delegate.decrypt(pubkey, ciphertext);

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) =>
      _delegate.nip44Encrypt(pubkey, plaintext);

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) =>
      _delegate.nip44Decrypt(pubkey, ciphertext);

  @override
  void close() => _delegate.close();
}

/// Denies every recipient — stands in for a protected minor's policy where the
/// counterparty is not in the approved official set.
Future<DmSendPolicyDecision> _denyAllPolicy(String recipientPubkey) async =>
    DmSendPolicyDecision.terminallyBlockedDiscard;

Future<DmSendPolicyDecision> _temporarilyDenyPolicy(
  String recipientPubkey,
) async => DmSendPolicyDecision.temporarilyBlocked;

Future<DmSendPolicyDecision> _retainBlockedPolicy(
  String recipientPubkey,
) async => DmSendPolicyDecision.terminallyBlockedRetain;

/// A local-key signer that advertises the isolate-offload capability,
/// delegating all crypto to a real [LocalNostrSigner]. Used to exercise the
/// `_buildWrap` isolate branch in [NIP17MessageService]. See #5391.
class _LocalIsolateSigner implements IsolateDecryptSigner {
  _LocalIsolateSigner(this._privateKeyHex)
    : _delegate = LocalNostrSigner(_privateKeyHex);

  final String _privateKeyHex;
  final LocalNostrSigner _delegate;

  @override
  bool get canDecryptInIsolate => true;

  @override
  T withPrivateKeyHex<T>(T Function(String hex) operation) =>
      operation(_privateKeyHex);

  @override
  Future<String?> getPublicKey() => _delegate.getPublicKey();

  @override
  Future<Event?> signEvent(Event event) => _delegate.signEvent(event);

  @override
  Future<Map<dynamic, dynamic>?> getRelays() => _delegate.getRelays();

  @override
  Future<String?> encrypt(String pubkey, String plaintext) =>
      _delegate.encrypt(pubkey, plaintext);

  @override
  Future<String?> decrypt(String pubkey, String ciphertext) =>
      _delegate.decrypt(pubkey, ciphertext);

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) =>
      _delegate.nip44Encrypt(pubkey, plaintext);

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) =>
      _delegate.nip44Decrypt(pubkey, ciphertext);

  @override
  void close() => _delegate.close();
}

/// Answers a `nip17_wrap_batch` call. Returning `null` models a backend
/// without the verb; throwing models a transient failure.
typedef _OnWrapBatch =
    Future<List<GiftWrapSlot>?> Function(
      Map<String, dynamic> rumor,
      List<String> recipientPubkeys,
    );

/// A remote signer that supports the server-side gift-wrap batch — the
/// OAuth-only Keycast shape. Counts the per-wrap signing calls too, so a test
/// can assert the batch actually replaced them rather than running alongside.
class _BatchWrapSigner implements NostrSigner, GiftWrapBatchWrapper {
  _BatchWrapSigner(String privateKeyHex, {required _OnWrapBatch onBatch})
    : _delegate = LocalNostrSigner(privateKeyHex),
      _onBatch = onBatch;

  final LocalNostrSigner _delegate;
  final _OnWrapBatch _onBatch;

  int batchCalls = 0;
  int nip44EncryptCalls = 0;
  int signEventCalls = 0;

  @override
  Future<List<GiftWrapSlot>?> nip17WrapBatch(
    Map<String, dynamic> rumor,
    List<String> recipientPubkeys,
  ) {
    batchCalls++;
    return _onBatch(rumor, recipientPubkeys);
  }

  @override
  Future<String?> getPublicKey() => _delegate.getPublicKey();

  @override
  Future<Event?> signEvent(Event event) {
    signEventCalls++;
    return _delegate.signEvent(event);
  }

  @override
  Future<Map<dynamic, dynamic>?> getRelays() => _delegate.getRelays();

  @override
  Future<String?> encrypt(String pubkey, String plaintext) =>
      _delegate.encrypt(pubkey, plaintext);

  @override
  Future<String?> decrypt(String pubkey, String ciphertext) =>
      _delegate.decrypt(pubkey, ciphertext);

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) {
    nip44EncryptCalls++;
    return _delegate.nip44Encrypt(pubkey, plaintext);
  }

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) =>
      _delegate.nip44Decrypt(pubkey, ciphertext);

  @override
  void close() => _delegate.close();
}

/// A signer that is BOTH isolate-capable and batch-capable — the BYOK Keycast
/// identity. Pins that the in-process isolate path wins over the network one.
class _IsolateAndBatchSigner extends _BatchWrapSigner
    implements IsolateDecryptSigner {
  _IsolateAndBatchSigner(this._privateKeyHex, {required super.onBatch})
    : super(_privateKeyHex);

  final String _privateKeyHex;

  @override
  bool get canDecryptInIsolate => true;

  @override
  T withPrivateKeyHex<T>(T Function(String hex) operation) =>
      operation(_privateKeyHex);
}

// Valid 64-character hex keys for testing.
const _testPrivateKey =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _testPublicKey =
    '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
const _recipientPubkey =
    'e771af0b05c8e95fcdf6feb3500544d2fb1ccd384788e9f490bb3ee28e8ed66f';

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(Duration.zero);
  });

  group(NIP17MessageService, () {
    late NIP17MessageService service;
    late _MockNostrClient mockNostrClient;

    setUp(() {
      mockNostrClient = _MockNostrClient();

      service = NIP17MessageService(
        signer: LocalNostrSigner(_testPrivateKey),
        senderPublicKey: _testPublicKey,
        nostrService: mockNostrClient,
      );
    });

    group('send policy gate', () {
      test(
        'sendRumor blocked by policy returns failure and never publishes',
        () async {
          final blocked = NIP17MessageService(
            signer: LocalNostrSigner(_testPrivateKey),
            senderPublicKey: _testPublicKey,
            nostrService: mockNostrClient,
            sendPolicy: _denyAllPolicy,
          );
          final rumor = blocked.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'should be blocked',
          );

          final result = await blocked.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _recipientPubkey,
          );

          expect(result.success, isFalse);
          // The complement of the temporary case below, and the signal the app
          // layer branches on: `blocked` drives the refusal copy in the
          // conversation view and tells the cold-start drain to drop the row
          // instead of retrying a send that can never succeed.
          expect(result.blocked, isTrue);
          expect(
            result.blockedDisposition,
            NIP17BlockedSendDisposition.discard,
          );
          verifyNever(() => mockNostrClient.publishEvent(any()));
          verifyNever(
            () => mockNostrClient.publishEvent(
              any(),
              targetRelays: any(named: 'targetRelays'),
            ),
          );
        },
      );

      test('sendRumor carries a retained terminal disposition', () async {
        final blocked = NIP17MessageService(
          signer: LocalNostrSigner(_testPrivateKey),
          senderPublicKey: _testPublicKey,
          nostrService: mockNostrClient,
          sendPolicy: _retainBlockedPolicy,
        );
        final rumor = blocked.buildRumor(
          recipientPubkey: _recipientPubkey,
          content: 'keep my local copy',
        );

        final result = await blocked.sendRumor(
          rumorEvent: rumor,
          recipientPubkey: _recipientPubkey,
        );

        expect(result.blocked, isTrue);
        expect(
          result.blockedDisposition,
          NIP17BlockedSendDisposition.retain,
        );
        verifyNever(() => mockNostrClient.publishEvent(any()));
      });

      test(
        'canSendTo surfaces the policy verdict for pre-enqueue/group checks',
        () async {
          final blocked = NIP17MessageService(
            signer: LocalNostrSigner(_testPrivateKey),
            senderPublicKey: _testPublicKey,
            nostrService: mockNostrClient,
            sendPolicy: _denyAllPolicy,
          );

          expect(await service.canSendTo(_recipientPubkey), isTrue);
          expect(await blocked.canSendTo(_recipientPubkey), isFalse);
        },
      );

      test(
        'temporary fail-closed policy denial stays retryable in the drain',
        () async {
          final temporarilyBlocked = NIP17MessageService(
            signer: LocalNostrSigner(_testPrivateKey),
            senderPublicKey: _testPublicKey,
            nostrService: mockNostrClient,
            sendPolicy: _temporarilyDenyPolicy,
          );
          final rumor = temporarilyBlocked.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'wait for account state',
          );

          final result = await temporarilyBlocked.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _recipientPubkey,
          );

          expect(result.success, isFalse);
          expect(result.blocked, isFalse);
          verifyNever(() => mockNostrClient.publishEvent(any()));
        },
      );

      test('default policy allows sending (behavior preserved)', () async {
        when(() => mockNostrClient.publishEvent(any())).thenAnswer(
          (inv) async =>
              PublishSuccess(event: inv.positionalArguments[0] as Event),
        );
        final rumor = service.buildRumor(
          recipientPubkey: _recipientPubkey,
          content: 'allowed',
        );

        final result = await service.sendRumor(
          rumorEvent: rumor,
          recipientPubkey: _recipientPubkey,
        );

        expect(result.success, isTrue);
      });
    });

    group('Keycast policy-denial classification (#6067)', () {
      test(
        'a 403 "operation denied by policy" refusal terminalizes as blocked',
        () async {
          // Keycast's server-side verified_minor gate refuses to sign/encrypt
          // and surfaces as an RpcException whose 403 body carries this
          // marker. A remote signer is not isolate-capable, so sendRumor's
          // _buildWrap goes straight to the injected main-isolate builder;
          // LocalNostrSigner stands in for that not-isolate-capable signer,
          // and the builder raises the refusal. The real RpcException string
          // shape is reproduced so the substring match is tested against the
          // Keycast surface, not a generic Exception.
          final refusing = NIP17MessageService(
            signer: LocalNostrSigner(_testPrivateKey),
            senderPublicKey: _testPublicKey,
            nostrService: mockNostrClient,
            giftWrapBuilder: (_, _, _) async => throw _RpcExceptionDouble(
              'HTTP 403: {"error":"Operation denied by policy"}',
            ),
          );
          final rumor = refusing.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'should terminalize, not retry',
          );

          final result = await refusing.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _recipientPubkey,
          );

          expect(result.blocked, isTrue);
          expect(result.success, isFalse);
          expect(result.retryablePending, isFalse);
          verifyNever(() => mockNostrClient.publishEvent(any()));
        },
      );

      test(
        'a non-policy send error stays a plain failure, not blocked',
        () async {
          final failing = NIP17MessageService(
            signer: LocalNostrSigner(_testPrivateKey),
            senderPublicKey: _testPublicKey,
            nostrService: mockNostrClient,
            giftWrapBuilder: (_, _, _) async =>
                throw _RpcExceptionDouble('HTTP 503: relay unavailable'),
          );
          final rumor = failing.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'transient failure',
          );

          final result = await failing.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _recipientPubkey,
          );

          expect(result.success, isFalse);
          expect(result.blocked, isFalse);
          // Hard, not retryable-pending. Pins that #7092's transient
          // classification stayed narrow: only Keycast's 504 says "I ran out
          // of time and did nothing", and a 503 does not promise that.
          expect(result.retryablePending, isFalse);
        },
      );
    });

    group('Keycast 504 classification (#7092)', () {
      test(
        'a signer that times out itself stays retryable-pending, not red',
        () async {
          // Keycast bounds its own /api/nostr handler at 8s and answers 504
          // (keycast#351). That arrives as an error, not as a Dart
          // TimeoutException, so before #7092 it fell through to the generic
          // hard-failure branch and the user got a red bubble — while the
          // *same* slow signer, if the client's own bound had fired first,
          // produced a dim retryable one. The outcome turned on a race
          // between two bounds. Both are the same event now.
          final timingOut = NIP17MessageService(
            signer: LocalNostrSigner(_testPrivateKey),
            senderPublicKey: _testPublicKey,
            nostrService: mockNostrClient,
            giftWrapBuilder: (_, _, _) async =>
                throw _TransientRpcExceptionDouble(
                  'HTTP 504: {"error":"RPC request timed out after 8s"}',
                ),
          );
          final rumor = timingOut.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'signer gave up before signing',
          );

          final result = await timingOut.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _recipientPubkey,
          );

          expect(result.success, isFalse);
          expect(result.blocked, isFalse);
          expect(result.retryablePending, isTrue);
          // The claim that makes retryable safe: the failure happens while
          // building the wrap, so nothing ever reached a relay and a re-drive
          // cannot double-deliver.
          verifyNever(() => mockNostrClient.publishEvent(any()));
        },
      );

      test('a policy refusal still wins over the transient marker', () async {
        // Ordering guard. A Keycast response could in principle be both a
        // 5xx-shaped transient and carry the verified_minor denial marker;
        // terminalizing must win, because a blocked send re-driven until
        // maxRetries deterministically re-fails (#6028).
        final blocked = NIP17MessageService(
          signer: LocalNostrSigner(_testPrivateKey),
          senderPublicKey: _testPublicKey,
          nostrService: mockNostrClient,
          giftWrapBuilder: (_, _, _) async =>
              throw _TransientRpcExceptionDouble(
                'HTTP 504: {"error":"Operation denied by policy"}',
              ),
        );
        final rumor = blocked.buildRumor(
          recipientPubkey: _recipientPubkey,
          content: 'denial beats transience',
        );

        final result = await blocked.sendRumor(
          rumorEvent: rumor,
          recipientPubkey: _recipientPubkey,
        );

        expect(result.blocked, isTrue);
        expect(result.retryablePending, isFalse);
      });
    });

    group('sendRumor relay targeting', () {
      test(
        'routes the recipient gift wrap to the provided targetRelays',
        () async {
          final captured = <List<String>?>[];
          when(
            () => mockNostrClient.publishEvent(
              any(),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).thenAnswer((invocation) async {
            captured.add(
              invocation.namedArguments[#targetRelays] as List<String>?,
            );
            return PublishSuccess(
              event: invocation.positionalArguments[0] as Event,
            );
          });

          final rumor = service.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'routed message',
          );
          final _ = await service.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _recipientPubkey,
            targetRelays: const ['wss://inbox.example.com'],
          );

          // The first publish is the recipient gift wrap; it must be routed
          // to the recipient's NIP-17 DM inbox relays.
          expect(captured, isNotEmpty);
          expect(captured.first, const ['wss://inbox.example.com']);
        },
      );

      group('self-wrap destination (#7328)', () {
        late NIP17MessageService selfService;
        late List<List<String>?> captured;

        setUp(() {
          // Real curve self key, or the self-addressed wrap never builds and
          // never reaches publishEvent — the module-level placeholder key
          // silently produces a one-publish send and the assertions below
          // would pass against a self-wrap that does not exist.
          selfService = NIP17MessageService(
            signer: LocalNostrSigner(_testPrivateKey),
            senderPublicKey: getPublicKey(_testPrivateKey),
            nostrService: mockNostrClient,
          );
          captured = <List<String>?>[];
          when(
            () => mockNostrClient.publishEvent(
              any(),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).thenAnswer((invocation) async {
            captured.add(
              invocation.namedArguments[#targetRelays] as List<String>?,
            );
            return PublishSuccess(
              event: invocation.positionalArguments[0] as Event,
            );
          });
        });

        Future<NIP17SendResult> send({List<String>? selfWrapTargetRelays}) {
          final rumor = selfService.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'routed message',
          );
          return selfService.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _recipientPubkey,
            targetRelays: const ['wss://inbox.example.com'],
            selfWrapTargetRelays: selfWrapTargetRelays,
          );
        }

        test('routes the self-wrap to its own relay set', () async {
          final result = await send(
            selfWrapTargetRelays: const [
              'wss://relay.divine.video',
              'wss://nos.lol',
            ],
          );

          expect(result.selfWrapPublished, isTrue);
          // Asserted as the whole ordered list, not `captured.first` plus a
          // membership check: the defect is a per-wrap destination, so the
          // only assertion that can catch the self-wrap inheriting the
          // recipient's relays — or losing its own — names both entries.
          expect(captured, hasLength(2));
          expect(captured, [
            const ['wss://inbox.example.com'],
            const ['wss://relay.divine.video', 'wss://nos.lol'],
          ]);
        });

        test(
          'publishes the self-wrap bare when no relay set is supplied',
          () async {
            // The `absent`/`failed` own-inbox outcome. Preserving the bare
            // publish is what keeps an account with no advertised kind-10050
            // on exactly its pre-#7328 behaviour.
            final result = await send();

            expect(result.selfWrapPublished, isTrue);
            expect(captured, hasLength(2));
            expect(captured.last, isNull);
          },
        );

        test('treats an empty relay set as no relay set', () async {
          // A kind-10050 that parsed to zero usable relays must not narrow the
          // publish to nothing — `_sendCollect` skips the filter only when the
          // list is null OR empty, but relying on that coincidence across two
          // packages is how a silent total-loss regression gets in.
          final result = await send(selfWrapTargetRelays: const []);

          expect(result.selfWrapPublished, isTrue);
          expect(captured, hasLength(2));
          expect(captured.last, isNull);
        });
      });
    });

    group('sendRumor awaitRecipientOk (reaction OK-confirm path)', () {
      late NIP17MessageService okService;

      setUp(() {
        // Real curve self key so the self-addressed wrap actually builds and
        // reaches publishEvent (the module-level placeholder key does not).
        okService = NIP17MessageService(
          signer: LocalNostrSigner(_testPrivateKey),
          senderPublicKey: getPublicKey(_testPrivateKey),
          nostrService: mockNostrClient,
        );
      });

      PublishOutcome outcome({
        List<String> accepted = const [],
        Map<String, String> rejected = const {},
        List<String> noResponse = const [],
      }) => PublishOutcome(
        eventId: 'gift-wrap-id',
        acceptedBy: accepted,
        rejectedBy: rejected,
        noResponseFrom: noResponse,
      );

      Future<(NIP17SendResult result, int selfWraps)> sendReaction(
        PublishOutcome recipient,
      ) async {
        when(
          () => mockNostrClient.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => recipient);
        var selfWrapPublishes = 0;
        when(() => mockNostrClient.publishEvent(any())).thenAnswer((inv) async {
          selfWrapPublishes++;
          return PublishSuccess(event: inv.positionalArguments[0] as Event);
        });
        final rumor = okService.buildRumor(
          recipientPubkey: _recipientPubkey,
          content: '🔥',
          eventKind: EventKind.reaction,
        );
        final result = await okService.sendRumor(
          rumorEvent: rumor,
          recipientPubkey: _recipientPubkey,
          awaitRecipientOk: true,
        );
        return (result, selfWrapPublishes);
      }

      test('confirmed OK → success; self-wrap published', () async {
        final (result, selfWraps) = await sendReaction(
          outcome(accepted: const ['wss://relay.example.com']),
        );

        expect(result.success, isTrue);
        expect(result.retryablePending, isFalse);
        expect(result.selfWrapPublished, isTrue);
        expect(selfWraps, 1);
      });

      test(
        'unconfirmed (frame written, no OK) → retryable-pending failure; '
        'self-wrap still published',
        () async {
          final (result, selfWraps) = await sendReaction(
            outcome(noResponse: const ['wss://relay.example.com']),
          );

          expect(result.success, isFalse);
          expect(result.retryablePending, isTrue);
          // Own-device durability must NOT hinge on the recipient's OK.
          expect(selfWraps, 1);
        },
      );

      Future<(NIP17SendResult result, int selfWraps)> sendMessage(
        PublishOutcome recipient, {
        required bool selfWrapOnSoftUnconfirmed,
      }) async {
        when(
          () => mockNostrClient.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => recipient);
        var selfWrapPublishes = 0;
        when(() => mockNostrClient.publishEvent(any())).thenAnswer((inv) async {
          selfWrapPublishes++;
          return PublishSuccess(event: inv.positionalArguments[0] as Event);
        });
        final rumor = okService.buildRumor(
          recipientPubkey: _recipientPubkey,
          content: 'hi',
        );
        final result = await okService.sendRumor(
          rumorEvent: rumor,
          recipientPubkey: _recipientPubkey,
          awaitRecipientOk: true,
          selfWrapOnSoftUnconfirmed: selfWrapOnSoftUnconfirmed,
        );
        return (result, selfWrapPublishes);
      }

      test(
        'unconfirmed MESSAGE send with selfWrapOnSoftUnconfirmed:false → '
        'retryable-pending failure and NO self-wrap (#6046)',
        () async {
          // A soft self-wrap that lands echoes back through the receive
          // pipeline and persists the message as a plain sent row — a
          // sent-looking bubble for a message the recipient may never have
          // received. Message sends therefore defer the self-wrap until the
          // recipient wrap confirms (the durable queue republishes both).
          final (result, selfWraps) = await sendMessage(
            outcome(noResponse: const ['wss://relay.example.com']),
            selfWrapOnSoftUnconfirmed: false,
          );

          expect(result.success, isFalse);
          expect(result.retryablePending, isTrue);
          expect(selfWraps, 0);
          // Kind-aware error string: this is a kind-14 message, and the
          // wording must not claim it was a reaction (misdirected the #6046
          // field debugging).
          expect(result.error, contains('Message recipient OK unconfirmed'));
        },
      );

      test(
        'confirmed MESSAGE send with selfWrapOnSoftUnconfirmed:false still '
        'publishes the self-wrap — the opt-out is scoped to the soft case',
        () async {
          final (result, selfWraps) = await sendMessage(
            outcome(accepted: const ['wss://relay.example.com']),
            selfWrapOnSoftUnconfirmed: false,
          );

          expect(result.success, isTrue);
          expect(result.selfWrapPublished, isTrue);
          expect(selfWraps, 1);
        },
      );

      test(
        'explicit OK-false rejection → hard failure (not retryable-pending); '
        'self-wrap NOT published (recipient definitely did not get it)',
        () async {
          final (result, selfWraps) = await sendReaction(
            outcome(rejected: const {'wss://relay.example.com': 'blocked'}),
          );

          expect(result.success, isFalse);
          expect(result.retryablePending, isFalse);
          // A hard rejection means the recipient never got the reaction.
          // Publishing the self-wrap anyway would surface a phantom reaction
          // on the sender's other devices (ingested as a plain `received` row
          // with no retry metadata), so it must be skipped.
          expect(
            selfWraps,
            0,
            reason:
                'Self-wrap on a rejected send creates a phantom reaction '
                'the recipient never received.',
          );
        },
      );

      test(
        'offline (nothing reached any relay) → non-retryable-pending failure '
        'so the sweep re-drives it immediately; self-wrap NOT published',
        () async {
          // Empty accepted/rejected/noResponse == nothing was sent anywhere.
          final (result, selfWraps) = await sendReaction(outcome());

          expect(result.success, isFalse);
          // Marked failed (not dim pending) so the reconnect sweep re-sends it
          // without the in-flight min-age guard holding it back.
          expect(result.retryablePending, isFalse);
          // Nothing reached a relay, so the recipient has nothing — a self-wrap
          // would be a phantom. The whole rumor is re-driven on reconnect.
          expect(
            selfWraps,
            0,
            reason:
                'Self-wrap while offline creates a phantom reaction on the '
                "sender's other devices.",
          );
        },
      );

      test('a hung connectivity probe cannot stall the send', () {
        // The probe is a raw platform-channel round trip with no timeout, and
        // `_isOfflineSafely`'s try/catch cannot help: a wedged channel is a
        // hang, not a throw. It sits INSIDE the publish backstop, so it spends
        // the cap that exists for a wedged signer (#7091).
        //
        // Fail open to ONLINE on timeout, matching the probe's existing
        // contract that a flaky probe never blocks a send that might succeed.
        final hungProbe = Completer<bool>();
        addTearDown(() {
          if (!hungProbe.isCompleted) hungProbe.complete(false);
        });
        final service = NIP17MessageService(
          signer: LocalNostrSigner(_testPrivateKey),
          senderPublicKey: getPublicKey(_testPrivateKey),
          nostrService: mockNostrClient,
          isOffline: () => hungProbe.future,
        );
        when(() => mockNostrClient.publishEvent(any())).thenAnswer(
          (inv) async =>
              PublishSuccess(event: inv.positionalArguments[0] as Event),
        );

        NIP17SendResult? result;
        fakeAsync((async) {
          unawaited(
            service
                .sendRumor(
                  rumorEvent: service.buildRumor(
                    recipientPubkey: _recipientPubkey,
                    content: 'probe hangs',
                  ),
                  recipientPubkey: _recipientPubkey,
                )
                .then((r) => result = r),
          );
          async.elapse(DmSendBudget.connectivityProbe * 4);
        });

        expect(
          result,
          isNotNull,
          reason: 'a wedged probe must not hold the send open to the backstop',
        );
      });

      test(
        'device offline (probe) → hard failure BEFORE any publish; no '
        'OK-confirm attempt, no self-wrap (#6046)',
        () async {
          // Regression for #6046: on a real device, airplane mode does not
          // flip the relay socket out of ConnectionState.connected
          // synchronously, so publishEventAwaitOk would buffer the frame to a
          // stale-connected socket and time out with noResponseFrom=[relay] —
          // misclassified as soft/pending, leaving the bubble looking sent
          // instead of red. The injected offline probe short-circuits that: no
          // publish is attempted, and the send is a hard failure so the durable
          // queue marks the row failed (red bubble) and the sweep re-drives it.
          final offlineService = NIP17MessageService(
            signer: LocalNostrSigner(_testPrivateKey),
            senderPublicKey: getPublicKey(_testPrivateKey),
            nostrService: mockNostrClient,
            isOffline: () async => true,
          );
          var selfWraps = 0;
          when(() => mockNostrClient.publishEvent(any())).thenAnswer((
            inv,
          ) async {
            selfWraps++;
            return PublishSuccess(event: inv.positionalArguments[0] as Event);
          });

          final rumor = offlineService.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'hi',
          );
          final result = await offlineService.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _recipientPubkey,
            awaitRecipientOk: true,
          );

          expect(result.success, isFalse);
          // Hard failure, not soft-pending: failed rows skip the sweep's
          // in-flight min-age guard and re-drive on the next reconnect.
          expect(result.retryablePending, isFalse);
          expect(result.blocked, isFalse);
          // Offline short-circuits before any relay round-trip: nothing is
          // buffered to a stale socket, so there is no doomed OK-confirm wait…
          verifyNever(
            () => mockNostrClient.publishEventAwaitOk(
              any(),
              timeout: any(named: 'timeout'),
            ),
          );
          // …and no phantom self-wrap on the sender's other devices.
          expect(selfWraps, 0);
        },
      );

      test(
        'probe reports online → unconfirmed send stays soft/retryable-pending '
        '(behaviour unchanged when there IS connectivity) (#6046)',
        () async {
          // The offline guard must NOT fire when the device has connectivity: a
          // genuine "frame written, OK lost" send on a live network is still
          // soft-unconfirmed (a lost OK is not proof of loss). This pins that
          // the guard is scoped to real offline, not any unconfirmed send.
          final onlineService = NIP17MessageService(
            signer: LocalNostrSigner(_testPrivateKey),
            senderPublicKey: getPublicKey(_testPrivateKey),
            nostrService: mockNostrClient,
            isOffline: () async => false,
          );
          when(
            () => mockNostrClient.publishEventAwaitOk(
              any(),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer(
            (_) async => outcome(noResponse: const ['wss://relay.example.com']),
          );
          when(() => mockNostrClient.publishEvent(any())).thenAnswer(
            (
              inv,
            ) async =>
                PublishSuccess(event: inv.positionalArguments[0] as Event),
          );

          final rumor = onlineService.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'hi',
          );
          final result = await onlineService.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _recipientPubkey,
            awaitRecipientOk: true,
          );

          expect(result.success, isFalse);
          expect(result.retryablePending, isTrue);
        },
      );
    });

    group('publishSelfApplicationMarker (#4977)', () {
      setUp(() {
        // The self marker is NIP-44-sealed to the sender's own key, so the
        // sender pubkey must be a real curve point derived from the signing
        // key (the module-level _testPublicKey is a non-curve placeholder).
        service = NIP17MessageService(
          signer: LocalNostrSigner(_testPrivateKey),
          senderPublicKey: getPublicKey(_testPrivateKey),
          nostrService: mockNostrClient,
        );
      });

      test('publishes through the default pool', () async {
        var bareCalls = 0;
        when(() => mockNostrClient.publishEvent(any())).thenAnswer((inv) async {
          bareCalls++;
          return PublishSuccess(event: inv.positionalArguments[0] as Event);
        });

        final ok = await service.publishSelfApplicationMarker(
          content: '{"v":1,"read":{}}',
          tags: const [
            ['d', 'divine/dm-read/v1'],
          ],
        );

        expect(ok, isTrue);
        expect(bareCalls, 1);
      });

      test('returns false when the publish does not succeed', () async {
        when(
          () => mockNostrClient.publishEvent(any()),
        ).thenAnswer((_) async => const PublishNoRelays());

        final ok = await service.publishSelfApplicationMarker(
          content: '{"v":1,"read":{}}',
          tags: const [
            ['d', 'divine/dm-read/v1'],
          ],
        );

        expect(ok, isFalse);
      });

      test('returns false when the gift wrap builder yields null', () async {
        final nullBuilderService = NIP17MessageService(
          signer: LocalNostrSigner(_testPrivateKey),
          senderPublicKey: _testPublicKey,
          nostrService: mockNostrClient,
          giftWrapBuilder: (_, _, _) async => null,
        );

        final ok = await nullBuilderService.publishSelfApplicationMarker(
          content: '{"v":1,"read":{}}',
          tags: const [
            ['d', 'divine/dm-read/v1'],
          ],
        );

        expect(ok, isFalse);
        verifyNever(() => mockNostrClient.publishEvent(any()));
      });

      test(
        'returns false (non-fatal) when the gift wrap builder throws',
        () async {
          final throwingService = NIP17MessageService(
            signer: LocalNostrSigner(_testPrivateKey),
            senderPublicKey: _testPublicKey,
            nostrService: mockNostrClient,
            giftWrapBuilder: (_, _, _) async => throw StateError('boom'),
          );

          final ok = await throwingService.publishSelfApplicationMarker(
            content: '{"v":1,"read":{}}',
            tags: const [
              ['d', 'divine/dm-read/v1'],
            ],
          );

          expect(ok, isFalse);
        },
      );

      test('returns false when the gift wrap build times out', () {
        bool? ok;
        fakeAsync((async) {
          final hangingService = NIP17MessageService(
            signer: LocalNostrSigner(_testPrivateKey),
            senderPublicKey: _testPublicKey,
            nostrService: mockNostrClient,
            giftWrapBuilder: (_, _, _) => Completer<Event?>().future,
          );

          unawaited(
            hangingService
                .publishSelfApplicationMarker(
                  content: '{"v":1,"read":{}}',
                  tags: const [
                    ['d', 'divine/dm-read/v1'],
                  ],
                )
                .then((value) => ok = value),
          );

          async
            ..flushMicrotasks()
            ..elapse(DmSendBudget.selfWrapUncappedBuild * 2)
            ..flushMicrotasks();
        });

        expect(ok, isFalse);
        verifyNever(() => mockNostrClient.publishEvent(any()));
      });
    });

    group('sendPrivateMessage', () {
      test('returns success with gift wrap event details', () async {
        when(() => mockNostrClient.publishEvent(any())).thenAnswer(
          (invocation) async =>
              PublishSuccess(event: invocation.positionalArguments[0] as Event),
        );

        final result = await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'Test message',
        );

        expect(result.success, isTrue);
        expect(result.rumorEventId, isNotNull);
        expect(result.messageEventId, isNotNull);
        expect(result.recipientPubkey, equals(_recipientPubkey));
        expect(result.error, isNull);

        // At least the recipient gift wrap is published; self-wrap may
        // silently fail with synthetic test keys.
        verify(
          () => mockNostrClient.publishEvent(any()),
        ).called(greaterThanOrEqualTo(1));
      });

      test('creates gift wrap with kind 1059', () async {
        Event? capturedEvent;

        when(() => mockNostrClient.publishEvent(any())).thenAnswer((
          invocation,
        ) async {
          capturedEvent = invocation.positionalArguments[0] as Event;
          return PublishSuccess(event: capturedEvent!);
        });

        final _ = await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'Test message',
        );

        expect(capturedEvent, isNotNull);
        expect(capturedEvent!.kind, equals(EventKind.giftWrap));
      });

      test('includes p tag with recipient pubkey', () async {
        Event? capturedEvent;

        when(() => mockNostrClient.publishEvent(any())).thenAnswer((
          invocation,
        ) async {
          capturedEvent = invocation.positionalArguments[0] as Event;
          return PublishSuccess(event: capturedEvent!);
        });

        final _ = await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'Test message',
        );

        expect(capturedEvent, isNotNull);
        final pTags = capturedEvent!.tags.where(
          (tag) => tag.isNotEmpty && tag[0] == 'p',
        );
        expect(pTags, isNotEmpty);
        expect(pTags.first[1], equals(_recipientPubkey));
      });

      test('uses random ephemeral key for each gift wrap', () async {
        final capturedEvents = <Event>[];

        when(() => mockNostrClient.publishEvent(any())).thenAnswer((
          invocation,
        ) async {
          final event = invocation.positionalArguments[0] as Event;
          capturedEvents.add(event);
          return PublishSuccess(event: event);
        });

        final _ = await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'Message 1',
        );
        final _ = await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'Message 2',
        );

        // At least 2 recipient gift wraps (self-wraps may silently fail
        // with synthetic test keys that are not valid EC points).
        expect(capturedEvents.length, greaterThanOrEqualTo(2));
        // First two events are the recipient gift wraps for each message.
        expect(
          capturedEvents[0].pubkey,
          isNot(equals(capturedEvents[1].pubkey)),
        );
        expect(capturedEvents[0].pubkey, isNot(equals(_testPublicKey)));
        expect(capturedEvents[1].pubkey, isNot(equals(_testPublicKey)));
      });

      test('obfuscates timestamp with random offset', () async {
        Event? capturedEvent;

        when(() => mockNostrClient.publishEvent(any())).thenAnswer((
          invocation,
        ) async {
          capturedEvent = invocation.positionalArguments[0] as Event;
          return PublishSuccess(event: capturedEvent!);
        });

        final beforeSend = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final _ = await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'Test message',
        );
        final afterSend = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        expect(capturedEvent, isNotNull);
        final timeDiff = (capturedEvent!.createdAt - beforeSend).abs();
        expect(timeDiff, lessThanOrEqualTo(60 * 60 * 24 * 2));
        expect(capturedEvent!.createdAt, lessThan(afterSend));
      });

      test(
        'returns failure when publish does not return PublishSuccess',
        () async {
          when(
            () => mockNostrClient.publishEvent(any()),
          ).thenAnswer((_) async => const PublishFailed());

          final result = await service.sendPrivateMessage(
            recipientPubkey: _recipientPubkey,
            content: 'Test message',
          );

          expect(result.success, isFalse);
          expect(result.error, contains('publish failed'));
        },
      );

      test('includes additional tags in the gift wrap', () async {
        Event? capturedEvent;

        when(() => mockNostrClient.publishEvent(any())).thenAnswer((
          invocation,
        ) async {
          capturedEvent = invocation.positionalArguments[0] as Event;
          return PublishSuccess(event: capturedEvent!);
        });

        final _ = await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'Test message',
          additionalTags: [
            Nip89ClientTag.tag,
            ['report_id', 'test-123'],
          ],
        );

        expect(capturedEvent, isNotNull);
      });

      test('uses provided eventKind for the rumor', () async {
        when(() => mockNostrClient.publishEvent(any())).thenAnswer(
          (invocation) async =>
              PublishSuccess(event: invocation.positionalArguments[0] as Event),
        );

        final result = await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'https://example.com/file.mp4',
          eventKind: EventKind.fileMessage,
        );

        // The rumor was created with kind 15; the gift wrap is still 1059.
        // We can only verify via the success result since the rumor is
        // encrypted inside the gift wrap.
        expect(result.success, isTrue);
        expect(result.rumorEventId, isNotNull);
      });

      test('returns success with selfWrapPublished=false when self-wrap '
          'publish throws (recipient delivered, sender will not see this '
          'message on other devices)', () async {
        var callCount = 0;
        when(() => mockNostrClient.publishEvent(any())).thenAnswer((
          invocation,
        ) async {
          callCount++;
          if (callCount == 1) {
            return PublishSuccess(
              event: invocation.positionalArguments[0] as Event,
            );
          }
          throw Exception('self-wrap relay error');
        });

        final result = await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'Test message',
        );

        expect(result.success, isTrue);
        expect(result.rumorEventId, isNotNull);
        expect(
          result.selfWrapPublished,
          isFalse,
          reason:
              'Self-wrap throws were silently swallowed before; the '
              'result must now reflect that the sender will not see '
              'this message on other devices until the self-wrap is '
              're-published (#3909 tracks the future retry path).',
        );
      });

      test('emits info log "Successfully published NIP-17 message '
          '(selfWrapPublished=false)" when self-wrap publish throws', () async {
        // Closes the gap from PR #3910's manual-verification checklist:
        // the reviewer asked for a real-device confirmation that this
        // exact log line fires on partial delivery (Keycast RPC slow ->
        // self-wrap second sign throws). Captured deterministically here
        // so CI guards against future drift in the log copy.
        await LogCaptureService().clearAllLogs();

        var callCount = 0;
        when(() => mockNostrClient.publishEvent(any())).thenAnswer((
          invocation,
        ) async {
          callCount++;
          if (callCount == 1) {
            return PublishSuccess(
              event: invocation.positionalArguments[0] as Event,
            );
          }
          throw Exception('keycast rpc timeout');
        });

        final _ = await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'Test message',
        );

        final logs = LogCaptureService().getRecentLogs();
        expect(
          logs.any(
            (e) =>
                e.level == LogLevel.info &&
                e.message ==
                    'Successfully published NIP-17 message '
                        '(selfWrapPublished=false)',
          ),
          isTrue,
          reason:
              'Diagnostic log copy for production triage of partial '
              'delivery. Not a load-bearing contract — the durable '
              'outgoing-DM queue (#3909) keys off '
              'NIP17SendResult.selfWrapPublished, not this string.',
        );
      });

      test('returns success with selfWrapPublished=false '
          'when self-wrap publish returns PublishFailed', () async {
        final signer = LocalNostrSigner(_testPrivateKey);
        final senderPublicKey = (await signer.getPublicKey())!;
        final matchingService = NIP17MessageService(
          signer: signer,
          senderPublicKey: senderPublicKey,
          nostrService: mockNostrClient,
        );
        var callCount = 0;
        when(() => mockNostrClient.publishEvent(any())).thenAnswer((
          invocation,
        ) async {
          callCount++;
          if (callCount == 1) {
            return PublishSuccess(
              event: invocation.positionalArguments[0] as Event,
            );
          }
          return const PublishFailed();
        });

        final result = await matchingService.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'Test message',
        );

        expect(result.success, isTrue);
        expect(result.rumorEventId, isNotNull);
        expect(result.selfWrapPublished, isFalse);
      });

      test('returns success with selfWrapPublished=false '
          'when self-wrap publish returns PublishNoRelays', () async {
        final signer = LocalNostrSigner(_testPrivateKey);
        final senderPublicKey = (await signer.getPublicKey())!;
        final matchingService = NIP17MessageService(
          signer: signer,
          senderPublicKey: senderPublicKey,
          nostrService: mockNostrClient,
        );
        var callCount = 0;
        when(() => mockNostrClient.publishEvent(any())).thenAnswer((
          invocation,
        ) async {
          callCount++;
          if (callCount == 1) {
            return PublishSuccess(
              event: invocation.positionalArguments[0] as Event,
            );
          }
          return const PublishNoRelays();
        });

        final result = await matchingService.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'Test message',
        );

        expect(result.success, isTrue);
        expect(result.rumorEventId, isNotNull);
        expect(result.selfWrapPublished, isFalse);
      });

      test(
        'returns success with selfWrapPublished=false when self-wrap '
        'publish returns PublishFailed (relay rejected with no exception)',
        () async {
          var callCount = 0;
          when(() => mockNostrClient.publishEvent(any())).thenAnswer((
            invocation,
          ) async {
            callCount++;
            if (callCount == 1) {
              return PublishSuccess(
                event: invocation.positionalArguments[0] as Event,
              );
            }
            return const PublishFailed();
          });

          final result = await service.sendPrivateMessage(
            recipientPubkey: _recipientPubkey,
            content: 'Test message',
          );

          expect(result.success, isTrue);
          expect(result.selfWrapPublished, isFalse);
        },
      );

      test(
        'publishes a self-wrap with selfWrapPublished=true '
        'when sender pubkey matches the signer and publish succeeds',
        () async {
          final signer = LocalNostrSigner(_testPrivateKey);
          final senderPublicKey = (await signer.getPublicKey())!;
          final capturedEvents = <Event>[];

          final matchingService = NIP17MessageService(
            signer: signer,
            senderPublicKey: senderPublicKey,
            nostrService: mockNostrClient,
          );

          when(() => mockNostrClient.publishEvent(any())).thenAnswer((
            invocation,
          ) async {
            final event = invocation.positionalArguments[0] as Event;
            capturedEvents.add(event);
            return PublishSuccess(event: event);
          });

          final result = await matchingService.sendPrivateMessage(
            recipientPubkey: _recipientPubkey,
            content: 'Test message',
          );

          expect(result.success, isTrue);
          expect(result.selfWrapPublished, isTrue);
          expect(capturedEvents, hasLength(2));
          expect(capturedEvents[0].kind, EventKind.giftWrap);
          expect(capturedEvents[1].kind, EventKind.giftWrap);
        },
      );

      group('with sender pubkey derived from signer key', () {
        // Existing tests use a synthetic _testPublicKey that is not a
        // valid secp256k1 point, so the self-wrap's NIP-44 ECDH throws
        // before reaching the publish call. These tests pair the signer
        // with a sender pubkey actually derived from its private key, so
        // the self-wrap path runs end-to-end and the publish/build-side
        // branches are exercised.
        late NIP17MessageService realKeyService;

        setUp(() {
          realKeyService = NIP17MessageService(
            signer: LocalNostrSigner(_testPrivateKey),
            senderPublicKey: getPublicKey(_testPrivateKey),
            nostrService: mockNostrClient,
          );
        });

        test(
          'returns selfWrapPublished=true when both publishes succeed',
          () async {
            when(() => mockNostrClient.publishEvent(any())).thenAnswer(
              (invocation) async => PublishSuccess(
                event: invocation.positionalArguments[0] as Event,
              ),
            );

            final result = await realKeyService.sendPrivateMessage(
              recipientPubkey: _recipientPubkey,
              content: 'Test message',
            );

            expect(result.success, isTrue);
            expect(result.selfWrapPublished, isTrue);
            verify(() => mockNostrClient.publishEvent(any())).called(2);
          },
        );

        test('emits info log "Successfully published NIP-17 message '
            '(selfWrapPublished=true)" when both publishes succeed', () async {
          await LogCaptureService().clearAllLogs();

          when(() => mockNostrClient.publishEvent(any())).thenAnswer(
            (invocation) async => PublishSuccess(
              event: invocation.positionalArguments[0] as Event,
            ),
          );

          final _ = await realKeyService.sendPrivateMessage(
            recipientPubkey: _recipientPubkey,
            content: 'Test message',
          );

          final logs = LogCaptureService().getRecentLogs();
          expect(
            logs.any(
              (e) =>
                  e.level == LogLevel.info &&
                  e.message ==
                      'Successfully published NIP-17 message '
                          '(selfWrapPublished=true)',
            ),
            isTrue,
            reason:
                'Diagnostic log copy for production triage. Symmetric '
                'with the partial-delivery log assertion above; neither '
                'is a contract the outgoing queue (#3909) keys off — '
                'the queue keys off NIP17SendResult.selfWrapPublished.',
          );
        });

        test('returns selfWrapPublished=false when self-wrap publish '
            'returns PublishFailed without throwing', () async {
          var callCount = 0;
          when(() => mockNostrClient.publishEvent(any())).thenAnswer((
            invocation,
          ) async {
            callCount++;
            if (callCount == 1) {
              return PublishSuccess(
                event: invocation.positionalArguments[0] as Event,
              );
            }
            return const PublishFailed();
          });

          final result = await realKeyService.sendPrivateMessage(
            recipientPubkey: _recipientPubkey,
            content: 'Test message',
          );

          expect(result.success, isTrue);
          expect(result.selfWrapPublished, isFalse);
          verify(() => mockNostrClient.publishEvent(any())).called(2);
        });

        test('returns selfWrapPublished=false when self-wrap event '
            'creation returns null (defensive null-event branch)', () async {
          var builderCalls = 0;
          final service = NIP17MessageService(
            signer: LocalNostrSigner(_testPrivateKey),
            senderPublicKey: getPublicKey(_testPrivateKey),
            nostrService: mockNostrClient,
            giftWrapBuilder: (nostr, rumor, recipientPubkey) async {
              builderCalls++;
              if (builderCalls == 1) {
                return GiftWrapUtil.getGiftWrapEvent(
                  nostr,
                  rumor,
                  recipientPubkey,
                );
              }
              return null;
            },
          );

          when(() => mockNostrClient.publishEvent(any())).thenAnswer(
            (invocation) async => PublishSuccess(
              event: invocation.positionalArguments[0] as Event,
            ),
          );

          final result = await service.sendPrivateMessage(
            recipientPubkey: _recipientPubkey,
            content: 'Test message',
          );

          expect(result.success, isTrue);
          expect(result.selfWrapPublished, isFalse);
          expect(
            builderCalls,
            equals(2),
            reason:
                'Both the recipient wrap and the self-wrap go through '
                'the injected builder; the second call returning null '
                'is what we are exercising here.',
          );
          verify(() => mockNostrClient.publishEvent(any())).called(1);
        });

        test(
          'returns selfWrapPublished=false when self-wrap builder '
          'throws (decoupled from SDK internals via injection seam)',
          () async {
            var builderCalls = 0;
            final service = NIP17MessageService(
              signer: LocalNostrSigner(_testPrivateKey),
              senderPublicKey: getPublicKey(_testPrivateKey),
              nostrService: mockNostrClient,
              giftWrapBuilder: (nostr, rumor, recipientPubkey) async {
                builderCalls++;
                if (builderCalls == 1) {
                  return GiftWrapUtil.getGiftWrapEvent(
                    nostr,
                    rumor,
                    recipientPubkey,
                  );
                }
                throw Exception('builder boom');
              },
            );

            when(() => mockNostrClient.publishEvent(any())).thenAnswer(
              (invocation) async => PublishSuccess(
                event: invocation.positionalArguments[0] as Event,
              ),
            );

            final result = await service.sendPrivateMessage(
              recipientPubkey: _recipientPubkey,
              content: 'Test message',
            );

            expect(result.success, isTrue);
            expect(result.selfWrapPublished, isFalse);
            expect(builderCalls, equals(2));
            verify(() => mockNostrClient.publishEvent(any())).called(1);
          },
        );
      });

      test('returns failure when signer throws during key refresh', () async {
        final mockSigner = _MockNostrSigner();
        when(
          mockSigner.getPublicKey,
        ).thenThrow(Exception('signer unavailable'));

        final brokenService = NIP17MessageService(
          signer: mockSigner,
          senderPublicKey: _testPublicKey,
          nostrService: mockNostrClient,
        );

        final result = await brokenService.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'Test message',
        );

        expect(result.success, isFalse);
        expect(result.error, isNotNull);
      });
    });

    group('buildRumor + sendRumor split', () {
      test('buildRumor returns the unsigned rumor event without touching '
          'the relay or signer', () async {
        final rumor = service.buildRumor(
          recipientPubkey: _recipientPubkey,
          content: 'queue this before publishing',
        );

        expect(rumor.kind, equals(EventKind.privateDirectMessage));
        expect(rumor.content, equals('queue this before publishing'));
        expect(rumor.pubkey, equals(_testPublicKey));
        expect(
          rumor.tags.first,
          equals(['p', _recipientPubkey]),
          reason: 'p-tag must be the first tag for NIP-17 compliance',
        );
        expect(
          rumor.id,
          isNotEmpty,
          reason:
              'Event constructor computes the rumor id deterministically '
              'from its fields — DmRepository keys the queue row by it',
        );
        // No publish should fire from a pure build call.
        verifyNever(() => mockNostrClient.publishEvent(any()));
      });

      test('sendRumor wraps and publishes a pre-built rumor with the same '
          'rumor id as buildRumor returned', () async {
        when(() => mockNostrClient.publishEvent(any())).thenAnswer(
          (invocation) async =>
              PublishSuccess(event: invocation.positionalArguments[0] as Event),
        );

        final rumor = service.buildRumor(
          recipientPubkey: _recipientPubkey,
          content: 'split-flow message',
        );
        final rumorIdBeforeSend = rumor.id;

        final result = await service.sendRumor(
          rumorEvent: rumor,
          recipientPubkey: _recipientPubkey,
        );

        expect(result.success, isTrue);
        expect(
          result.rumorEventId,
          equals(rumorIdBeforeSend),
          reason:
              'sendRumor must surface the same rumor id the caller saw '
              'from buildRumor — the queue row PK depends on this',
        );
        expect(result.recipientPubkey, equals(_recipientPubkey));
      });

      test('buildRumor includes additional tags after the recipient p-tag', () {
        final rumor = service.buildRumor(
          recipientPubkey: _recipientPubkey,
          content: 'reply test',
          additionalTags: [
            ['e', 'parent-message-id'],
          ],
        );

        expect(rumor.tags, [
          ['p', _recipientPubkey],
          ['e', 'parent-message-id'],
        ]);
      });

      test('buildRumor honors a non-default eventKind so kind 15 file '
          'messages can be enqueued before publishing', () {
        final rumor = service.buildRumor(
          recipientPubkey: _recipientPubkey,
          content: 'https://example.com/file.enc',
          eventKind: EventKind.fileMessage,
        );

        expect(rumor.kind, equals(EventKind.fileMessage));
      });

      test('sendPrivateMessage convenience wrapper still works (delegates '
          'to buildRumor + sendRumor)', () async {
        when(() => mockNostrClient.publishEvent(any())).thenAnswer(
          (invocation) async =>
              PublishSuccess(event: invocation.positionalArguments[0] as Event),
        );

        final result = await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'convenience-wrapper smoke test',
        );

        expect(result.success, isTrue);
        expect(result.rumorEventId, isNotNull);
      });

      test(
        'sendPrivateMessage forwards target relay confirmation options',
        () async {
          const targetRelays = ['wss://relay.nos.social'];
          when(
            () => mockNostrClient.publishEventAwaitOk(
              any(),
              targetRelays: any(named: 'targetRelays'),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer(
            (_) async => const PublishOutcome(
              eventId: 'gift-wrap-id',
              acceptedBy: ['wss://relay.nos.social'],
              rejectedBy: {},
              noResponseFrom: [],
            ),
          );
          when(() => mockNostrClient.publishEvent(any())).thenAnswer(
            (invocation) async => PublishSuccess(
              event: invocation.positionalArguments[0] as Event,
            ),
          );

          final result = await service.sendPrivateMessage(
            recipientPubkey: _recipientPubkey,
            content: 'targeted message',
            targetRelays: targetRelays,
            awaitRecipientOk: true,
            selfWrapOnSoftUnconfirmed: false,
          );

          expect(result.success, isTrue);
          verify(
            () => mockNostrClient.publishEventAwaitOk(
              any(),
              targetRelays: targetRelays,
              timeout: any(named: 'timeout'),
            ),
          ).called(1);
        },
      );
    });

    group('buildGroupRumor (#8188)', () {
      const peerB =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      const peerC =
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
      const peerA =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

      test('carries every recipient as a p tag', () {
        final rumor = service.buildGroupRumor(
          recipientPubkeys: const [peerC, peerA, peerB],
          content: 'hi all',
        );

        expect(
          rumor.tags.where((t) => t.first == 'p').map((t) => t[1]).toSet(),
          {peerA, peerB, peerC},
        );
      });

      test('orders p tags canonically, so the id ignores argument order', () {
        // Two callers listing the same room in different orders must produce
        // the SAME message identity — otherwise the id depends on an
        // incidental argument order.
        final one = service.buildGroupRumor(
          recipientPubkeys: const [peerC, peerA, peerB],
          content: 'hi all',
          createdAt: 1700000000,
        );
        final two = service.buildGroupRumor(
          recipientPubkeys: const [peerA, peerB, peerC],
          content: 'hi all',
          createdAt: 1700000000,
        );

        expect(
          one.tags.where((t) => t.first == 'p').map((t) => t[1]).toList(),
          [peerA, peerB, peerC],
        );
        expect(one.id, equals(two.id));
      });

      test(
        'is ONE byte-identical rumor for the whole fan-out, unlike a '
        'per-recipient buildRumor',
        () {
          const room = [peerA, peerB, peerC];

          // What sendGroupMessage used to do: buildRumor once per recipient,
          // which prepends the addressee and so rotates the p-tag order.
          final perRecipient = [
            for (final me in room)
              service.buildRumor(
                recipientPubkey: me,
                content: 'hi all',
                additionalTags: [
                  for (final other in room)
                    if (other != me) ['p', other],
                ],
                createdAt: 1700000000,
              ),
          ];
          expect(
            perRecipient.map((r) => r.id).toSet(),
            hasLength(3),
            reason:
                'the old shape forked the id — this is the bug, pinned so '
                'the contrast stays visible',
          );

          // What it does now: one rumor, wrapped N times (NIP-59 59.md:108).
          final shared = service.buildGroupRumor(
            recipientPubkeys: room,
            content: 'hi all',
            createdAt: 1700000000,
          );
          expect(
            List.generate(room.length, (_) => shared.id).toSet(),
            hasLength(1),
          );
        },
      );

      test('appends additionalTags after the p tags and keeps the kind', () {
        final rumor = service.buildGroupRumor(
          recipientPubkeys: const [peerB, peerA],
          content: '',
          eventKind: EventKind.fileMessage,
          additionalTags: const [
            ['e', 'parent'],
            ['batch', 'token'],
          ],
        );

        expect(rumor.kind, EventKind.fileMessage);
        expect(rumor.tags.last, ['batch', 'token']);
        expect(rumor.tags.map((t) => t.first).toList(), [
          'p',
          'p',
          'e',
          'batch',
        ]);
      });
    });

    group('publishSelfWrap', () {
      // The recovery primitive: re-publish only the sender
      // self-addressed gift wrap for a rumor whose recipient publish
      // already landed. The full sendRumor path would publish a second
      // recipient wrap and double-deliver — these tests pin that
      // publishSelfWrap never builds or publishes the recipient wrap.
      late NIP17MessageService realKeyService;

      setUp(() {
        // Use a sender pubkey derived from the signer so the self-wrap
        // NIP-44 ECDH actually runs end-to-end (the synthetic
        // _testPublicKey is not a valid secp256k1 point).
        realKeyService = NIP17MessageService(
          signer: LocalNostrSigner(_testPrivateKey),
          senderPublicKey: getPublicKey(_testPrivateKey),
          nostrService: mockNostrClient,
        );
      });

      test('returns success when the self-wrap publish succeeds and '
          'never publishes a recipient wrap', () async {
        final captured = <Event>[];
        when(() => mockNostrClient.publishEvent(any())).thenAnswer((
          invocation,
        ) async {
          final event = invocation.positionalArguments[0] as Event;
          captured.add(event);
          return PublishSuccess(event: event);
        });

        final rumor = realKeyService.buildRumor(
          recipientPubkey: _recipientPubkey,
          content: 'recovery smoke test',
        );

        final result = await realKeyService.publishSelfWrap(rumorEvent: rumor);

        expect(result.success, isTrue);
        expect(result.selfWrapPublished, isTrue);
        expect(
          result.rumorEventId,
          equals(rumor.id),
          reason:
              'rumor id must be preserved across recovery — receiver-side '
              'gift-wrap dedup keys on it',
        );
        expect(
          result.recipientPubkey,
          equals(getPublicKey(_testPrivateKey)),
          reason:
              'recovery republishes a self-addressed wrap; the result '
              "exposes the sender's pubkey in the recipientPubkey slot",
        );
        expect(
          captured,
          hasLength(1),
          reason:
              'publishSelfWrap must NOT republish the recipient wrap — '
              'doing so would double-deliver the message',
        );
        expect(captured.single.kind, equals(EventKind.giftWrap));
      });

      test('returns failure when the self-wrap publish returns '
          'PublishFailed without throwing', () async {
        when(
          () => mockNostrClient.publishEvent(any()),
        ).thenAnswer((_) async => const PublishFailed());

        final rumor = realKeyService.buildRumor(
          recipientPubkey: _recipientPubkey,
          content: 'PublishFailed path',
        );

        final result = await realKeyService.publishSelfWrap(rumorEvent: rumor);

        expect(result.success, isFalse);
        expect(result.error, isNotNull);
        expect(result.selfWrapPublished, isNull);
        verify(() => mockNostrClient.publishEvent(any())).called(1);
      });

      test('returns failure when the gift-wrap builder returns null', () async {
        final nullBuilderService = NIP17MessageService(
          signer: LocalNostrSigner(_testPrivateKey),
          senderPublicKey: getPublicKey(_testPrivateKey),
          nostrService: mockNostrClient,
          giftWrapBuilder: (_, _, _) async => null,
        );

        final rumor = nullBuilderService.buildRumor(
          recipientPubkey: _recipientPubkey,
          content: 'null builder path',
        );

        final result = await nullBuilderService.publishSelfWrap(
          rumorEvent: rumor,
        );

        expect(result.success, isFalse);
        expect(result.error, isNotNull);
        verifyNever(() => mockNostrClient.publishEvent(any()));
      });

      test(
        'sendRumor fails, and publishes nothing, when the signer declines to '
        'sign the seal',
        () async {
          // End-to-end through the REAL GiftWrapUtil: a declining signer used
          // to yield a seal with an empty sig, wrapped under a valid ephemeral
          // key, which relays accepted and the caller recorded as delivered —
          // while every recipient dropped it. The send must fail instead, so
          // the durable queue row survives and the sweep re-drives it.
          final decliningService = NIP17MessageService(
            signer: _RefusesToSignSigner(LocalNostrSigner(_testPrivateKey)),
            senderPublicKey: getPublicKey(_testPrivateKey),
            nostrService: mockNostrClient,
          );

          final rumor = decliningService.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'must not ship unsigned',
          );

          final result = await decliningService.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _recipientPubkey,
          );

          expect(result.success, isFalse);
          expect(result.error, isNotNull);
          verifyNever(() => mockNostrClient.publishEvent(any()));
          verifyNever(
            () => mockNostrClient.publishEventAwaitOk(
              any(),
              timeout: any(named: 'timeout'),
            ),
          );
        },
      );

      test('returns failure when the gift-wrap builder throws', () async {
        final throwingBuilderService = NIP17MessageService(
          signer: LocalNostrSigner(_testPrivateKey),
          senderPublicKey: getPublicKey(_testPrivateKey),
          nostrService: mockNostrClient,
          giftWrapBuilder: (_, _, _) async {
            throw Exception('builder boom');
          },
        );

        final rumor = throwingBuilderService.buildRumor(
          recipientPubkey: _recipientPubkey,
          content: 'throwing builder path',
        );

        final result = await throwingBuilderService.publishSelfWrap(
          rumorEvent: rumor,
        );

        expect(result.success, isFalse);
        expect(result.error, isNotNull);
        verifyNever(() => mockNostrClient.publishEvent(any()));
      });

      test(
        'returns failure when the signer throws during key refresh',
        () async {
          final mockSigner = _MockNostrSigner();
          when(
            mockSigner.getPublicKey,
          ).thenThrow(Exception('signer unavailable'));

          final brokenService = NIP17MessageService(
            signer: mockSigner,
            senderPublicKey: _testPublicKey,
            nostrService: mockNostrClient,
          );

          final rumor = realKeyService.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'signer-key-failure path',
          );

          final result = await brokenService.publishSelfWrap(rumorEvent: rumor);

          expect(result.success, isFalse);
          expect(result.error, isNotNull);
          verifyNever(() => mockNostrClient.publishEvent(any()));
        },
      );
    });

    group('gift-wrap build offload (#5391)', () {
      late String localPrivateKey;
      late String localPubkey;

      setUp(() {
        localPrivateKey = generatePrivateKey();
        localPubkey = getPublicKey(localPrivateKey);
        when(() => mockNostrClient.publishEvent(any())).thenAnswer(
          (inv) async =>
              PublishSuccess(event: inv.positionalArguments[0] as Event),
        );
      });

      test(
        'local-key signer builds wraps via the isolate seam, not the main '
        'builder',
        () async {
          var mainBuilderCalls = 0;
          var isolateSeamCalls = 0;

          final service = NIP17MessageService(
            signer: _LocalIsolateSigner(localPrivateKey),
            senderPublicKey: localPubkey,
            nostrService: mockNostrClient,
            giftWrapBuilder: (nostr, rumor, recipient) async {
              mainBuilderCalls++;
              return null;
            },
            isolateGiftWrapBatchBuilder: (request) {
              isolateSeamCalls++;
              // Build inline (no real isolate) — exercises the same worker.
              return buildGiftWrapBatch(request);
            },
          );

          final rumor = service.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'via isolate',
          );
          final result = await service.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _recipientPubkey,
          );

          expect(result.success, isTrue);
          // One combined batch hop builds both the recipient and self wraps.
          expect(isolateSeamCalls, equals(1));
          expect(mainBuilderCalls, equals(0));
        },
      );

      test(
        'remote signer builds wraps on the main isolate, never the isolate '
        'seam',
        () async {
          var mainBuilderCalls = 0;
          var isolateSeamCalls = 0;

          final remoteSigner = _MockNostrSigner();
          when(remoteSigner.getPublicKey).thenAnswer((_) async => localPubkey);

          final service = NIP17MessageService(
            signer: remoteSigner,
            senderPublicKey: localPubkey,
            nostrService: mockNostrClient,
            giftWrapBuilder: (nostr, rumor, recipient) async {
              mainBuilderCalls++;
              return Event(localPubkey, EventKind.giftWrap, [
                ['p', recipient],
              ], 'ciphertext');
            },
            isolateGiftWrapBatchBuilder: (request) async {
              isolateSeamCalls++;
              return const <BuiltGiftWrapResult>[];
            },
          );

          final rumor = service.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'via main isolate',
          );
          final result = await service.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _recipientPubkey,
          );

          expect(result.success, isTrue);
          expect(mainBuilderCalls, equals(2));
          expect(isolateSeamCalls, equals(0));
        },
      );

      test(
        'batch builder throws falls back to single-receiver isolate path '
        'for recipient and self-wrap',
        () async {
          var batchCalls = 0;
          final service = NIP17MessageService(
            signer: _LocalIsolateSigner(localPrivateKey),
            senderPublicKey: localPubkey,
            nostrService: mockNostrClient,
            isolateGiftWrapBatchBuilder: (request) {
              batchCalls++;
              if (request.receiverPublicKeys.length == 2) {
                throw Exception('batch boom');
              }
              // Single-receiver call from _buildWrap fallback — succeed.
              return buildGiftWrapBatch(request);
            },
          );

          final rumor = service.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'batch-throw fallback',
          );
          final result = await service.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _recipientPubkey,
          );

          expect(result.success, isTrue);
          // 1 batch (throws) + 1 single-receiver for recipient + 1 for self.
          expect(batchCalls, equals(3));
        },
      );

      test(
        'batch builder reports self-wrap slot failure triggers _buildWrap '
        'for the self-wrap lazily',
        () async {
          final service = NIP17MessageService(
            signer: _LocalIsolateSigner(localPrivateKey),
            senderPublicKey: localPubkey,
            nostrService: mockNostrClient,
            isolateGiftWrapBatchBuilder: (request) async {
              final all = await buildGiftWrapBatch(request);
              if (request.receiverPublicKeys.length == 2) {
                // Recipient succeeds; self-wrap slot reports failure.
                return [
                  all[0],
                  const BuiltGiftWrapResult.failure('self-wrap slot failed'),
                ];
              }
              return all;
            },
          );

          final rumor = service.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'self-wrap-slot-failure',
          );
          final result = await service.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _recipientPubkey,
          );

          expect(result.success, isTrue);
          expect(result.selfWrapPublished, isTrue);
        },
      );

      test(
        'single-receiver slot failure does not rebuild on the main isolate',
        () async {
          var mainBuilderCalls = 0;
          final service = NIP17MessageService(
            signer: _LocalIsolateSigner(localPrivateKey),
            senderPublicKey: localPubkey,
            nostrService: mockNostrClient,
            giftWrapBuilder: (nostr, rumor, recipient) async {
              mainBuilderCalls++;
              return Event(localPubkey, EventKind.giftWrap, [
                ['p', recipient],
              ], 'ciphertext');
            },
            isolateGiftWrapBatchBuilder: (_) async => const [
              BuiltGiftWrapResult.failure('deterministic local crypto'),
            ],
          );

          final rumor = service.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'single-slot-failure',
          );
          final result = await service.publishSelfWrap(rumorEvent: rumor);

          expect(result.success, isFalse);
          expect(mainBuilderCalls, equals(0));
          verifyNever(() => mockNostrClient.publishEvent(any()));
        },
      );

      test(
        'batch builder reports recipient slot failure causes sendRumor to '
        'return failure without rebuilding on the main isolate',
        () async {
          // #8534: the branch deliberately does NOT fall back. Both builders
          // derive the conversation key from the same recipient pubkey via
          // `NIP44V2.shareSecret`, so a rebuild fails identically; spending
          // one is pure cost. The zero-main-builder assertion is the point of
          // this test — without it, making the branch fall back would leave
          // it green, which is how the log line and the code disagreed for
          // two months.
          // Counting seam calls, not main-builder calls: a fall-through would
          // reach [_buildWrap], which retries the isolate with ONE receiver
          // and would succeed against this fake — so `giftWrapBuilder` would
          // never run and a main-builder counter would read zero in both
          // worlds. The receiver-count sequence is what distinguishes them.
          final seamReceiverCounts = <int>[];
          final service = NIP17MessageService(
            signer: _LocalIsolateSigner(localPrivateKey),
            senderPublicKey: localPubkey,
            nostrService: mockNostrClient,
            isolateGiftWrapBatchBuilder: (request) async {
              seamReceiverCounts.add(request.receiverPublicKeys.length);
              final all = await buildGiftWrapBatch(request);
              if (request.receiverPublicKeys.length == 2) {
                // Recipient slot fails; self-wrap slot succeeds.
                return [
                  const BuiltGiftWrapResult.failure('recipient slot failed'),
                  all[1],
                ];
              }
              return all;
            },
          );

          final rumor = service.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'recipient-slot-failure',
          );
          final result = await service.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _recipientPubkey,
          );

          expect(result.success, isFalse);
          expect(
            seamReceiverCounts,
            equals([2]),
            reason:
                'no per-receiver rebuild may follow a failed recipient slot',
          );
          verifyNever(() => mockNostrClient.publishEvent(any()));
        },
      );

      test(
        'batch builder returning the wrong slot count DOES rebuild on the '
        'main isolate',
        () async {
          // The contrast to the test above, and the branch whose "falling
          // back" log is accurate. Unexercised before #8534: the only
          // empty-list fake in this file sat behind a remote signer and was
          // never invoked, so nothing pinned that these two adjacent branches
          // behave differently on purpose.
          // Fall-through is observable as a SECOND seam call carrying one
          // receiver: the tail calls [_buildWrap], which prefers the isolate
          // for a single receiver and only reaches `giftWrapBuilder` if that
          // also fails. So counting main-builder calls would read zero here
          // even though the fallback ran — the receiver-count sequence is
          // what actually proves it.
          final seamReceiverCounts = <int>[];
          final service = NIP17MessageService(
            signer: _LocalIsolateSigner(localPrivateKey),
            senderPublicKey: localPubkey,
            nostrService: mockNostrClient,
            isolateGiftWrapBatchBuilder: (request) async {
              seamReceiverCounts.add(request.receiverPublicKeys.length);
              final all = await buildGiftWrapBatch(request);
              if (request.receiverPublicKeys.length == 2) {
                // One slot for a two-receiver request: misshapen, so the
                // batch attempt is abandoned rather than partially trusted.
                return [all.first];
              }
              return all;
            },
          );

          final rumor = service.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'wrong-slot-count',
          );
          final result = await service.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _recipientPubkey,
          );

          expect(result.success, isTrue);
          expect(seamReceiverCounts.first, equals(2));
          expect(
            seamReceiverCounts.skip(1),
            contains(1),
            reason: 'the abandoned batch must be retried per-receiver',
          );
        },
      );

      test(
        'uses compute() isolate by default when no isolateGiftWrapBatchBuilder '
        'is injected (covers the _computeGiftWrapBatch static method)',
        () async {
          // No isolateGiftWrapBatchBuilder injection — exercises the default
          // _computeGiftWrapBatch static tear-off that calls compute().
          final realIsolateService = NIP17MessageService(
            signer: _LocalIsolateSigner(localPrivateKey),
            senderPublicKey: localPubkey,
            nostrService: mockNostrClient,
          );

          final result = await realIsolateService.sendPrivateMessage(
            recipientPubkey: _recipientPubkey,
            content: 'real compute isolate test',
          );

          expect(result.success, isTrue);
        },
      );
    });

    // #7090. A remote signer pays nip44Encrypt + signEvent per NIP-59 wrap —
    // four round trips for a 1:1 send once the NIP-17 self copy is counted.
    // Keycast's `nip17_wrap_batch` builds every recipient's seal and wrap
    // server-side, collapsing that to one. The verb is optional, so every
    // failure mode has to land back on the existing per-wrap path.
    group('server-side gift-wrap batch (#7090)', () {
      late String localPrivateKey;
      late String localPubkey;

      setUp(() {
        localPrivateKey = generatePrivateKey();
        localPubkey = getPublicKey(localPrivateKey);
        when(() => mockNostrClient.publishEvent(any())).thenAnswer(
          (inv) async =>
              PublishSuccess(event: inv.positionalArguments[0] as Event),
        );
      });

      Map<String, dynamic> wrapFor(
        String recipient, {
        int kind = EventKind.giftWrap,
        bool sign = true,
      }) {
        final privateKey = generatePrivateKey();
        final event = Event(
          getPublicKey(privateKey),
          kind,
          [
            ['p', recipient],
          ],
          'ciphertext-$recipient',
        );
        if (sign) event.sign(privateKey);
        return event.toJson();
      }

      test(
        'one batch call replaces both per-wrap signing round trips',
        () async {
          final signer = _BatchWrapSigner(
            localPrivateKey,
            onBatch: (rumor, recipients) async => [
              GiftWrapSlot.success(wrapFor(recipients[0])),
              GiftWrapSlot.success(wrapFor(recipients[1])),
            ],
          );
          var mainBuilderCalls = 0;

          final service = NIP17MessageService(
            signer: signer,
            senderPublicKey: localPubkey,
            nostrService: mockNostrClient,
            giftWrapBuilder: (_, _, _) async {
              mainBuilderCalls++;
              return null;
            },
          );

          final rumor = service.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'via server batch',
          );
          final result = await service.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _recipientPubkey,
          );

          expect(result.success, isTrue);
          expect(signer.batchCalls, equals(1));
          // The whole point: zero signer round trips for the seal, and no
          // per-wrap rebuild for the self copy.
          expect(signer.nip44EncryptCalls, isZero);
          expect(signer.signEventCalls, isZero);
          expect(mainBuilderCalls, isZero);
          // Both wraps published from the one call: recipient, then self.
          verify(() => mockNostrClient.publishEvent(any())).called(2);
        },
      );

      test(
        'sends the rumor and [recipient, self] as the batch params',
        () async {
          Map<String, dynamic>? seenRumor;
          List<String>? seenRecipients;
          final signer = _BatchWrapSigner(
            localPrivateKey,
            onBatch: (rumor, recipients) async {
              seenRumor = rumor;
              seenRecipients = recipients;
              return [
                GiftWrapSlot.success(wrapFor(recipients[0])),
                GiftWrapSlot.success(wrapFor(recipients[1])),
              ];
            },
          );

          final service = NIP17MessageService(
            signer: signer,
            senderPublicKey: localPubkey,
            nostrService: mockNostrClient,
          );
          final rumor = service.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'params check',
          );
          final result = await service.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _recipientPubkey,
          );
          expect(result.success, isTrue);

          // The rumor must go over the wire verbatim: the server recomputes
          // and verifies its id, and every slot seals this exact body, so the
          // id the durable queue keyed on is the id the recipient dedups on.
          expect(seenRumor, equals(rumor.toJson()));
          expect(seenRumor!['id'], equals(rumor.id));
          // Order is load-bearing — slot 0 is the recipient, slot 1 the NIP-17
          // self copy.
          expect(seenRecipients, equals([_recipientPubkey, localPubkey]));
        },
      );

      test('falls back to the per-wrap path when the recipient slot '
          'fails', () async {
        final signer = _BatchWrapSigner(
          localPrivateKey,
          onBatch: (rumor, recipients) async => [
            const GiftWrapSlot.failure('encrypt_failed'),
            GiftWrapSlot.success(wrapFor(recipients[1])),
          ],
        );
        var mainBuilderCalls = 0;

        final service = NIP17MessageService(
          signer: signer,
          senderPublicKey: localPubkey,
          nostrService: mockNostrClient,
          giftWrapBuilder: (_, _, recipient) async {
            mainBuilderCalls++;
            return Event.fromJson(wrapFor(recipient));
          },
        );
        final result = await service.sendRumor(
          rumorEvent: service.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'recipient slot failed',
          ),
          recipientPubkey: _recipientPubkey,
        );

        expect(result.success, isTrue);
        // Recipient wrap + self wrap, both rebuilt the old way.
        expect(mainBuilderCalls, equals(2));
      });

      test('keeps the recipient wrap and defers the self copy when only the '
          'self slot fails', () async {
        final signer = _BatchWrapSigner(
          localPrivateKey,
          onBatch: (rumor, recipients) async => [
            GiftWrapSlot.success(wrapFor(recipients[0])),
            const GiftWrapSlot.failure('internal'),
          ],
        );
        var mainBuilderCalls = 0;

        final service = NIP17MessageService(
          signer: signer,
          senderPublicKey: localPubkey,
          nostrService: mockNostrClient,
          giftWrapBuilder: (_, _, recipient) async {
            mainBuilderCalls++;
            return Event.fromJson(wrapFor(recipient));
          },
        );
        final result = await service.sendRumor(
          rumorEvent: service.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'self slot failed',
          ),
          recipientPubkey: _recipientPubkey,
        );

        expect(result.success, isTrue);
        expect(result.selfWrapPublished, isTrue);
        // Only the self copy was rebuilt; the batch's recipient wrap stands.
        expect(mainBuilderCalls, equals(1));
      });

      test('falls back when the slot count does not match the recipient '
          'count', () async {
        final signer = _BatchWrapSigner(
          localPrivateKey,
          onBatch: (rumor, recipients) async => [
            GiftWrapSlot.success(wrapFor(recipients[0])),
          ],
        );
        var mainBuilderCalls = 0;

        final service = NIP17MessageService(
          signer: signer,
          senderPublicKey: localPubkey,
          nostrService: mockNostrClient,
          giftWrapBuilder: (_, _, recipient) async {
            mainBuilderCalls++;
            return Event.fromJson(wrapFor(recipient));
          },
        );
        final result = await service.sendRumor(
          rumorEvent: service.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'short slot list',
          ),
          recipientPubkey: _recipientPubkey,
        );

        expect(result.success, isTrue);
        expect(mainBuilderCalls, equals(2));
      });

      test('falls back when a slot carries an unusable event', () async {
        // Parsed as JSON but not a well-formed event: never publish a wrap we
        // only half understand.
        final signer = _BatchWrapSigner(
          localPrivateKey,
          onBatch: (rumor, recipients) async => const [
            GiftWrapSlot.success({'not': 'an event'}),
            GiftWrapSlot.success({'not': 'an event'}),
          ],
        );
        var mainBuilderCalls = 0;

        final service = NIP17MessageService(
          signer: signer,
          senderPublicKey: localPubkey,
          nostrService: mockNostrClient,
          giftWrapBuilder: (_, _, recipient) async {
            mainBuilderCalls++;
            return Event.fromJson(wrapFor(recipient));
          },
        );
        final result = await service.sendRumor(
          rumorEvent: service.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'unusable slot',
          ),
          recipientPubkey: _recipientPubkey,
        );

        expect(result.success, isTrue);
        expect(mainBuilderCalls, equals(2));
      });

      test('falls back when a server wrap is unsigned', () async {
        final signer = _BatchWrapSigner(
          localPrivateKey,
          onBatch: (rumor, recipients) async => [
            GiftWrapSlot.success(wrapFor(recipients[0], sign: false)),
            GiftWrapSlot.success(wrapFor(recipients[1])),
          ],
        );
        var mainBuilderCalls = 0;

        final service = NIP17MessageService(
          signer: signer,
          senderPublicKey: localPubkey,
          nostrService: mockNostrClient,
          giftWrapBuilder: (_, _, recipient) async {
            mainBuilderCalls++;
            return Event.fromJson(wrapFor(recipient));
          },
        );
        final result = await service.sendRumor(
          rumorEvent: service.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'unsigned server wrap',
          ),
          recipientPubkey: _recipientPubkey,
        );

        expect(result.success, isTrue);
        expect(mainBuilderCalls, equals(2));
      });

      test('falls back when a server wrap is not kind 1059', () async {
        final signer = _BatchWrapSigner(
          localPrivateKey,
          onBatch: (rumor, recipients) async => [
            GiftWrapSlot.success(
              wrapFor(recipients[0], kind: EventKind.textNote),
            ),
            GiftWrapSlot.success(wrapFor(recipients[1])),
          ],
        );
        var mainBuilderCalls = 0;

        final service = NIP17MessageService(
          signer: signer,
          senderPublicKey: localPubkey,
          nostrService: mockNostrClient,
          giftWrapBuilder: (_, _, recipient) async {
            mainBuilderCalls++;
            return Event.fromJson(wrapFor(recipient));
          },
        );
        final result = await service.sendRumor(
          rumorEvent: service.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'wrong server wrap kind',
          ),
          recipientPubkey: _recipientPubkey,
        );

        expect(result.success, isTrue);
        expect(mainBuilderCalls, equals(2));
      });

      test('falls back when server slots are swapped', () async {
        final signer = _BatchWrapSigner(
          localPrivateKey,
          onBatch: (rumor, recipients) async => [
            GiftWrapSlot.success(wrapFor(recipients[1])),
            GiftWrapSlot.success(wrapFor(recipients[0])),
          ],
        );
        var mainBuilderCalls = 0;

        final service = NIP17MessageService(
          signer: signer,
          senderPublicKey: localPubkey,
          nostrService: mockNostrClient,
          giftWrapBuilder: (_, _, recipient) async {
            mainBuilderCalls++;
            return Event.fromJson(wrapFor(recipient));
          },
        );
        final result = await service.sendRumor(
          rumorEvent: service.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'swapped server wraps',
          ),
          recipientPubkey: _recipientPubkey,
        );

        expect(result.success, isTrue);
        expect(mainBuilderCalls, equals(2));
      });

      test(
        'latches off after the backend reports the verb unsupported',
        () async {
          // A null answer means "this server does not have the verb" — the only
          // signal strong enough to stop probing for the rest of the session.
          final signer = _BatchWrapSigner(
            localPrivateKey,
            onBatch: (rumor, recipients) async => null,
          );

          final service = NIP17MessageService(
            signer: signer,
            senderPublicKey: localPubkey,
            nostrService: mockNostrClient,
            giftWrapBuilder: (_, _, recipient) async =>
                Event.fromJson(wrapFor(recipient)),
          );

          for (final content in ['first', 'second']) {
            final result = await service.sendRumor(
              rumorEvent: service.buildRumor(
                recipientPubkey: _recipientPubkey,
                content: content,
              ),
              recipientPubkey: _recipientPubkey,
            );
            expect(result.success, isTrue);
          }

          expect(signer.batchCalls, equals(1));
        },
      );

      test('does NOT latch off after a transient batch failure', () async {
        // A 5xx, an expired token or a timeout is not evidence the verb is
        // gone. Latching on one would cost the rest of the session four round
        // trips per DM — the regression this whole change removes.
        final signer = _BatchWrapSigner(
          localPrivateKey,
          onBatch: (rumor, recipients) async =>
              throw StateError('HTTP 503: Database temporarily unavailable'),
        );

        final service = NIP17MessageService(
          signer: signer,
          senderPublicKey: localPubkey,
          nostrService: mockNostrClient,
          giftWrapBuilder: (_, _, recipient) async =>
              Event.fromJson(wrapFor(recipient)),
        );

        for (final content in ['first', 'second']) {
          final result = await service.sendRumor(
            rumorEvent: service.buildRumor(
              recipientPubkey: _recipientPubkey,
              content: content,
            ),
            recipientPubkey: _recipientPubkey,
          );
          expect(result.success, isTrue);
        }

        expect(signer.batchCalls, equals(2));
      });

      test('a policy refusal thrown by the batch still terminalizes as '
          'blocked', () async {
        // Keycast's verified_minor gate answers 403 "Operation denied by
        // policy". The batch rethrows it, the fallback's own encrypt re-hits
        // it, and sendRumor must classify it terminal rather than retryable.
        final signer = _BatchWrapSigner(
          localPrivateKey,
          onBatch: (rumor, recipients) async =>
              throw _RpcExceptionDouble('HTTP 403: Operation denied by policy'),
        );

        final service = NIP17MessageService(
          signer: signer,
          senderPublicKey: localPubkey,
          nostrService: mockNostrClient,
          giftWrapBuilder: (_, _, _) async =>
              throw _RpcExceptionDouble('HTTP 403: Operation denied by policy'),
        );
        final result = await service.sendRumor(
          rumorEvent: service.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'minor gate',
          ),
          recipientPubkey: _recipientPubkey,
        );

        expect(result.blocked, isTrue);
      });

      for (final (label, kind) in [
        ('kind-7 reaction', EventKind.reaction),
        ('kind-5 deletion', EventKind.eventDeletion),
      ]) {
        test('never offers a $label rumor to the batch', () async {
          // keycast rejects anything but kinds 14/15 at request level, so
          // probing would burn a round trip to learn the same answer every
          // time — and NIP-17 blesses both of these kinds, so they are not
          // rare. See #7090 / the keycast follow-up.
          final signer = _BatchWrapSigner(
            localPrivateKey,
            onBatch: (rumor, recipients) async => [
              GiftWrapSlot.success(wrapFor(recipients[0])),
              GiftWrapSlot.success(wrapFor(recipients[1])),
            ],
          );
          var mainBuilderCalls = 0;

          final service = NIP17MessageService(
            signer: signer,
            senderPublicKey: localPubkey,
            nostrService: mockNostrClient,
            giftWrapBuilder: (_, _, recipient) async {
              mainBuilderCalls++;
              return Event.fromJson(wrapFor(recipient));
            },
          );
          final result = await service.sendRumor(
            rumorEvent: service.buildRumor(
              recipientPubkey: _recipientPubkey,
              content: label,
              eventKind: kind,
            ),
            recipientPubkey: _recipientPubkey,
          );

          expect(result.success, isTrue);
          expect(signer.batchCalls, isZero);
          expect(mainBuilderCalls, equals(2));
        });
      }

      test('a kind the batch cannot take does not latch it off for the kinds '
          'it can', () async {
        // The kind guard has to be a skip, not a failure: a reaction must not
        // cost the next message send its fast path.
        final signer = _BatchWrapSigner(
          localPrivateKey,
          onBatch: (rumor, recipients) async => [
            GiftWrapSlot.success(wrapFor(recipients[0])),
            GiftWrapSlot.success(wrapFor(recipients[1])),
          ],
        );

        final service = NIP17MessageService(
          signer: signer,
          senderPublicKey: localPubkey,
          nostrService: mockNostrClient,
          giftWrapBuilder: (_, _, recipient) async =>
              Event.fromJson(wrapFor(recipient)),
        );

        final reaction = await service.sendRumor(
          rumorEvent: service.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: '👍',
            eventKind: EventKind.reaction,
          ),
          recipientPubkey: _recipientPubkey,
        );
        expect(reaction.success, isTrue);
        expect(signer.batchCalls, isZero);

        final message = await service.sendRumor(
          rumorEvent: service.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'message after a reaction',
          ),
          recipientPubkey: _recipientPubkey,
        );
        expect(message.success, isTrue);
        expect(signer.batchCalls, equals(1));
      });

      test('a local-key signer never reaches the batch, even when its signer '
          'supports it', () async {
        // A BYOK Keycast identity is both isolate-capable and batch-capable.
        // The isolate hop costs zero round trips, so it must win.
        final signer = _IsolateAndBatchSigner(
          localPrivateKey,
          onBatch: (rumor, recipients) async => [
            GiftWrapSlot.success(wrapFor(recipients[0])),
            GiftWrapSlot.success(wrapFor(recipients[1])),
          ],
        );

        final service = NIP17MessageService(
          signer: signer,
          senderPublicKey: localPubkey,
          nostrService: mockNostrClient,
          isolateGiftWrapBatchBuilder: buildGiftWrapBatch,
        );
        final result = await service.sendRumor(
          rumorEvent: service.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'local key wins',
          ),
          recipientPubkey: _recipientPubkey,
        );

        expect(result.success, isTrue);
        expect(signer.batchCalls, isZero);
      });

      test('a failed isolate hop falls to in-process signing, not the '
          'network', () async {
        // Same identity, but the isolate seam fails. The main-isolate builder
        // still signs with the local key at zero round trips, so falling to
        // the server batch here would be a regression.
        final signer = _IsolateAndBatchSigner(
          localPrivateKey,
          onBatch: (rumor, recipients) async => [
            GiftWrapSlot.success(wrapFor(recipients[0])),
            GiftWrapSlot.success(wrapFor(recipients[1])),
          ],
        );
        var mainBuilderCalls = 0;

        final service = NIP17MessageService(
          signer: signer,
          senderPublicKey: localPubkey,
          nostrService: mockNostrClient,
          isolateGiftWrapBatchBuilder: (_) async =>
              throw StateError('isolate spawn failed'),
          giftWrapBuilder: (_, _, recipient) async {
            mainBuilderCalls++;
            return Event.fromJson(wrapFor(recipient));
          },
        );
        final result = await service.sendRumor(
          rumorEvent: service.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'isolate failed',
          ),
          recipientPubkey: _recipientPubkey,
        );

        expect(result.success, isTrue);
        expect(signer.batchCalls, isZero);
        expect(mainBuilderCalls, equals(2));
      });
    });

    // #6586. A 1:1 send costs four remote signer round trips, and no signer
    // interface exposes a per-call timeout — Keycast bounds an op at 20s,
    // Amber's NIP-55 intent path for nip44Encrypt/signEvent is human-gated and
    // unbounded, and a bunker may be unbounded too. Before these bounds existed
    // the chain could outrun the caller's publish backstop, which then fired
    // AFTER the recipient publish had landed and reported a delivered message
    // as unconfirmed.
    group('wrap-build bounds (#6586)', () {
      late _MockNostrClient client;

      setUp(() {
        client = _MockNostrClient();
        when(
          () => client.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => const PublishOutcome(
            eventId: 'gift-wrap-id',
            acceptedBy: ['wss://relay.example.com'],
            rejectedBy: {},
            noResponseFrom: [],
          ),
        );
        when(() => client.publishEvent(any())).thenAnswer(
          (inv) async =>
              PublishSuccess(event: inv.positionalArguments[0] as Event),
        );
      });

      // `GiftWrapBuilder` is hidden from the package barrel, so spell the
      // signature out rather than reaching into `src/`.
      NIP17MessageService serviceWithBuilder(
        Future<Event?> Function(Nostr, Event, String) builder,
      ) => NIP17MessageService(
        signer: LocalNostrSigner(_testPrivateKey),
        senderPublicKey: _testPublicKey,
        nostrService: client,
        giftWrapBuilder: builder,
      );

      test(
        'recipient wrap build timeout is retryable-pending before publishing',
        () {
          // The load-bearing assertion is the negative one: a build that never
          // completes must not reach the relay. Timing out after the publish is
          // the #6586 defect — the recipient has the message and the sender is
          // told it is unconfirmed. Timing out before publish leaves nothing
          // delivered, but NIP-55/Amber may still be waiting on a human approval,
          // so the durable queue keeps the row pending for retry instead of
          // red.
          NIP17SendResult? result;
          fakeAsync((async) {
            unawaited(
              serviceWithBuilder((_, _, _) => Completer<Event?>().future)
                  .sendRumor(
                    rumorEvent: Event(
                      _testPublicKey,
                      EventKind.privateDirectMessage,
                      const [],
                      'hangs while wrapping',
                    ),
                    recipientPubkey: _recipientPubkey,
                    awaitRecipientOk: true,
                    selfWrapOnSoftUnconfirmed: false,
                  )
                  .then((r) => result = r),
            );

            async.elapse(
              DmBatchSendBudget.recipientWrapBuild * 2,
            );
          });

          expect(result, isNotNull, reason: 'send must resolve, not hang');
          expect(result!.success, isFalse);
          expect(result!.retryablePending, isTrue);
          expect(
            (result! as NIP17SendFailure).error,
            'Recipient gift wrap build timed out after '
            '${DmBatchSendBudget.recipientWrapBuild.inSeconds}s',
          );
          verifyNever(
            () => client.publishEventAwaitOk(
              any(),
              timeout: any(named: 'timeout'),
            ),
          );
          verifyNever(() => client.publishEvent(any()));
        },
      );

      test(
        'recipient wrap builder returning null remains a hard failure',
        () async {
          final result = await serviceWithBuilder((_, _, _) async => null)
              .sendRumor(
                rumorEvent: Event(
                  _testPublicKey,
                  EventKind.privateDirectMessage,
                  const [],
                  'builder returned null',
                ),
                recipientPubkey: _recipientPubkey,
                awaitRecipientOk: true,
                selfWrapOnSoftUnconfirmed: false,
              );

          expect(result.success, isFalse);
          expect(result.retryablePending, isFalse);
          expect(
            (result as NIP17SendFailure).error,
            'Failed to create gift wrap event',
          );
          verifyNever(
            () => client.publishEventAwaitOk(
              any(),
              timeout: any(named: 'timeout'),
            ),
          );
          verifyNever(() => client.publishEvent(any()));
        },
      );

      test(
        'a send with no retry row leaves the recipient build uncapped',
        () {
          // `sendFileMessage` and the bug-report send reach sendRumor through
          // sendPrivateMessage and do not own an outgoing_dms row. If an Amber
          // approval takes longer than the send-chain recipient bound,
          // returning retryablePending gives those callers nowhere to retry
          // from. Keep this pre-publish build uncapped for that convenience
          // path.
          final senderPublicKey = getPublicKey(_testPrivateKey);
          final slowApproval =
              DmSendBudget.recipientWrapBuild + const Duration(seconds: 5);

          NIP17SendResult? result;
          fakeAsync((async) {
            var builds = 0;
            final service = NIP17MessageService(
              signer: LocalNostrSigner(_testPrivateKey),
              senderPublicKey: senderPublicKey,
              nostrService: client,
              giftWrapBuilder: (nostr, rumor, receiverPubkey) {
                builds++;
                return Future.delayed(
                  builds == 1 ? slowApproval : Duration.zero,
                  () => GiftWrapUtil.getGiftWrapEvent(
                    nostr,
                    rumor,
                    receiverPubkey,
                  ),
                );
              },
            );

            unawaited(
              service
                  .sendPrivateMessage(
                    recipientPubkey: _recipientPubkey,
                    content: 'slow recipient approval',
                    awaitRecipientOk: true,
                  )
                  .then((r) => result = r),
            );

            async
              ..flushMicrotasks()
              ..elapse(slowApproval)
              ..flushMicrotasks();
          });

          expect(result, isNotNull, reason: 'send must resolve, not time out');
          expect(result!.success, isTrue);
          expect(result!.retryablePending, isFalse);
        },
      );

      test(
        'self-wrap build that outruns its bound still reports a delivered send',
        () {
          // The recipient wrap is already published and OK-confirmed here, so
          // the send DID happen. A slow self-wrap must degrade to partial
          // delivery (recoverSelfWrap picks it up, #4124), never to a failure —
          // reporting failure here is what parked delivered messages as
          // soft-unconfirmed until the retry budget turned them red.
          var builds = 0;
          NIP17SendResult? result;
          fakeAsync((async) {
            unawaited(
              serviceWithBuilder((nostr, rumor, receiverPubkey) {
                    builds++;
                    // First call = recipient wrap: succeed. Second = self:
                    // hang.
                    return builds == 1
                        ? GiftWrapUtil.getGiftWrapEvent(
                            nostr,
                            rumor,
                            receiverPubkey,
                          )
                        : Completer<Event?>().future;
                  })
                  .sendRumor(
                    rumorEvent: Event(
                      _testPublicKey,
                      EventKind.privateDirectMessage,
                      const [],
                      'self-wrap hangs',
                    ),
                    recipientPubkey: _recipientPubkey,
                    awaitRecipientOk: true,
                    selfWrapOnSoftUnconfirmed: false,
                  )
                  .then((r) => result = r),
            );

            async.elapse(DmSendBudget.selfWrapBuild * 2);
          });

          expect(result, isNotNull, reason: 'send must resolve, not hang');
          expect(
            result!.success,
            isTrue,
            reason: 'the recipient wrap was published and OK-confirmed',
          );
          expect(
            result!.selfWrapPublished,
            isFalse,
            reason: 'partial delivery, recoverable via recoverSelfWrap',
          );
        },
      );

      test('the self-wrap bound is tighter than the recipient bound', () {
        // Encodes the asymmetry the bounds exist for: a slow recipient wrap
        // costs a delivery, a slow self-wrap costs a recovery step.
        expect(
          DmSendBudget.selfWrapBuild,
          lessThan(DmSendBudget.recipientWrapBuild),
        );
      });

      test(
        'a self-wrap rebuild too slow for the send bound still recovers '
        'out of band',
        () {
          // The tight in-send bound buys headroom under the publish backstop.
          // Recovery has no backstop to protect, so bounding it the same way
          // would only fail rebuilds the signer would have completed — and the
          // rebuild is the same two round trips that left the self-wrap
          // outstanding, so it would fail against exactly the slow signer this
          // arm exists for, every attempt, until the row exhausted its retry
          // budget with the cross-device copy permanently missing.
          final senderPublicKey = getPublicKey(_testPrivateKey);
          // Past the in-send bound, well inside the recovery bound.
          final slowRebuild = DmSendBudget.selfWrapBuild * 2;
          expect(
            slowRebuild,
            lessThan(DmSendBudget.selfWrapUncappedBuild),
            reason: 'the rebuild must sit between the two bounds to test them',
          );

          NIP17SendResult? result;
          fakeAsync((async) {
            final service = NIP17MessageService(
              signer: LocalNostrSigner(_testPrivateKey),
              // Derived from the signer: the self-wrap ECDH keys on it, and
              // the synthetic _testPublicKey is not a valid secp256k1 point.
              senderPublicKey: senderPublicKey,
              nostrService: client,
              giftWrapBuilder: (nostr, rumor, receiverPubkey) => Future.delayed(
                slowRebuild,
                () => GiftWrapUtil.getGiftWrapEvent(
                  nostr,
                  rumor,
                  receiverPubkey,
                ),
              ),
            );

            unawaited(
              service
                  .publishSelfWrap(
                    rumorEvent: service.buildRumor(
                      recipientPubkey: _recipientPubkey,
                      content: 'slow self-wrap rebuild',
                    ),
                  )
                  .then((r) => result = r),
            );

            async.elapse(DmSendBudget.selfWrapUncappedBuild);
          });

          expect(result, isNotNull, reason: 'recovery must resolve, not hang');
          expect(result!.success, isTrue);
          expect(result!.selfWrapPublished, isTrue);
        },
      );

      test(
        'a send with no retry row leaves the self-wrap build uncapped',
        () {
          // `sendFileMessage` and the bug-report send reach sendRumor via
          // sendPrivateMessage, impose NO outer cap, and own no outgoing_dms
          // row. A self-wrap build timeout reports selfWrapPublished: false
          // and leans on recoverSelfWrap to finish out of band — but that
          // requires the queue row they never create, so ANY bound here drops
          // the sender's cross-device copy for good. Drive the rebuild past
          // even the widest bound to pin that it is uncapped, not just wide.
          final senderPublicKey = getPublicKey(_testPrivateKey);
          final slowRebuild =
              DmSendBudget.selfWrapUncappedBuild + const Duration(seconds: 5);

          NIP17SendResult? result;
          fakeAsync((async) {
            var builds = 0;
            final service = NIP17MessageService(
              signer: LocalNostrSigner(_testPrivateKey),
              senderPublicKey: senderPublicKey,
              nostrService: client,
              giftWrapBuilder: (nostr, rumor, receiverPubkey) {
                builds++;
                // Recipient wrap is prompt; only the self-wrap rebuild is slow.
                return builds == 1
                    ? GiftWrapUtil.getGiftWrapEvent(
                        nostr,
                        rumor,
                        receiverPubkey,
                      )
                    : Future.delayed(
                        slowRebuild,
                        () => GiftWrapUtil.getGiftWrapEvent(
                          nostr,
                          rumor,
                          receiverPubkey,
                        ),
                      );
              },
            );

            unawaited(
              service
                  .sendPrivateMessage(
                    recipientPubkey: _recipientPubkey,
                    content: 'uncapped caller',
                    awaitRecipientOk: true,
                  )
                  .then((r) => result = r),
            );

            async
              ..flushMicrotasks()
              ..elapse(slowRebuild)
              ..flushMicrotasks();
          });

          expect(result, isNotNull, reason: 'send must resolve, not hang');
          expect(result!.success, isTrue);
          expect(
            result!.selfWrapPublished,
            isTrue,
            reason:
                'a rebuild slower than every self-wrap bound must still land '
                'for a caller with no row to recover from',
          );
        },
      );
    });
  });
}
