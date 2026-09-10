// ABOUTME: #5413 — measures the MAIN-ISOLATE CPU a large remote-signer DM
// ABOUTME: backfill imposes per gift wrap (event validation) and per Drift
// ABOUTME: emission (conversation-list projection), on real device hardware.
//
// Context: a remote signer (Keycast NIP-46 / Amber NIP-55) takes the per-event
// decrypt path (the batch fast-path does not cover it). The symmetric decrypt
// itself runs OFF the main isolate (network RPC / IPC), but `getRumorEvent`
// runs 2x Event.isValid (sha256) + 2x Event.isSigned (Schnorr verify) per wrap
// ON the main isolate, and `ConversationListBloc` re-runs an un-throttled
// projection (mergeAndSort + classifyPotentialRequests) per persisted wrap.
// This test puts a real device-CPU number on both, so we can reason about the
// per-frame budget (8.33ms @120Hz / 16.67ms @60Hz) and the WS3 yield interval
// of 16 wraps. See tasks/findings_5413.md (E1, E3) and PR #5405/#5412/#5417.
//
// This is the CPU half of the trace. The frame build/raster half is in
// dm_remote_signer_backfill_frame_test.dart.

import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';

String _randomBase64(Random rng, int bytes) {
  final b = List<int>.generate(bytes, (_) => rng.nextInt(256));
  return base64.encode(b);
}

/// Builds a real signed event whose `content` is a realistic NIP-44-ciphertext-
/// sized base64 blob, so `isValid` (sha256 over the serialized event) and
/// `isSigned` (Schnorr verify over the 32-byte id) cost what they cost in the
/// real gift-wrap / seal validation.
Event _signedEvent(Random rng, int kind, int contentBytes) {
  final priv = generatePrivateKey();
  final pub = getPublicKey(priv);
  final e = Event(pub, kind, const [], _randomBase64(rng, contentBytes));
  e.sign(priv);
  return e;
}

DmConversation _conversation(Random rng, int i, {required bool group}) {
  final me = 'a' * 64;
  final peer = i.toRadixString(16).padLeft(64, '0');
  return DmConversation(
    id: 'conv_$i',
    participantPubkeys: group ? [me, peer, '${'b' * 63}c'] : [me, peer],
    isGroup: group,
    createdAt: 1700000000 + i,
    lastMessageContent: _randomBase64(rng, 24),
    lastMessageTimestamp: 1700000000 + i * 7,
    lastMessageSenderPubkey: peer,
  );
}

double _median(List<int> micros) {
  final s = [...micros]..sort();
  return s[s.length ~/ 2] / 1000.0; // ms
}

double _p99(List<int> micros) {
  final s = [...micros]..sort();
  return s[(s.length * 0.99).floor().clamp(0, s.length - 1)] / 1000.0;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('backfill cost', () {
    test(
      '#5413 remote-signer backfill: main-isolate CPU per wrap + per emission',
      () async {
        final rng = Random(5413);

        // Refresh rate / frame budget for the device under test.
        final view = PlatformDispatcher.instance.views.first;
        final refreshHz = view.display.refreshRate;
        final frameBudgetMs = refreshHz > 0 ? 1000.0 / refreshHz : 16.67;

        // --- Component 1: per-wrap main-isolate VALIDATION cost (H1b) ---
        // Two nested events per wrap: outer gift wrap (kind 1059, ~encrypted seal)
        // and seal (kind 13, ~encrypted rumor). getRumorEvent validates BOTH:
        // isValid (sha256) + isSigned (Schnorr verify) on each.
        const wrapCount = 400;
        final outers = [
          for (var i = 0; i < wrapCount; i++)
            _signedEvent(rng, EventKind.giftWrap, 900),
        ];
        final seals = [
          for (var i = 0; i < wrapCount; i++)
            _signedEvent(rng, EventKind.sealEventKind, 600),
        ];

        // perWrap = both nested validations (reference total). The TRUE per-frame
        // risk, though, is the largest CONTIGUOUS main-isolate burst between two
        // off-isolate awaits: in getRumorEvent that is ONE isValid (sha256) + ONE
        // isSigned (Schnorr verify) — the outer verify runs, an awaited
        // nip44Decrypt RPC yields the loop, THEN the seal verify runs. A single
        // frame never sees both verifies.
        final perWrapMicros = <int>[];
        final perBurstMicros = <int>[];
        final singleVerifyMicros = <int>[];
        final singleSha256Micros = <int>[];
        final sw = Stopwatch();
        for (var i = 0; i < wrapCount; i++) {
          sw
            ..reset()
            ..start();
          final ok =
              outers[i].isValid &&
              outers[i].isSigned &&
              seals[i].isValid &&
              seals[i].isSigned;
          sw.stop();
          expect(ok, isTrue, reason: 'generated events must self-validate');
          perWrapMicros.add(sw.elapsedMicroseconds);

          sw
            ..reset()
            ..start();
          final v = outers[i].isValid;
          sw.stop();
          expect(v, isTrue);
          singleSha256Micros.add(sw.elapsedMicroseconds);

          sw
            ..reset()
            ..start();
          final s = outers[i].isSigned;
          sw.stop();
          expect(s, isTrue);
          singleVerifyMicros.add(sw.elapsedMicroseconds);

          sw
            ..reset()
            ..start();
          final b = seals[i].isValid && seals[i].isSigned;
          sw.stop();
          expect(b, isTrue);
          perBurstMicros.add(sw.elapsedMicroseconds);
        }

        // --- Component 2: per-emission projection cost (H2) ---
        // ConversationListBloc re-runs mergeAndSort + classifyPotentialRequests on
        // every Drift emission (~once per persisted wrap). watchPotentialRequests
        // is UNPAGINATED, so after a reinstall N grows toward the full history.
        final projectionByN = <int, ({double median, double p99})>{};
        bool isFollowing(String _) => false; // worst case: nothing followed
        for (final n in const [200, 500, 1000]) {
          final accepted = [
            for (var i = 0; i < (n * 0.1).round(); i++)
              _conversation(rng, i, group: false),
          ];
          final potential = [
            for (var i = 0; i < n; i++)
              _conversation(rng, 100000 + i, group: i % 25 == 0),
          ];
          final micros = <int>[];
          for (var rep = 0; rep < 50; rep++) {
            sw
              ..reset()
              ..start();
            final split = DmRepository.classifyPotentialRequests(
              potential,
              userPubkey: 'a' * 64,
              isFollowing: isFollowing,
            );
            DmRepository.mergeAndSort(accepted, split.followed);
            sw.stop();
            micros.add(sw.elapsedMicroseconds);
          }
          projectionByN[n] = (median: _median(micros), p99: _p99(micros));
        }

        final perWrapMedian = _median(perWrapMicros);
        final perWrapP99 = _p99(perWrapMicros);
        final verifyMedian = _median(singleVerifyMicros);
        final verifyP99 = _p99(singleVerifyMicros);
        final sha256Median = _median(singleSha256Micros);
        final burstMedian = _median(perBurstMicros);
        final burstP99 = _p99(perBurstMicros);
        // The realistic per-frame main-isolate cost: one inter-await burst
        // (1 verify + 1 sha256) + one projection recompute at the largest N.
        final worstProjectionMs = projectionByN[1000]!.p99;
        final perFrameP99 = burstP99 + worstProjectionMs;

        final summary = StringBuffer()
          ..writeln(
            '================ #5413 BACKFILL MAIN-ISOLATE COST ================',
          )
          ..writeln(
            'device refreshRate=${refreshHz.toStringAsFixed(1)}Hz '
            'frameBudget=${frameBudgetMs.toStringAsFixed(2)}ms',
          )
          ..writeln(
            'single Schnorr verify (isSigned): '
            'median=${verifyMedian.toStringAsFixed(3)}ms '
            'p99=${verifyP99.toStringAsFixed(3)}ms',
          )
          ..writeln(
            'single sha256 (isValid): '
            'median=${sha256Median.toStringAsFixed(3)}ms',
          )
          ..writeln(
            'full per-wrap validation (2x verify + 2x sha256): '
            'median=${perWrapMedian.toStringAsFixed(3)}ms '
            'p99=${perWrapP99.toStringAsFixed(3)}ms',
          )
          ..writeln('projection (classify+mergeAndSort) per emission:');
        for (final n in const [200, 500, 1000]) {
          final p = projectionByN[n]!;
          summary.writeln(
            '  N=$n: median=${p.median.toStringAsFixed(3)}ms '
            'p99=${p.p99.toStringAsFixed(3)}ms',
          );
        }
        summary
          ..writeln(
            'REALISTIC per-frame main-isolate cost (the decision metric):',
          )
          ..writeln(
            '  one inter-await burst (1 verify + 1 sha256), p99 = '
            '${burstP99.toStringAsFixed(2)}ms (median '
            '${burstMedian.toStringAsFixed(2)}ms)',
          )
          ..writeln(
            '  + projection @N=1000 (p99) = '
            '${worstProjectionMs.toStringAsFixed(2)}ms',
          )
          ..writeln(
            '  = ${perFrameP99.toStringAsFixed(2)}ms vs budget '
            '${frameBudgetMs.toStringAsFixed(2)}ms '
            '(${perFrameP99 <= frameBudgetMs ? "WITHIN" : "OVER"})',
          )
          ..writeln(
            'WHY one burst, not 16: getRumorEvent splits the two verifies with an '
            'awaited off-isolate nip44Decrypt RPC (~235ms observed), and the WS3 '
            'yield fires every 16 wraps — so verifies never accumulate within a '
            'frame. The Schnorr verify, not the projection (~0.06ms), is the '
            'dominant main-isolate cost. Numbers are for THIS device class; a '
            'low-end Android verify is materially slower (extrapolate up).',
          )
          ..writeln(
            '=================================================================',
          );
        // This benchmark's result is a human-readable console report.
        // ignore: avoid_print
        print(summary);

        // The realistic per-frame unit (one inter-await burst) must fit a frame
        // on this device class. (We report, not gate, the low-end extrapolation.)
        expect(
          burstP99,
          lessThan(frameBudgetMs),
          reason:
              'one inter-await validation burst must fit the frame budget '
              'on this device class',
        );
      },
    );
  });
}
