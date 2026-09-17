// ABOUTME: Pins the persisted editor-history form: repeated metas become
// ABOUTME: references, proof manifests are stored once, and loads round-trip

import 'dart:convert';

import 'package:collection/collection.dart' show DeepCollectionEquality;
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/editor_state_history_compaction.dart';

const _deepEquals = DeepCollectionEquality();

/// A ~10 KB attestation, the size a recorded clip's manifest has on device.
final String _manifestA = jsonEncode({
  'hash': 'a' * 64,
  'deviceAttestation': 'A' * 10000,
});
final String _manifestB = jsonEncode({
  'hash': 'b' * 64,
  'deviceAttestation': 'B' * 10000,
});

Map<String, dynamic> _clip(String id, String manifest, {int trimEndMs = 0}) => {
  'id': id,
  'filePath': '$id.mp4',
  'durationMs': 2000,
  'trimEndMs': trimEndMs,
  'proofManifestJson': manifest,
};

/// The meta the editor writes into a history entry: the clip list plus the
/// audio tracks and markers that travel with it.
Map<String, dynamic> _meta({int trimEndMs = 0}) => {
  'clips': [
    _clip('clip_a', _manifestA, trimEndMs: trimEndMs),
    _clip('clip_b', _manifestB),
  ],
  'audio': <Object?>[],
  'timelineMarkers': [500],
};

/// Mirrors `addHistory`: a fresh map tree per entry with shared leaf values.
Map<String, dynamic> _copy(Map<String, dynamic> meta) =>
    jsonDecode(jsonEncode(meta)) as Map<String, dynamic>;

Map<String, dynamic> _entry({Map<String, dynamic>? meta, int layer = 0}) => {
  'layers': [
    {'id': 'text_1', 'x': layer * 10},
  ],
  'meta': ?meta,
};

Map<String, dynamic> _export(List<Map<String, dynamic>> history) => {
  'version': '1.0.0',
  'position': history.length - 1,
  'history': history,
  'references': {
    'text_1': {'type': 'text', 'text': 'Hello'},
  },
};

List<Map<String, dynamic>> _entriesOf(Map<String, dynamic> history) =>
    (history['history'] as List).cast<Map<String, dynamic>>();

void main() {
  group('compactEditorStateHistory', () {
    test('stores a meta identical to the previous entry as a reference', () {
      final meta = _meta();
      final compact = compactEditorStateHistory(
        _export([
          _entry(meta: meta),
          _entry(meta: _copy(meta), layer: 1),
          _entry(meta: _copy(meta), layer: 2),
        ]),
      );

      final entries = _entriesOf(compact);
      expect(entries[0].containsKey('meta'), isTrue);
      expect(entries[1], isNot(contains('meta')));
      expect(entries[1][historyMetaRefKey], 0);
      expect(entries[2], isNot(contains('meta')));
      expect(entries[2][historyMetaRefKey], 0);
      expect(entries[2]['layers'], [
        {'id': 'text_1', 'x': 20},
      ]);
    });

    test('keeps a meta that differs from the previous one', () {
      final compact = compactEditorStateHistory(
        _export([
          _entry(meta: _meta()),
          _entry(meta: _meta(trimEndMs: 1500), layer: 1),
          _entry(meta: _meta(trimEndMs: 1500), layer: 2),
        ]),
      );

      final entries = _entriesOf(compact);
      expect(entries[0].containsKey('meta'), isTrue);
      expect(entries[1].containsKey('meta'), isTrue);
      expect(entries[1], isNot(contains(historyMetaRefKey)));
      expect(
        ((entries[1]['meta'] as Map)['clips'] as List).first,
        containsPair('trimEndMs', 1500),
      );
      expect(entries[2][historyMetaRefKey], 1);
    });

    // `DeepCollectionEquality` calls 1 and 1.0 equal, so this pair deduped
    // and the double came back an int — enough to throw in any consumer
    // reading a volume, a playback speed or a layer scale back out.
    test('keeps a double apart from the int that equals it', () {
      final export = _export([
        _entry(meta: {'volume': 1}),
        _entry(meta: {'volume': 1.0}, layer: 1),
      ]);

      final compact = compactEditorStateHistory(export);
      expect(_entriesOf(compact)[1], isNot(contains(historyMetaRefKey)));

      final expanded = expandEditorStateHistory(compact);
      final restored = (_entriesOf(expanded)[1]['meta']! as Map)['volume'];
      expect(restored, isA<double>());
      expect(restored, 1.0);
    });

    test('skips entries without a meta without breaking the run', () {
      final meta = _meta();
      final compact = compactEditorStateHistory(
        _export([
          _entry(meta: meta),
          _entry(layer: 1),
          _entry(meta: _copy(meta), layer: 2),
        ]),
      );

      final entries = _entriesOf(compact);
      expect(entries[1], isNot(contains('meta')));
      expect(entries[1], isNot(contains(historyMetaRefKey)));
      expect(entries[2][historyMetaRefKey], 0);
    });

    test('interns every proof manifest once', () {
      final compact = compactEditorStateHistory(
        _export([
          _entry(meta: _meta()),
          _entry(meta: _meta(trimEndMs: 1500), layer: 1),
        ]),
      );

      expect(compact[proofManifestsKey], [_manifestA, _manifestB]);
      for (final entry in _entriesOf(compact)) {
        final clips = (entry['meta'] as Map)['clips'] as List;
        expect(
          clips.map((c) => (c as Map)[proofManifestRefKey]),
          [0, 1],
        );
        expect(clips.map((c) => (c as Map).containsKey('proofManifestJson')), [
          false,
          false,
        ]);
      }
    });

    test('interns a manifest carried by a layer reference', () {
      final export = _export([_entry(meta: _meta())]);
      export['references'] = {
        'detached_1': {
          'type': 'widget',
          'clip': _clip('clip_a', _manifestA),
        },
      };

      final compact = compactEditorStateHistory(export);

      expect(compact[proofManifestsKey], [_manifestA, _manifestB]);
      final reference = (compact['references'] as Map)['detached_1'] as Map;
      expect((reference['clip'] as Map)[proofManifestRefKey], 0);
    });

    // A minified export marks itself with `m`, not the literal `minify`:
    // the exporter writes `'minify'.toMainKey(minifier)` and the minifier
    // maps that name to `m`. Keying the bail-out on `minify` made it dead
    // code that only passed because `history` minifies to `h` as well.
    test('leaves a minified export unchanged', () {
      final export = <String, dynamic>{
        'm': true,
        'h': [
          {'meta': _meta()},
          {'meta': _copy(_meta())},
        ],
      };

      expect(identical(compactEditorStateHistory(export), export), isTrue);
    });

    test('leaves a minified export unchanged even when it spells out '
        'history', () {
      final export = _export([_entry(meta: _meta()), _entry(meta: _meta())])
        ..['m'] = true;

      expect(identical(compactEditorStateHistory(export), export), isTrue);
    });

    // An unconditional write would put an empty table into every draft that
    // has no manifests, which makes the load see a table, skip the
    // legacy/no-op fast path, and rebuild the whole history for nothing.
    test('writes no manifest table when nothing carries a manifest', () {
      final compact = compactEditorStateHistory(
        _export([
          _entry(meta: {'clips': <Object?>[], 'audio': <Object?>[]}),
          _entry(meta: {'clips': <Object?>[], 'audio': <Object?>[]}, layer: 1),
        ]),
      );

      expect(compact, isNot(contains(proofManifestsKey)));
    });

    test('leaves an export without history entries unchanged', () {
      final export = _export([]);

      expect(identical(compactEditorStateHistory(export), export), isTrue);
    });

    // Compaction runs on the live editor map, not a decoded one, so a map
    // the editor built with a non-String key reached `Map.from` and threw
    // out of `toJson` mid-autosave.
    test('leaves a map holding a non-String key alone instead of throwing', () {
      final export = _export([
        _entry(
          meta: {
            'weird': <Object?, Object?>{
              1: 'int-key',
              'clip': _clip('clip_a', _manifestA),
            },
          },
        ),
      ]);

      final compact = compactEditorStateHistory(export);

      final weird =
          (_entriesOf(compact)[0]['meta'] as Map)['weird']
              as Map<Object?, Object?>;
      expect(weird[1], 'int-key');
      expect((weird['clip'] as Map)['proofManifestJson'], _manifestA);
    });

    test('does not mutate its input', () {
      final meta = _meta();
      final export = _export([
        _entry(meta: meta),
        _entry(meta: _copy(meta), layer: 1),
      ]);
      final before = jsonEncode(export);
      expect(before, contains('"proofManifestJson"'));

      compactEditorStateHistory(export);

      expect(jsonEncode(export), before);
    });

    // The shape from #9206: one text layer dragged around a draft whose clips
    // carry attestations. Every drag re-stored the whole clip list.
    test('stops the stored size growing with layer-only edits', () {
      final meta = _meta();
      final twoEdits = _export([
        _entry(meta: meta),
        _entry(meta: _copy(meta), layer: 1),
      ]);
      final twentyEdits = _export([
        for (var i = 0; i < 20; i++) _entry(meta: _copy(meta), layer: i),
      ]);

      final twoEditsBytes = jsonEncode(
        compactEditorStateHistory(twoEdits),
      ).length;
      final twentyEditsBytes = jsonEncode(
        compactEditorStateHistory(twentyEdits),
      ).length;

      // 18 more entries cost their layer deltas only, not 18 clip lists.
      expect(twentyEditsBytes - twoEditsBytes, lessThan(2000));
      expect(
        twentyEditsBytes,
        lessThan(jsonEncode(twentyEdits).length ~/ 10),
      );
    });
  });

  group('expandEditorStateHistory', () {
    test('restores the compact form to the exported one', () {
      final meta = _meta();
      final export = _export([
        _entry(meta: meta),
        _entry(meta: _copy(meta), layer: 1),
        _entry(layer: 2),
        _entry(meta: _meta(trimEndMs: 1500), layer: 3),
        _entry(meta: _meta(trimEndMs: 1500), layer: 4),
      ]);

      final stored = jsonDecode(
        jsonEncode(compactEditorStateHistory(export)),
      );
      final expanded = expandEditorStateHistory(
        stored as Map<String, dynamic>,
      );

      expect(_deepEquals.equals(expanded, export), isTrue);
      expect(expanded, isNot(contains(proofManifestsKey)));
    });

    test('returns a history saved before compaction unchanged', () {
      final legacy = _export([
        _entry(meta: _meta()),
        _entry(meta: _meta(), layer: 1),
      ]);

      expect(identical(expandEditorStateHistory(legacy), legacy), isTrue);
    });

    test('gives each referenced entry its own meta map', () {
      final meta = _meta();
      final expanded = expandEditorStateHistory(
        compactEditorStateHistory(
          _export([_entry(meta: meta), _entry(meta: _copy(meta), layer: 1)]),
        ),
      );

      final entries = _entriesOf(expanded);
      final first = entries[0]['meta'] as Map<String, dynamic>;
      final second = entries[1]['meta'] as Map<String, dynamic>;
      expect(identical(first, second), isFalse);

      // The editor writes into the active entry's meta in place; the entry it
      // was copied from must not see that write. Replacing a whole top-level
      // key passes with a shallow copy too, so the assertion that pins the
      // invariant is the in-place one on the nested list.
      second['clips'] = <Object?>[];
      expect(first['clips'], hasLength(2));
    });

    test('gives each referenced entry its own nested clip and audio lists', () {
      final meta = _meta();
      final expanded = expandEditorStateHistory(
        compactEditorStateHistory(
          _export([_entry(meta: meta), _entry(meta: _copy(meta), layer: 1)]),
        ),
      );

      final entries = _entriesOf(expanded);
      final first = entries[0]['meta']! as Map<String, dynamic>;
      final second = entries[1]['meta']! as Map<String, dynamic>;

      expect(identical(first['clips'], second['clips']), isFalse);
      (second['clips']! as List).clear();
      expect(first['clips'], hasLength(2));

      // An undo restoring a shared clip map would replay the edit it undoes.
      ((first['clips']! as List).first as Map)['trimEndMs'] = 999;
      expect(
        ((_entriesOf(expanded)[0]['meta']! as Map)['clips']! as List).first,
        containsPair('trimEndMs', 999),
      );
    });

    // Removing the reference as well would leave the entry indistinguishable
    // from one that never had a meta, and the next autosave would write that
    // back as the new truth.
    test(
      'keeps a meta reference that points nowhere so the gap stays visible',
      () {
        final export = _export([
          _entry(meta: _meta()),
          _entry(layer: 1)..[historyMetaRefKey] = 7,
        ]);

        final expanded = expandEditorStateHistory(export);

        final entries = _entriesOf(expanded);
        expect(entries[1][historyMetaRefKey], 7);
        expect(entries[1], isNot(contains('meta')));
        expect(
          editorStateHistoryHasUnresolvedMetaReferences(expanded),
          isTrue,
        );
      },
    );

    // A reference may only point at an entry already expanded. A forward one
    // would read a target whose own meta has not been restored yet, so the
    // bound is backward-only rather than merely in range.
    test('does not resolve a reference pointing forward', () {
      final export = _export([
        _entry()..[historyMetaRefKey] = 1,
        _entry(meta: _meta(), layer: 1),
      ]);

      final entries = _entriesOf(expandEditorStateHistory(export));

      expect(entries[0], isNot(contains('meta')));
      expect(entries[0][historyMetaRefKey], 1);
    });

    test('does not resolve a reference pointing at itself', () {
      final export = _export([_entry(layer: 0)..[historyMetaRefKey] = 0]);

      final entries = _entriesOf(expandEditorStateHistory(export));

      expect(entries[0], isNot(contains('meta')));
      expect(entries[0][historyMetaRefKey], 0);
    });

    test('reports no unresolved meta references once every one resolves', () {
      final meta = _meta();
      final expanded = expandEditorStateHistory(
        compactEditorStateHistory(
          _export([_entry(meta: meta), _entry(meta: _copy(meta), layer: 1)]),
        ),
      );

      expect(_entriesOf(expanded)[1]['meta'], isNotNull);
      expect(
        editorStateHistoryHasUnresolvedMetaReferences(expanded),
        isFalse,
      );
    });

    // A manifest reference is dropped rather than kept: the table is rebuilt
    // on every save, so a stale index could later land inside a larger table
    // and resolve to a different clip's attestation.
    test('drops a manifest reference that points nowhere', () {
      final expanded = expandEditorStateHistory(<String, dynamic>{
        proofManifestsKey: [_manifestA],
        'history': [
          {
            'meta': {
              'clips': [
                {'id': 'clip_a', proofManifestRefKey: 9},
              ],
            },
          },
        ],
      });

      final clip =
          ((_entriesOf(expanded)[0]['meta'] as Map)['clips'] as List).first
              as Map;
      expect(clip, isNot(contains(proofManifestRefKey)));
      expect(clip, isNot(contains('proofManifestJson')));
      expect(clip['id'], 'clip_a');
    });

    // The reserved names are app-namespaced because `meta` is free-form
    // space the editor owns. Before that, expansion rewrote any map in the
    // tree that happened to hold one of these names.
    test(
      'leaves an app-owned key that merely looks like a reference alone',
      () {
        final legacy = <String, dynamic>{
          'history': [
            {
              'meta': {'a': 1},
            },
            {'metaRef': 0},
            {
              'layers': [
                {'id': 'l1', 'proofManifestRef': 0},
              ],
            },
          ],
          'proofManifests': 'not ours',
        };

        final expanded = expandEditorStateHistory(legacy);

        expect(identical(expanded, legacy), isTrue);
        final entries = _entriesOf(expanded);
        expect(entries[1], isNot(contains('meta')));
        expect(entries[1]['metaRef'], 0);
        expect((entries[2]['layers'] as List).first, {
          'id': 'l1',
          'proofManifestRef': 0,
        });
        expect(expanded['proofManifests'], 'not ours');
      },
    );

    test('does not mutate its input', () {
      final stored = compactEditorStateHistory(
        _export([_entry(meta: _meta()), _entry(meta: _meta(), layer: 1)]),
      );
      final before = jsonEncode(stored);
      expect(before, contains('"$historyMetaRefKey"'));

      expandEditorStateHistory(stored);

      expect(jsonEncode(stored), before);
    });
  });
}
