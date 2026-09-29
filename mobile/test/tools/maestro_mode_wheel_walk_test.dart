// ABOUTME: Pins that Maestro helpers reach a recorder mode by walking the mode
// ABOUTME: wheel one entry at a time, in the order the app declares the modes.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:yaml/yaml.dart';

const _maestroDir = 'e2e/maestro';

/// A tap on a mode-wheel entry, and whether an enclosing `runFlow` runs it
/// only while that entry is on screen.
typedef _WheelTap = ({VideoRecorderMode mode, bool onlyWhenShown});

/// The mode whose wheel entry carries [id], or null for any other control.
VideoRecorderMode? _modeOf(Object? id) {
  for (final mode in VideoRecorderMode.values) {
    if (id == SemanticIds.cameraMode(mode.name)) return mode;
  }
  return null;
}

/// The wheel taps under [node], in the order Maestro reaches them.
///
/// [shown] holds the ids an enclosing `runFlow` requires to be visible, so a
/// tap nested under `when: visible` on its own entry reads as conditional.
List<_WheelTap> _wheelTaps(Object? node, [Set<Object?> shown = const {}]) {
  if (node is List) {
    return [for (final child in node) ..._wheelTaps(child, shown)];
  }
  if (node is! YamlMap) return const [];

  final tap = node['tapOn'];
  final id = tap is YamlMap ? tap['id'] : null;
  final mode = _modeOf(id);
  if (mode != null) return [(mode: mode, onlyWhenShown: shown.contains(id))];

  final flow = node['runFlow'];
  final condition = flow is YamlMap ? flow['when'] : null;
  final visible = condition is YamlMap ? condition['visible'] : null;
  final scope = visible is YamlMap ? {...shown, visible['id']} : shown;
  return [for (final child in node.values) ..._wheelTaps(child, scope)];
}

/// The commands of [flow]: its last YAML document, after any config header.
Object? _commandsOf(File flow) {
  final documents = loadYamlDocuments(flow.readAsStringSync());
  return documents.isEmpty ? null : documents.last.contents.value;
}

void main() {
  group('Maestro mode-wheel walk', () {
    final files =
        Directory(_maestroDir)
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.yaml'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final walks = {
      for (final file in files) file.path: _wheelTaps(_commandsOf(file)),
    }..removeWhere((_, taps) => taps.isEmpty);

    test('still finds the helpers that select a mode', () {
      // Every check below skips a flow that taps no wheel entry, so an empty
      // set would pass them all for the wrong reason.
      expect(walks.keys, contains(endsWith('utils/openClassicMode.yaml')));
    });

    test('each helper taps every entry between Capture and its mode', () {
      for (final MapEntry(key: path, value: taps) in walks.entries) {
        final target = taps.last.mode;
        expect(
          taps.map((tap) => tap.mode),
          orderedEquals(
            VideoRecorderMode.values.sublist(
              VideoRecorderMode.capture.index + 1,
              target.index + 1,
            ),
          ),
          reason:
              '$path selects ${target.name} starting from Capture, where the '
              'recorder opens after a clearState. The wheel is a lazy '
              'ListView that only builds entries near the armed one, so each '
              "tap has to land on the armed entry's neighbour: tap every "
              'entry in between, in the order VideoRecorderMode declares.',
        );
      }
    });

    test('taps an entry the wheel can leave out only while it shows', () {
      final optional = VideoRecorderMode.values.toSet().difference(
        VideoRecorderMode.available(liveChromaKeySupported: false).toSet(),
      );
      expect(optional, isNotEmpty);

      for (final MapEntry(key: path, value: taps) in walks.entries) {
        for (final tap in taps.where((tap) => optional.contains(tap.mode))) {
          expect(
            tap.onlyWhenShown,
            isTrue,
            reason:
                '$path taps ${tap.mode.name}, which the wheel leaves out on '
                'a renderer without shader image filters. Put the tap under '
                'a runFlow with `when: visible` on the same id, or the flow '
                'fails on those devices.',
          );
        }
      }
    });

    group('detector', () {
      test('reads a tap under `when: visible` on its own entry as '
          'conditional', () {
        final chromaKey = SemanticIds.cameraMode(
          VideoRecorderMode.chromaKey.name,
        );
        final classic = SemanticIds.cameraMode(VideoRecorderMode.classic.name);

        final taps = _wheelTaps(
          loadYaml('''
- runFlow:
    when:
      notVisible:
        id: $classic
    commands:
      - tapOn:
          id: $chromaKey
      - assertVisible:
          id: $classic
- runFlow:
    when:
      visible:
        id: $chromaKey
    commands:
      - tapOn:
          id: $chromaKey
'''),
        );

        expect(taps, [
          (mode: VideoRecorderMode.chromaKey, onlyWhenShown: false),
          (mode: VideoRecorderMode.chromaKey, onlyWhenShown: true),
        ]);
      });
    });
  });
}
