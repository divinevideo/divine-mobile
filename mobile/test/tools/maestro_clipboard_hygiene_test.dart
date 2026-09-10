// ABOUTME: Pins that a Maestro flow copying the private key also clears it.
// ABOUTME: The copy is the journey under test; the key left behind is not.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// The control whose tap puts the signed-in account's `nsec` on the device
/// clipboard.
///
/// Asserting the button is *visible* is harmless and several flows do it;
/// only a tap moves key material, so this guard keys on the tap.
const _copyPrivateKeyId = 'copy_nsec_button';

/// Maestro's command for overwriting the clipboard with a literal.
///
/// Present in the pinned CLI (`MAESTRO_VERSION` in `codemagic.yaml`).
const _setClipboard = 'setClipboard';

const _maestroDir = 'e2e/maestro';

/// Every command in a flow, in order.
///
/// A Maestro flow is two YAML documents — an `appId`/`tags` header, then the
/// command list — so the commands are the last document rather than the
/// first.
List<Object?> _commandsOf(File flow) {
  final documents = loadYamlDocuments(flow.readAsStringSync());
  if (documents.isEmpty) return const [];
  final commands = documents.last.contents.value;
  return commands is YamlList ? commands.toList() : const [];
}

/// Whether [command] is a `tapOn` naming [id].
///
/// Maestro accepts both the nested (`tapOn:` then `id:`) and inline forms, so
/// this reads the argument as a map rather than matching source text.
bool _tapsId(Object? command, String id) {
  if (command is! YamlMap) return false;
  final argument = command['tapOn'];
  return argument is YamlMap && argument['id'] == id;
}

bool _isSetClipboard(Object? command) =>
    command is YamlMap && command.containsKey(_setClipboard);

void main() {
  group('Maestro clipboard hygiene', () {
    final flows =
        Directory(_maestroDir)
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.yaml'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    test('the suite is present and readable', () {
      // A guard over an empty set passes for the wrong reason; #8777 is
      // exactly the kind of change that can move these files.
      expect(flows, isNotEmpty, reason: 'no flows found under $_maestroDir');
      expect(
        flows.map((file) => file.path),
        contains(contains('backupYourKey.yaml')),
      );
    });

    test('a flow that copies the private key clears the clipboard after', () {
      for (final flow in flows) {
        final commands = _commandsOf(flow);
        final tapIndex = commands.indexWhere(
          (command) => _tapsId(command, _copyPrivateKeyId),
        );
        if (tapIndex < 0) continue;

        final clearIndex = commands.indexWhere(_isSetClipboard);
        expect(
          clearIndex,
          greaterThan(tapIndex),
          reason:
              '${flow.path} taps $_copyPrivateKeyId, which copies a live '
              "account's private key to the device clipboard. The flow must "
              'overwrite it with `$_setClipboard` before it ends, or the key '
              'outlives the run on a shared device (#8828).',
        );
      }
    });
  });
}
