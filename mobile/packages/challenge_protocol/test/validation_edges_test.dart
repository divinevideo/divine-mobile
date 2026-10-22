import 'dart:convert';

import 'package:bech32/bech32.dart';
import 'package:challenge_protocol/challenge_protocol.dart';
import 'package:challenge_protocol/src/time_zones.dart';
import 'package:test/test.dart';

import 'synthetic.dart';

void main() {
  late SyntheticSigner organizer;
  late SyntheticSigner creator;
  late ChallengeDefinition definition;
  late NostrEvent video;
  setUpAll(() {
    organizer = SyntheticSigner();
    creator = SyntheticSigner();
    definition = definitionOf(organizer.definition());
    video = NostrEvent.fromJson(creator.sign(kind: 21));
  });

  group('parseChallengeEvent', () {
    test('every audited Intl zone and lowercase alias is accepted', () {
      expect(recognizedTimeZones, hasLength(637));
      for (final zone in recognizedTimeZones) {
        expect(
          parseChallengeEvent(
            organizer.definition(
              timezone: zone,
              endTimezone: zone.toUpperCase(),
            ),
          ).ok,
          isTrue,
          reason: zone,
        );
      }
    });

    for (final zone in ['ACT', 'PST', 'SystemV/PST8PDT', 'UTC']) {
      test('legacy timezone $zone remains signed verbatim', () {
        final parsed = definitionOf(organizer.definition(timezone: zone));
        expect(parsed.timeZone, zone);
        expect(parsed.endTimeZone, zone);
      });
    }

    for (final zone in [
      '',
      'Factory',
      '+01:00',
      'Not/A_Zone',
      'SystemV/PST9PDT',
      ' UTC',
    ]) {
      test('rejects timezone $zone', () {
        expect(
          parseChallengeEvent(organizer.definition(timezone: zone)).code,
          'timezone',
        );
      });
    }

    test('grapheme title and prompt UTF-8 budgets are independent', () {
      const cluster = '👩🏽‍💻';
      expect(
        parseChallengeEvent(
          organizer.definition(title: cluster * 120, content: 'é' * 4096),
        ).ok,
        isTrue,
      );
      expect(
        parseChallengeEvent(organizer.definition(title: cluster * 121)).code,
        'length',
      );
      expect(
        parseChallengeEvent(organizer.definition(content: '${'é' * 4096}a'))
            .code,
        'size',
      );
      expect(
        parseChallengeEvent(organizer.definition(title: ' \n\t')).code,
        'length',
      );
    });

    test('fresh verification ignores unsigned metadata and cached flags', () {
      final wire = organizer.definition();
      wire['verified'] = true;
      wire['unsigned'] = List<Object?>.filled(100000, null);
      expect(parseChallengeEvent(wire).ok, isTrue);
      wire['content'] = 'tampered';
      expect(parseChallengeEvent(wire).code, 'signature');
    });

    test('original signed JSON types and unsafe integers are rejected', () {
      for (final change in <String, Object?>{
        'created_at': 9007199254740992,
        'kind': 21.5,
        'content': {r'$serde_json::private::RawValue': '"text"'},
        'tags': [
          ['d', 1],
        ],
        'id': {r'$serde_json::private::RawValue': '"${video.id}"'},
      }.entries) {
        expect(
          parseChallengeEvent({
            ...organizer.definition(),
            change.key: change.value,
          }).code,
          'shape',
          reason: change.key,
        );
      }
      final wire = organizer.definition();
      wire['created_at'] = 100.0;
      wire['kind'] = 31923.0;
      expect(parseChallengeEvent(wire).ok, isTrue);
    });

    for (final depth in [150, 16000]) {
      test('deep $depth-array unsigned metadata is ignored', () {
        final template = buildEntry(definition, video, 150);
        final tags = template.tags.map((t) => t.toList()).toList();
        final videoJson = jsonEncode(video.toJson());
        final snapshot =
            '${videoJson.substring(0, videoJson.length - 1)},'
            '"metadata":${'[' * depth}null${']' * depth}}';
        tags.singleWhere((t) => t[0] == 'video_snapshot')[1] = snapshot;
        final signed = creator.sign(
          kind: 1111,
          createdAt: 150,
          content: template.content,
          tags: tags,
        );
        expect(utf8.encode(jsonEncode(signed)).length, lessThan(65536));
        expect(parseChallengeEvent(signed).ok, isTrue);
      });
    }

    test(
      'deep object metadata and duplicate fields preserve last-key-wins',
      () {
        final template = buildEntry(definition, video, 150);
        final tags = template.tags.map((t) => t.toList()).toList();
        final signedJson = jsonEncode(video.toJson());
        final snapshot =
            '{"content":{"discard":true},'
            '${signedJson.substring(1, signedJson.length - 1)},'
            '"metadata":${'{"x":' * 2000}null${'}' * 2000}}';
        tags.singleWhere((t) => t[0] == 'video_snapshot')[1] = snapshot;
        expect(
          parseChallengeEvent(
            creator.sign(
              kind: 1111,
              createdAt: 150,
              content: template.content,
              tags: tags,
            ),
          ).ok,
          isTrue,
        );
        final rawObject = jsonEncode({r'$serde_json::private::RawValue': '""'});
        tags.singleWhere((t) => t[0] == 'video_snapshot')[1] =
            '${signedJson.substring(0, signedJson.length - 1)},'
            '"content":$rawObject}';
        expect(
          parseChallengeEvent(
            creator.sign(
              kind: 1111,
              createdAt: 150,
              content: template.content,
              tags: tags,
            ),
          ).code,
          'shape',
        );
      },
    );

    test(
      'nevent accepts empty optional TLV and replacement UTF-8 relay hints',
      () {
        final template = buildEntry(definition, video, 150);
        final bytes = [
          0,
          32,
          for (var i = 0; i < 64; i += 2)
            int.parse(video.id.substring(i, i + 2), radix: 16),
          1,
          0,
          1,
          1,
          255,
        ];
        var acc = 0;
        var bits = 0;
        final words = <int>[];
        for (final byte in bytes) {
          acc = ((acc << 8) | byte) & 4095;
          bits += 8;
          while (bits >= 5) {
            bits -= 5;
            words.add((acc >> bits) & 31);
          }
        }
        if (bits > 0) words.add((acc << (5 - bits)) & 31);
        final citation = bech32.encode(Bech32('nevent', words), 5000);
        expect(
          parseChallengeEvent(
            creator.sign(
              kind: 1111,
              createdAt: 150,
              content: 'nostr:$citation',
              tags: template.tags,
            ),
          ).ok,
          isTrue,
        );
      },
    );

    test(
      'superseded numeric overflow preserves last-key-wins in snapshots',
      () {
        final template = buildEntry(definition, video, 150);
        final tags = template.tags.map((t) => t.toList()).toList();
        final json = jsonEncode(video.toJson());
        for (final field in ['kind', 'created_at', 'content', 'tags', 'id']) {
          final snapshot = '{"$field":1e400,${json.substring(1)}';
          tags.singleWhere((t) => t[0] == 'video_snapshot')[1] = snapshot;
          expect(
            parseChallengeEvent(
              creator.sign(
                kind: 1111,
                createdAt: 150,
                content: template.content,
                tags: tags,
              ),
            ).ok,
            isTrue,
            reason: field,
          );
        }
        tags.singleWhere((t) => t[0] == 'video_snapshot')[1] =
            '{"kind":1e+,${json.substring(1)}';
        expect(
          parseChallengeEvent(
            creator.sign(
              kind: 1111,
              createdAt: 150,
              content: template.content,
              tags: tags,
            ),
          ).code,
          'snapshot',
        );
        tags.singleWhere((t) => t[0] == 'video_snapshot')[1] =
            '${json.substring(0, json.length - 1)},"created_at":1e400}';
        expect(
          parseChallengeEvent(
            creator.sign(
              kind: 1111,
              createdAt: 150,
              content: template.content,
              tags: tags,
            ),
          ).code,
          'shape',
        );
      },
    );

    test('title blankness matches ECMAScript whitespace', () {
      expect(
        parseChallengeEvent(organizer.definition(title: '\u0085')).ok,
        isTrue,
      );
      expect(
        parseChallengeEvent(organizer.definition(title: '\uFEFF')).code,
        'length',
      );
    });
  });

  group('NostrEvent.fromJson', () {
    test('record compact UTF-8 budget includes all signed fields', () {
      final base = creator.sign(kind: 21);
      final baseSize = utf8.encode(jsonEncode(base)).length;
      final exact = creator.sign(kind: 21, content: 'a' * (65536 - baseSize));
      expect(NostrEvent.fromJson(exact).kind, 21);
      final excess = creator.sign(kind: 21, content: 'a' * (65537 - baseSize));
      expect(
        () => NostrEvent.fromJson(excess),
        throwsA(isA<ContractError>().having((e) => e.code, 'code', 'size')),
      );
    });
  });
}
