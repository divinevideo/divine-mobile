// ABOUTME: Pins semantic extraction of Apple's required-reason DocC payload.
// ABOUTME: Covers Swift references, Objective-C overrides, and drift reporting.

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  final probe = File(
    'scripts/lib/apple_required_reason_probe.py',
  ).absolute.path;
  final catalogue =
      jsonDecode(
            File(
              'scripts/data/apple_required_reason_catalogue.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  Map<String, dynamic> payloadForCatalogue() {
    final references = <String, dynamic>{};
    final titlePatches = <Map<String, dynamic>>[];
    final values = <Map<String, dynamic>>[];
    final categories = catalogue['categories']! as List<dynamic>;
    for (final rawCategory in categories) {
      final category = rawCategory! as Map<String, dynamic>;
      final symbols = category['symbols']! as Map<String, dynamic>;
      final swift = symbols['swift']! as List<dynamic>;
      final objectiveC = symbols['objectiveC']! as List<dynamic>;
      final apiItems = <Map<String, dynamic>>[];
      for (var index = 0; index < swift.length; index += 1) {
        final swiftName = swift[index]! as String;
        final objectiveCName = objectiveC[index]! as String;
        Map<String, dynamic> inline;
        if (swiftName == objectiveCName) {
          inline = {'type': 'codeVoice', 'code': '$swiftName()'};
        } else {
          final reference = 'doc://test/${category['name']}/$index';
          references[reference] = {'title': swiftName};
          final pointer = reference.replaceAll('~', '~0').replaceAll('/', '~1');
          titlePatches.add({
            'op': 'replace',
            'path': '/references/$pointer/title',
            'value': objectiveCName,
          });
          inline = {'type': 'reference', 'identifier': reference};
        }
        apiItems.add({
          'content': [
            {
              'inlineContent': [inline],
            },
          ],
        });
      }
      final reasons = category['reasons']! as Map<String, dynamic>;
      values.add({
        'name': category['id'],
        'content': [
          {'type': 'unorderedList', 'items': apiItems},
          {
            'type': 'termList',
            'items': [
              for (final code in reasons.keys)
                {
                  'term': {
                    'inlineContent': [
                      {'type': 'codeVoice', 'code': code},
                    ],
                  },
                },
            ],
          },
        ],
      });
    }
    return {
      'references': references,
      'primaryContentSections': [
        {'kind': 'possibleValues', 'values': values},
      ],
      'variantOverrides': [
        {
          'patch': [
            {
              'op': 'replace',
              'path': '/identifier/interfaceLanguage',
              'value': 'occ',
            },
            ...titlePatches,
          ],
        },
      ],
    };
  }

  ({int exitCode, String output}) run(Map<String, dynamic> payload) {
    final directory = Directory.systemTemp.createTempSync('apple_docc_test');
    addTearDown(() => directory.deleteSync(recursive: true));
    final input = File('${directory.path}/payload.json')
      ..writeAsStringSync(jsonEncode(payload));
    final result = Process.runSync('python3', [probe, '--input', input.path]);
    return (
      exitCode: result.exitCode,
      output: '${result.stdout}${result.stderr}',
    );
  }

  group('Apple required-reason catalogue probe', () {
    test('accepts a matching Swift and Objective-C catalogue', () {
      final result = run(payloadForCatalogue());

      expect(result.exitCode, equals(0), reason: result.output);
      expect(result.output, contains('matches the pinned data'));
    });

    test('reports a semantic reason-code delta', () {
      final payload = payloadForCatalogue();
      final sections = payload['primaryContentSections']! as List<dynamic>;
      final section = sections.single! as Map<String, dynamic>;
      final values = section['values']! as List<dynamic>;
      final category = values.first! as Map<String, dynamic>;
      final content = category['content']! as List<dynamic>;
      final termList = content.last! as Map<String, dynamic>;
      final items = termList['items']! as List<dynamic>;
      items.add({
        'term': {
          'inlineContent': [
            {'type': 'codeVoice', 'code': 'NEW1.1'},
          ],
        },
      });

      final result = run(payload);

      expect(result.exitCode, equals(1), reason: result.output);
      expect(result.output, contains('CATALOGUE DRIFT'));
      expect(
        result.output,
        contains('+ NSPrivacyAccessedAPICategoryFileTimestamp reason NEW1.1'),
      );
    });

    test('classifies a missing Objective-C variant as operational', () {
      final payload = payloadForCatalogue()..['variantOverrides'] = <dynamic>[];

      final result = run(payload);

      expect(result.exitCode, equals(2), reason: result.output);
      expect(result.output, contains('OPERATIONAL ERROR'));
    });

    test('documentation tables match the catalogue', () {
      final result = Process.runSync('python3', [
        'scripts/lib/render_required_reason_catalogue.py',
        '--check',
      ]);

      expect(
        result.exitCode,
        equals(0),
        reason: '${result.stdout}${result.stderr}',
      );
    });
  });
}
