// ABOUTME: #5413 — captures real frame build/raster times while a large
// ABOUTME: remote-signer DM backfill runs the per-event path concurrently,
// ABOUTME: proving the visible UI stays within frame budget (no sustained jank).
//
// A continuously-animating canary widget stands in for the active Notifications
// tab (the surface the user watches while the drain runs). During
// `watchPerformance`, a backfill loop reproduces the REAL main-isolate work the
// remote per-event path does — for each wrap: one Event validation burst
// (sha256 + Schnorr verify), an awaited off-isolate decrypt RPC (emulated as a
// delay, since Keycast=network / Amber=IPC), a second validation burst, a
// second awaited RPC, an un-throttled ConversationListBloc-style projection,
// and the WS3 yield every 16 wraps. If that main-isolate work starves frame
// rendering, the canary drops frames and the summary shows it.
//
// Two latencies: realistic (~235ms, observed for remote nip44_decrypt) and a
// fast stress (~10ms, Keycast-HTTP-like, where bursts arrive far more often).
// See tasks/findings_5413.md and the CPU half in
// dm_remote_signer_backfill_cost_test.dart.

import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';

const int _drainYieldInterval = 16;

String _randomBase64(Random rng, int bytes) =>
    base64.encode(List<int>.generate(bytes, (_) => rng.nextInt(256)));

Event _signedEvent(Random rng, int kind, int contentBytes) {
  final priv = generatePrivateKey();
  final e = Event(
    getPublicKey(priv),
    kind,
    const [],
    _randomBase64(rng, contentBytes),
  );
  e.sign(priv);
  return e;
}

DmConversation _conversation(Random rng, int i) {
  return DmConversation(
    id: 'conv_$i',
    participantPubkeys: ['a' * 64, i.toRadixString(16).padLeft(64, '0')],
    isGroup: false,
    createdAt: 1700000000 + i,
    lastMessageContent: _randomBase64(rng, 24),
    lastMessageTimestamp: 1700000000 + i * 7,
    lastMessageSenderPubkey: i.toRadixString(16).padLeft(64, '0'),
  );
}

/// Reproduces the main-isolate work of one remote-signer gift-wrap drain step:
/// validate outer (burst) -> await off-isolate decrypt -> validate seal (burst)
/// -> await off-isolate decrypt -> project. Mirrors getRumorEvent +
/// ConversationListBloc.onData. Yields every [_drainYieldInterval] wraps (WS3).
Future<void> _runBackfill({
  required Random rng,
  required int wraps,
  required Duration decryptLatency,
  required List<DmConversation> potential,
}) async {
  bool isFollowing(String _) => false;
  for (var i = 0; i < wraps; i++) {
    final outer = _signedEvent(rng, EventKind.giftWrap, 900);
    final seal = _signedEvent(rng, EventKind.sealEventKind, 600);

    // Burst 1: outer validation (sha256 + Schnorr verify) on the main isolate.
    if (!(outer.isValid && outer.isSigned)) {
      throw StateError('outer self-validate failed');
    }
    // Off-isolate decrypt RPC (Keycast network / Amber IPC) — frames render.
    await Future<void>.delayed(decryptLatency);

    // Burst 2: seal validation on the main isolate.
    if (!(seal.isValid && seal.isSigned)) {
      throw StateError('seal self-validate failed');
    }
    await Future<void>.delayed(decryptLatency);

    // Per-emission projection (un-throttled ConversationListBloc recompute).
    final visible = potential.sublist(0, min(potential.length, (i + 1) * 3));
    final split = DmRepository.classifyPotentialRequests(
      visible,
      userPubkey: 'a' * 64,
      isFollowing: isFollowing,
    );
    DmRepository.mergeAndSort(const [], split.followed);

    // WS3 yield.
    if ((i + 1) % _drainYieldInterval == 0) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

/// Always-animating canary: forces a build + repaint every frame, like the
/// active Notifications tab the user is watching while the drain runs.
class _Canary extends StatefulWidget {
  const _Canary();
  @override
  State<_Canary> createState() => _CanaryState();
}

class _CanaryState extends State<_Canary> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return ListView.builder(
              itemCount: 40,
              itemBuilder: (context, i) => Opacity(
                opacity: 0.3 + 0.7 * ((_c.value + i / 40) % 1.0),
                child: Container(
                  height: 56,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  color: Color.lerp(
                    Colors.indigo,
                    Colors.teal,
                    (_c.value + i / 40) % 1.0,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('backfill frame', () {
    testWidgets('#5413 frame build/raster during a remote-signer backfill', (
      tester,
    ) async {
      final rng = Random(5413);
      final view = PlatformDispatcher.instance.views.first;
      final refreshHz = view.display.refreshRate;
      final frameBudgetMs = refreshHz > 0 ? 1000.0 / refreshHz : 16.67;

      final potential = [for (var i = 0; i < 1000; i++) _conversation(rng, i)];

      // Free-run frames in real time so the canary animation renders continuously
      // and any concurrent main-isolate work shows up as delayed/janky frames.
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

      await tester.pumpWidget(const _Canary());
      await tester.pump(const Duration(milliseconds: 16));

      final report = StringBuffer()
        ..writeln(
          '================ #5413 BACKFILL FRAME TRACE ================',
        )
        ..writeln(
          'device refreshRate=${refreshHz.toStringAsFixed(1)}Hz '
          'frameBudget=${frameBudgetMs.toStringAsFixed(2)}ms',
        );

      final overBudgetByLabel = <String, int>{};
      final frameCountByLabel = <String, int>{};

      Future<void> measure(
        String label, {
        required Future<void> Function() action,
      }) async {
        final raw = <FrameTiming>[];
        void cb(List<FrameTiming> t) => raw.addAll(t);
        binding.addTimingsCallback(cb);
        // With fullyLive frame policy + a repeating animation, frames free-run in
        // real time during this await, so a concurrent main-isolate backfill
        // burst genuinely competes for the UI thread (watchPerformance hangs on a
        // passive await — it needs an action that itself drives frames).
        await action();
        // FrameTimings are flushed by the engine ~once/sec — drain the tail.
        await Future<void>.delayed(const Duration(seconds: 2));
        binding.removeTimingsCallback(cb);

        double ms(int micros) => micros / 1000.0;
        final build =
            raw.map((t) => ms(t.buildDuration.inMicroseconds)).toList()..sort();
        final raster =
            raw.map((t) => ms(t.rasterDuration.inMicroseconds)).toList()
              ..sort();
        double p(List<double> xs, double q) => xs.isEmpty
            ? 0
            : xs[(xs.length * q).floor().clamp(0, xs.length - 1)];
        final jankyBuild = build.where((d) => d > frameBudgetMs).length;
        final jankyRaster = raster.where((d) => d > frameBudgetMs).length;
        overBudgetByLabel[label] = jankyBuild + jankyRaster;
        frameCountByLabel[label] = raw.length;

        report
          ..writeln('--- $label (${raw.length} frames) ---')
          ..writeln(
            '  build  p50=${p(build, 0.5).toStringAsFixed(2)} '
            'p90=${p(build, 0.9).toStringAsFixed(2)} '
            'p99=${p(build, 0.99).toStringAsFixed(2)} '
            'max=${(build.isEmpty ? 0 : build.last).toStringAsFixed(2)}ms',
          )
          ..writeln(
            '  raster p50=${p(raster, 0.5).toStringAsFixed(2)} '
            'p90=${p(raster, 0.9).toStringAsFixed(2)} '
            'p99=${p(raster, 0.99).toStringAsFixed(2)} '
            'max=${(raster.isEmpty ? 0 : raster.last).toStringAsFixed(2)}ms',
          )
          ..writeln(
            '  over-budget frames: build=$jankyBuild raster=$jankyRaster '
            '(budget ${frameBudgetMs.toStringAsFixed(2)}ms)',
          );
      }

      // Baseline: animation only, no backfill.
      await measure(
        'baseline',
        action: () async {
          await Future<void>.delayed(const Duration(seconds: 3));
        },
      );

      // Realistic remote latency (~235ms): the common Keycast NIP-46 / Amber case.
      await measure(
        'backfill_realistic_235ms',
        action: () async {
          await _runBackfill(
            rng: rng,
            wraps: 40,
            decryptLatency: const Duration(milliseconds: 235),
            potential: potential,
          );
        },
      );

      // Fast stress (~10ms): Keycast-HTTP-like, bursts arrive ~20x more often.
      await measure(
        'backfill_fast_10ms',
        action: () async {
          await _runBackfill(
            rng: rng,
            wraps: 300,
            decryptLatency: const Duration(milliseconds: 10),
            potential: potential,
          );
        },
      );

      report.writeln(
        '===========================================================',
      );
      // This benchmark's result is a human-readable console report.
      // ignore: avoid_print
      print(report);

      // The backfill windows must render real frames and stay within budget. The
      // observed result is 0 over-budget frames; allow a small slack for harness
      // noise. (The idle baseline's startup frame is intentionally excluded.)
      for (final label in const [
        'backfill_realistic_235ms',
        'backfill_fast_10ms',
      ]) {
        expect(
          frameCountByLabel[label],
          greaterThan(50),
          reason: '$label must actually render frames during the backfill',
        );
        expect(
          overBudgetByLabel[label],
          lessThanOrEqualTo(3),
          reason: '$label must not produce sustained over-budget frames',
        );
      }
    });
  });
}
