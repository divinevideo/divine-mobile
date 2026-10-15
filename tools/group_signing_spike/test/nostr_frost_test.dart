// Throwaway feasibility probe. Local participants share a test process; this
// proves the Dart/native boundary and output format, not a secure transport.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bip340/bip340.dart' as bip340;
import 'package:coinlib/coinlib.dart' as coin;
import 'package:crypto/crypto.dart';
import 'package:frosty/frosty.dart';
import 'package:test/test.dart';

// Import the real SDK implementation without changing the mobile workspace.
import '../../../mobile/packages/nostr_sdk/lib/event.dart' as nostr;

List<ParticipantKeyInfo> ceremony(int threshold, int n) {
  final ids = List.generate(n, (i) => Identifier.fromUint16(i + 1));
  final first = List.generate(
    n,
    (i) => DkgPart1(identifier: ids[i], threshold: threshold, n: n),
  );
  // An identical transcript is supplied to every participant in this harness.
  // Network delivery would require authenticated transcript agreement first.
  final transcript = DkgCommitmentSet([
    for (var i = 0; i < n; i++) (ids[i], first[i].public),
  ]);
  final second = List.generate(
    n,
    (i) => DkgPart2(
      identifier: ids[i],
      round1Secret: first[i].secret,
      commitments: transcript,
    ),
  );
  final infos = List.generate(
    n,
    (i) => DkgPart3(
      identifier: ids[i],
      round2Secret: second[i].secret,
      commitments: transcript,
      receivedShares: {
        for (var j = 0; j < n; j++)
          if (j != i) ids[j]: second[j].sharesToGive[ids[i]]!,
      },
    ).participantInfo,
  );
  for (final round in first) {
    round.secret.dispose();
    round.public.dispose();
  }
  for (final round in second) {
    round.secret.dispose();
    for (final share in round.sharesToGive.values) {
      share.dispose();
    }
  }
  expect(infos.map((i) => coin.bytesToHex(i.groupKey.x)).toSet().length, 1);
  return infos;
}

/// Owns a nonce for one immutable event ID. The upstream wrapper itself does
/// not consume nonces: this probe deliberately destroys one before returning.
class OneUseApproval {
  OneUseApproval(this.info, Uint8List message)
    : message = Uint8List.fromList(message).asUnmodifiableView(),
      _round = SignPart1(privateShare: info.private.share);
  final ParticipantKeyInfo info;
  final Uint8List message;
  final SignPart1 _round;
  bool _used = false;
  SigningCommitment get commitment => _round.commitment;

  SignatureShare sign(SigningCommitmentSet commitments) {
    if (_used) throw StateError('Approval already consumed');
    _used = true;
    try {
      return SignPart2(
        identifier: info.private.identifier,
        details: SignDetails.scriptSpend(message: message),
        ourNonces: _round.nonces,
        commitments: commitments,
        info: info.signing,
      ).share;
    } finally {
      _round.nonces.dispose();
    }
  }
}

Map<String, dynamic> unsigned(ParticipantKeyInfo info) => {
  'pubkey': coin.bytesToHex(info.groupKey.x),
  'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
  'kind': 30005,
  'tags': [
    ['d', 'divine-group-signing-spike'],
    ['title', 'Group signing prototype'],
    ['description', 'Synthetic threshold signing compatibility test'],
  ],
  'content': '',
};

Uint8List eventId(Map<String, dynamic> event) => Uint8List.fromList(
  sha256
      .convert(
        utf8.encode(
          jsonEncode([
            0,
            event['pubkey'],
            event['created_at'],
            event['kind'],
            event['tags'],
            event['content'],
          ]),
        ),
      )
      .bytes,
);

Map<String, dynamic> signEvent(
  List<ParticipantKeyInfo> infos,
  List<int> signers,
) {
  final event = unsigned(infos.first);
  final message = eventId(event);
  final approvals = [
    for (final i in signers) OneUseApproval(infos[i], message),
  ];
  final commitments = SigningCommitmentSet({
    for (final approval in approvals)
      approval.info.private.identifier: approval.commitment,
  });
  final shares = [
    for (final approval in approvals)
      (approval.info.private.identifier, approval.sign(commitments)),
  ];
  // Retrying the same approval must fail, even for the same message.
  for (final approval in approvals) {
    expect(() => approval.sign(commitments), throwsStateError);
  }
  final signature = SignatureAggregation(
    commitments: commitments,
    details: SignDetails.scriptSpend(message: message),
    shares: shares,
    info: infos.first.aggregate,
  ).signature;
  expect(signature.data.length, 64);
  expect(signature.verify(infos.first.groupKey, message), isTrue);
  final id = coin.bytesToHex(message);
  final sig = coin.bytesToHex(signature.data);
  expect(bip340.verify(event['pubkey'] as String, id, sig), isTrue);
  final changed = Uint8List.fromList(message)..[0] ^= 1;
  expect(
    bip340.verify(event['pubkey'] as String, coin.bytesToHex(changed), sig),
    isFalse,
  );
  for (final approval in approvals) {
    approval.commitment.dispose();
  }
  for (final share in shares) {
    share.$2.dispose();
  }
  final signed = {...event, 'id': id, 'sig': sig};
  final parsed = nostr.Event.fromJson(signed);
  expect(parsed.isValid, isTrue);
  expect(parsed.isSigned, isTrue);
  expect(
    nostr.Event.fromJson({...signed, 'content': 'tampered'}).isValid,
    isFalse,
  );
  return signed;
}

void main() {
  setUpAll(() async {
    await coin.loadCoinlib();
    await loadFrosty();
  });

  test('2-of-2 dealerless DKG signs a Nostr event', () {
    signEvent(ceremony(2, 2), [0, 1]);
  });
  test('each 2-of-3 subset signs; a non-signer can remain offline', () {
    final infos = ceremony(2, 3);
    for (final subset in [
      [0, 1],
      [0, 2],
      [1, 2],
    ]) {
      final event = signEvent(infos, subset);
      final exportPath = Platform.environment['GROUP_SIGNING_SPIKE_EVENT_PATH'];
      if (exportPath != null)
        File(exportPath).writeAsStringSync(jsonEncode(event));
    }
  });
  test('3-of-3 DKG signs with all three participants', () {
    signEvent(ceremony(3, 3), [0, 1, 2]);
  });
  test(
    'fresh approvals use distinct nonce commitments and immutable messages',
    () {
      final info = ceremony(2, 2).first;
      final input = eventId(unsigned(info));
      final first = OneUseApproval(info, input);
      final second = OneUseApproval(info, input);
      input[0] ^= 1;
      expect(first.message[0] != input[0], isTrue);
      expect(() => first.message[0] ^= 1, throwsUnsupportedError);
      expect(
        coin.bytesEqual(
          first.commitment.toBytes(),
          second.commitment.toBytes(),
        ),
        isFalse,
      );
      first._round.nonces.dispose();
      first.commitment.dispose();
      second._round.nonces.dispose();
      second.commitment.dispose();
    },
  );
  test('one participant cannot sign for a 2-of-3 group', () {
    final infos = ceremony(2, 3);
    final approval = OneUseApproval(
      infos.first,
      eventId(unsigned(infos.first)),
    );
    final commitments = SigningCommitmentSet({
      infos.first.private.identifier: approval.commitment,
    });
    expect(() => approval.sign(commitments), throwsA(isA<InvalidSignPart2>()));
    expect(() => approval.sign(commitments), throwsStateError);
    approval.commitment.dispose();
  });
  test('missing DKG participant prevents completing the ceremony', () {
    final id = Identifier.fromUint16(1);
    final first = DkgPart1(identifier: id, threshold: 2, n: 3);
    expect(
      () => DkgPart2(
        identifier: id,
        round1Secret: first.secret,
        commitments: DkgCommitmentSet([(id, first.public)]),
      ),
      throwsA(isA<InvalidPart2>()),
    );
    first.secret.dispose();
    first.public.dispose();
  });
}
