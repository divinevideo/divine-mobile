// ABOUTME: #5391 — proves the NIP-17 send-path gift-wrap build no longer
// ABOUTME: freezes the UI (main) isolate for local-key signers. Measures the
// ABOUTME: max event-loop stall while building the recipient + self gift wraps
// ABOUTME: the OLD way (GiftWrapUtil.getGiftWrapEvent on the main isolate) vs
// ABOUTME: the NEW way (buildGiftWrapBatch via compute()). On-device only.

import 'dart:async';
import 'dart:ui';

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/foundation.dart' show compute, debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nip59/gift_wrap_util.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/relay/relay.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

// Signing-only Nostr instance never opens relays, so the generator is never
// invoked (mirrors NIP17MessageService's own dummy generator).
Relay _dummyRelay(String url) => throw UnimplementedError();

/// Runs [work] while a 1ms periodic timer samples the event loop, returning the
/// largest gap (ms) between consecutive ticks — i.e. the longest the main
/// isolate was blocked from servicing the loop. A small gap means the UI thread
/// stayed responsive; a large gap is a visible freeze.
Future<double> _maxEventLoopStallMs(Future<void> Function() work) async {
  final sw = Stopwatch()..start();
  var last = sw.elapsedMicroseconds;
  var maxGap = 0;
  final timer = Timer.periodic(const Duration(milliseconds: 1), (_) {
    final now = sw.elapsedMicroseconds;
    final gap = now - last;
    if (gap > maxGap) maxGap = gap;
    last = now;
  });
  // Let the timer reach a steady cadence, then reset the baseline so the
  // measured window covers only [work].
  await Future<void>.delayed(const Duration(milliseconds: 20));
  last = sw.elapsedMicroseconds;
  maxGap = 0;
  await work();
  timer.cancel();
  return maxGap / 1000.0;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('gift-wrap build stall', () {
    test('#5391 send-path gift-wrap build no longer stalls the UI isolate', () async {
      final senderPrivateKey = generatePrivateKey();
      final senderPubkey = getPublicKey(senderPrivateKey);
      final recipientPubkey = getPublicKey(generatePrivateKey());

      final senderNostr = Nostr(
        LocalNostrSigner(senderPrivateKey),
        const [],
        _dummyRelay,
      );
      await senderNostr.refreshPublicKey();

      final rumor = Event(
        senderPubkey,
        EventKind.privateDirectMessage,
        const <List<String>>[],
        'benchmark message',
      );
      final rumorJson = rumor.toJson();

      final view = PlatformDispatcher.instance.views.first;
      final refreshHz = view.display.refreshRate;
      final frameBudgetMs = refreshHz > 0 ? 1000.0 / refreshHz : 16.67;

      // The shipped send path: one combined batch for recipient + self wrap.
      final combinedRequest = BuildGiftWrapRequest(
        privateKeyHex: senderPrivateKey,
        rumorJson: rumorJson,
        receiverPublicKeys: [recipientPubkey, senderPubkey],
      );

      // Warm up both paths (JIT + first-isolate spawn) so the measured windows
      // reflect steady-state cost rather than one-off initialization.
      await GiftWrapUtil.getGiftWrapEvent(senderNostr, rumor, recipientPubkey);
      await compute(buildGiftWrapBatch, combinedRequest);

      // OLD: build recipient + self wrap on the main isolate (today's path).
      final oldStallMs = await _maxEventLoopStallMs(() async {
        await GiftWrapUtil.getGiftWrapEvent(
          senderNostr,
          rumor,
          recipientPubkey,
        );
        await GiftWrapUtil.getGiftWrapEvent(senderNostr, rumor, senderPubkey);
      });

      // NEW: build both wraps off the main isolate in one combined compute() hop.
      final newStallMs = await _maxEventLoopStallMs(() async {
        await compute(buildGiftWrapBatch, combinedRequest);
      });

      debugPrint(
        '[#5391] frameBudget=${frameBudgetMs.toStringAsFixed(2)}ms '
        'OLD main-isolate stall=${oldStallMs.toStringAsFixed(1)}ms '
        'NEW main-isolate stall=${newStallMs.toStringAsFixed(1)}ms',
      );

      // The OLD path blocks the UI isolate well past a single frame — the freeze.
      expect(
        oldStallMs,
        greaterThan(frameBudgetMs),
        reason: 'on-main-isolate build should blow the frame budget',
      );
      // The offloaded path keeps the UI isolate under one frame budget — an
      // absolute bound that is device-speed-independent, unlike a relative
      // fraction of the old-path stall. This is precisely what "the freeze is
      // gone" means to the user: the UI stays responsive across every frame.
      expect(
        newStallMs,
        lessThan(frameBudgetMs),
        reason: 'compute() offload should keep the UI isolate under one frame budget',
      );
    });
  });
}
