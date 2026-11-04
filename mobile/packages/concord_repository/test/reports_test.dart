import 'dart:convert';

import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:test/test.dart';

void main() {
  test(
    'room report signs the exact HTTP body and configured endpoint with fresh authentication',
    () async {
      final templates = <Map<String, dynamic>>[];
      final requests = <String>[];
      final url = Uri.parse('https://reports.example/v1/reports');
      final reports = ConcordReports(
        url: url,
        now: () => 1793760000,
        signer: (template) async {
          templates.add(template);
          return {
            ...template,
            'pubkey': '44' * 32,
            'id': '55' * 32,
            'sig': '66' * 64,
          };
        },
        post: (actual, body, headers) async {
          expect(actual, url);
          requests.add(body);
          final signed =
              jsonDecode(
                    utf8.decode(
                      base64Decode(headers['authorization']!.substring(6)),
                    ),
                  )
                  as Map;
          expect(signed['kind'], 27235);
          expect(signed['content'], '');
          expect(signed['tags'], contains(equals(['u', url.toString()])));
          expect(signed['tags'], contains(equals(['method', 'POST'])));
          expect(
            signed['tags'],
            contains(equals(['payload', sha256Hex(body)])),
          );
          return {'caseId': 'synthetic-case'};
        },
      );
      for (var i = 0; i < 2; i++) {
        expect(
          await reports.submit(
            communityId: '11' * 32,
            channelId: '22' * 32,
            rumorId: '33' * 32,
            reason: 'Spam',
          ),
          'synthetic-case',
        );
      }
      expect(requests.first, requests.last);
      expect(templates.first['tags'], isNot(templates.last['tags']));
      expect(jsonDecode(requests.first), {
        'target': {
          'communityId': '11' * 32,
          'channelId': '22' * 32,
          'rumorId': '33' * 32,
        },
        'reason': 'Spam',
      });
    },
  );
  test('unsafe endpoint and missing service acknowledgement fail', () async {
    Future<Map<String, dynamic>> sign(Map<String, dynamic> t) async => t;
    Future<Map<String, dynamic>> post(
      Uri u,
      String b,
      Map<String, String> h,
    ) async => {};
    expect(
      () => ConcordReports(
        url: Uri.parse('http://reports.example/v1/reports'),
        signer: sign,
        post: post,
      ),
      throwsArgumentError,
    );
    final reports = ConcordReports(
      url: Uri.parse('https://reports.example/v1/reports'),
      signer: sign,
      post: post,
    );
    await expectLater(
      reports.submit(
        communityId: '11' * 32,
        channelId: '22' * 32,
        rumorId: '33' * 32,
        reason: 'Spam',
      ),
      throwsFormatException,
    );
  });
}
