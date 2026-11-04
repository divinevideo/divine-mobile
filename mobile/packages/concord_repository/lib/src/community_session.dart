// MPL-2.0
import 'dart:async';
import 'dart:convert';

import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/src/concord_repository.dart';
import 'package:concord_repository/src/sealed_transport.dart';

/// One account's live, verified public-community read session. The invitation
/// opens read material; the signed owner-rooted plane supplies every room.
class ConcordCommunitySession {
  ConcordCommunitySession({
    required this.relay,
    required this.store,
    required this.linkSigner,
    required this.fragment,
    required this.account,
    int Function()? nowMs,
  }) : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);
  final RelayGateway relay;
  final AccountScopedStore store;
  final String linkSigner;
  final ConcordInviteFragment fragment;
  final String account;
  final int Function() _nowMs;
  final _changes = StreamController<void>.broadcast();
  final _subscriptions = <StreamSubscription<Map<String, dynamic>>>[];
  final _wraps = <String, Map<String, dynamic>>{};
  final _editions = <String, ConcordEdition>{};
  Map<String, ConcordEdition> _acceptedHeads = {};
  final _heldRoots = <int, ConcordInviteBundle>{};
  final _snapshotIds = <String>{};
  Future<void> _work = Future.value();
  Future<void>? _starting;
  Future<void>? _closing;
  ConcordInviteBundle? bundle;
  ConcordControlState? control;
  Object? failure;
  bool _closed = false;
  bool _loaded = false;
  int _pending = 0;
  bool get canPublish =>
      ready &&
      _pending == 0 &&
      (relay is! RelaySynchronizationStatus ||
          (relay as RelaySynchronizationStatus).synchronized);
  Iterable<ConcordInviteBundle> get heldMembership =>
      List.unmodifiable(_heldRoots.values);
  Stream<void> get changes => _changes.stream;
  bool get ready =>
      _loaded &&
      !_closed &&
      failure == null &&
      control != null &&
      control!.name != null &&
      control!.publicChannels.isNotEmpty &&
      control!.incomplete.isEmpty &&
      !control!.banned.contains(account);

  void _notify() {
    if (!_closed) _changes.add(null);
  }

  void _fail(Object error) {
    failure = error;
    _notify();
  }

  void _enqueue(Future<void> Function() action) {
    _pending++;
    _work = _work.then((_) async {
      try {
        if (!_closed) await action();
      } on Object catch (error) {
        _fail(error);
      } finally {
        _pending--;
      }
    });
  }

  Future<void> start() {
    if (_closed) return Future.error(StateError('Community session is closed'));
    return _starting ??= _start();
  }

  Future<void> _start() async {
    try {
      final candidates = <Map<String, dynamic>>[];
      _subscriptions.add(
        relay
            .subscribe({
              'kinds': [33301],
              'authors': [linkSigner],
              '#d': [''],
              'limit': 2,
            })
            .listen((event) {
              if (!_loaded) {
                candidates.add(event);
                return;
              }
              _enqueue(() async {
                final refreshed = await openInviteBundle(
                  event: event,
                  expectedSigner: linkSigner,
                  token: fragment.token,
                  nowMs: _nowMs(),
                );
                if (refreshed.communityId != bundle!.communityId ||
                    refreshed.communityRoot != bundle!.communityRoot ||
                    refreshed.rootEpoch != bundle!.rootEpoch ||
                    refreshed.controlPubkey != bundle!.controlPubkey) {
                  throw StateError(
                    'Community membership changed; reopen Rooms to refresh',
                  );
                }
              });
            }, onError: _fail),
      );
      if (relay is! RelayHistoryStatus) {
        throw StateError('Community history boundary unavailable');
      }
      await (relay as RelayHistoryStatus).historyReady;
      if (_closed) return;
      if (candidates.isEmpty) {
        throw StateError('Community invitation was not found');
      }
      candidates.sort((a, b) {
        final timestamp = (b['created_at'] as int).compareTo(
          a['created_at'] as int,
        );
        return timestamp == 0
            ? (a['id'] as String).compareTo(b['id'] as String)
            : timestamp;
      });
      bundle = await openInviteBundle(
        event: candidates.first,
        expectedSigner: linkSigner,
        token: fragment.token,
        nowMs: _nowMs(),
      );
      if (_closed) {
        throw StateError('Community session closed during bootstrap');
      }
      final savedRoots = await store.get('community-held-roots');
      if (savedRoots != null) {
        for (final raw in jsonDecode(savedRoots) as List) {
          final held = ConcordInviteBundle.fromJson(
            Map<String, dynamic>.from(raw as Map),
            nowMs: 0,
          );
          if (held.communityId != bundle!.communityId ||
              held.owner != bundle!.owner) {
            throw StateError(
              'Saved community identity does not match invitation',
            );
          }
          if (held.rootEpoch > bundle!.rootEpoch ||
              held.rootEpoch == bundle!.rootEpoch &&
                  (held.communityRoot != bundle!.communityRoot ||
                      held.controlPubkey != bundle!.controlPubkey)) {
            throw StateError(
              'Community invitation would roll back or fork held membership',
            );
          }
          _heldRoots[held.rootEpoch] = held;
        }
      }
      _heldRoots[bundle!.rootEpoch] = bundle!;
      final stopped = await store.get('community-stop');
      if (stopped != null) {
        final stop = jsonDecode(stopped) as Map;
        if (stop['dissolved'] == true || stop['epoch'] == bundle!.rootEpoch) {
          throw StateError(
            'Community membership must be refreshed before continuing',
          );
        }
      }
      final saved = await store.get('community-control-wraps');
      if (saved != null) {
        for (final raw in jsonDecode(saved) as List) {
          final record = Map<String, dynamic>.from(raw as Map);
          if (record['epoch'] is! int ||
              record['wrap'] is! Map ||
              !_heldRoots.containsKey(record['epoch'])) {
            throw StateError('Saved community carrier lacks its held epoch');
          }
          await _acceptControl(
            Map<String, dynamic>.from(record['wrap'] as Map),
            rootEpoch: record['epoch'] as int,
            persist: false,
          );
        }
        final savedHeads = await store.get('community-control-heads');
        if (savedHeads != null) {
          for (final entry in (jsonDecode(savedHeads) as Map).entries) {
            final edition = _editions[entry.value];
            if (edition == null || edition.entityId != entry.key) {
              throw StateError('Saved community authority is incomplete');
            }
            _acceptedHeads[entry.key as String] = edition;
          }
        }
        _refold();
      }
      final read = controlReadKey(
        bundle!.communityRoot,
        bundle!.communityId,
        bundle!.rootEpoch,
      );
      if (_closed) {
        throw StateError('Community session closed during bootstrap');
      }
      _subscriptions.add(
        relay
            .subscribe({
              'kinds': [1059],
              'authors': [bundle!.controlPubkey ?? read.pubkey],
              'limit': 10000,
            })
            .listen(
              (wrap) => _enqueue(() => _acceptControl(wrap)),
              onError: _fail,
            ),
      );
      _watchTerminalSignals();
      await (relay as RelayHistoryStatus).historyReady;
      await _work;
      if ((relay as RelayHistoryStatus).historyLimited) {
        throw StateError('Community control history is incomplete');
      }
      _refold();
      if (control?.name == null || control!.publicChannels.isEmpty) {
        throw StateError('Community has no verified public rooms');
      }
      if (control!.incomplete.isNotEmpty) {
        throw StateError('Community authority history is incomplete');
      }
      if (control!.banned.contains(account)) {
        throw StateError('You cannot access this community');
      }
      await _checkSignals();
      if (failure != null) {
        throw StateError('Community membership is unavailable');
      }
      _loaded = true;
      _acceptedHeads = {...control!.heads};
      await _persist();
      _notify();
    } on Object catch (error) {
      _fail(error);
      rethrow;
    }
  }

  final _signals = <Map<String, dynamic>>[];
  void _watchTerminalSignals() {
    final held = bundle!;
    final dissolved = groupKey(
      'concord/dissolved',
      held.communityId,
      '00' * 32,
    );
    final rekey = groupKey(
      'concord/base-rekey-pseudonym',
      held.communityRoot,
      held.communityId,
      epoch: held.rootEpoch + 1,
    );
    for (final group in [dissolved, rekey]) {
      _subscriptions.add(
        relay
            .subscribe({
              'kinds': [1059, 21059],
              'authors': [group.pubkey],
              'limit': 10000,
            })
            .listen(
              (wrap) => _enqueue(() async {
                try {
                  _signals.add(
                    await openVerifiedStreamWrap(
                      wrap: wrap,
                      readKey: group,
                      streamPubkey: group.pubkey,
                    ),
                  );
                } on FormatException {
                  return;
                }
                await _checkSignals();
              }),
              onError: _fail,
            ),
      );
    }
  }

  Future<void> _checkSignals() async {
    if (control == null) return;
    for (final signal in _signals) {
      final tags = (signal['tags'] as List).cast<List<String>>();
      String? tag(String n) => tags
          .where((t) => t.isNotEmpty && t[0] == n)
          .firstOrNull
          ?.elementAtOrNull(1);
      final author = signal['author'] as String;
      final dissolved =
          signal['kind'] == 3308 &&
          signal['sealKind'] == 20014 &&
          author == bundle!.owner &&
          tag('vsk') == '10' &&
          tag('eid') == bundle!.communityId;
      final vac = tags.where((t) => t.length >= 4 && t[0] == 'vac').firstOrNull;
      final citation =
          vac != null && RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(vac[2])
          ? ConcordCitation(vac[1], int.parse(vac[2]), vac[3])
          : null;
      final rotation =
          signal['kind'] == 3303 &&
          signal['sealKind'] == 20013 &&
          tag('scope') == '00' * 32 &&
          tag('prevepoch') == '${bundle!.rootEpoch}' &&
          tag('newepoch') == '${bundle!.rootEpoch + 1}' &&
          tag('prevcommit') ==
              epochKeyCommitment(bundle!.rootEpoch, bundle!.communityRoot) &&
          !control!.banned.contains(author) &&
          control!.permits(author, 16) &&
          control!.citationSatisfied(author, citation);
      if (!dissolved && !rotation) continue;
      await store.put(
        'community-stop',
        jsonEncode({'dissolved': dissolved, 'epoch': bundle!.rootEpoch}),
      );
      _fail(
        StateError(
          dissolved
              ? 'This community has closed'
              : 'Community keys changed; reopen Rooms to refresh membership',
        ),
      );
    }
  }

  Future<void> _acceptControl(
    Map<String, dynamic> wrap, {
    bool persist = true,
    int? rootEpoch,
  }) async {
    final held = _heldRoots[rootEpoch ?? bundle!.rootEpoch]!;
    final read = controlReadKey(
      held.communityRoot,
      held.communityId,
      held.rootEpoch,
    );
    ConcordEdition edition;
    try {
      final opened = await openControlWrap(
        wrap: wrap,
        readKey: read,
        streamPubkey: held.controlPubkey ?? read.pubkey,
      );
      edition = ConcordEdition.parse(opened);
    } on FormatException {
      return;
    }
    _wraps[wrap['id'] as String] = {'epoch': held.rootEpoch, 'wrap': wrap};
    _editions[edition.rumorId] = edition;
    if (held.rootEpoch == bundle!.rootEpoch) _snapshotIds.add(edition.rumorId);
    if (_loaded) {
      _refold();
      if (persist) await _persist();
    }
  }

  Future<void> _persist() async {
    if (_closed) return;
    await store.writeBatch({
      'community-held-roots': jsonEncode([
        for (final held in _heldRoots.values)
          {
            'community_id': held.communityId,
            'owner': held.owner,
            'owner_salt': held.ownerSalt,
            'community_root': held.communityRoot,
            'root_epoch': held.rootEpoch,
            if (held.controlPubkey != null) 'control_pk': held.controlPubkey,
            'channels': <dynamic>[],
            'relays': <String>[],
          },
      ]),
      'community-control-wraps': jsonEncode(_wraps.values.toList()),
      'community-control-heads': jsonEncode({
        for (final entry in _acceptedHeads.entries)
          entry.key: entry.value.rumorId,
      }),
    });
  }

  void _refold() {
    control = foldCommunityControl(
      _editions.values.toList(),
      communityId: bundle!.communityId,
      owner: bundle!.owner,
      priorHeads: _acceptedHeads,
      snapshotIds: bundle!.rootEpoch > 0 ? _snapshotIds : const {},
    );
    if (_loaded &&
        (control!.incomplete.isNotEmpty || control!.banned.contains(account))) {
      failure = StateError(
        'Community authority changed; reopen Rooms to refresh',
      );
    }
    if (_loaded) _acceptedHeads = {...control!.heads};
    if (_signals.isNotEmpty) _enqueue(_checkSignals);
    _notify();
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _work;
    try {
      await _starting;
    } on Object {
      /* A cancelled bootstrap has still drained. */
    }
    await _changes.close();
  }
}
