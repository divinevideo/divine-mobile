// ABOUTME: Explicit local cross-language consent contract acceptance runner.
// ABOUTME: Run against local_stack/consent_acceptance/server.mjs, never a live service.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/services/api_service.dart';
import 'package:openvine/services/consent_upload.dart';
import 'package:openvine/services/consent_upload_session.dart';
import 'package:openvine/services/nip98_auth_service.dart';

import 'consent_acceptance_support.dart';

void main() {
  const endpoint = String.fromEnvironment(
    'CONSENT_ACCEPTANCE_URL',
    defaultValue: 'http://127.0.0.1:48787',
  );
  final base = Uri.parse(endpoint);
  if (!base.isScheme('http') ||
      !['localhost', '127.0.0.1'].contains(base.host)) {
    throw StateError(
      'Consent acceptance only permits an isolated loopback service',
    );
  }

  test(
    'real signed Dart upload, private playback and reviewer transition',
    () async {
      final client = http.Client();
      addTearDown(client.close);
      final auth = Nip98AuthService(
        authService: SyntheticConsentSigner(
          '0000000000000000000000000000000000000000000000000000000000000001',
        ),
      );
      addTearDown(auth.dispose);
      final api = ApiService(
        relayManagerBaseUrl: endpoint,
        appVersion: 'local-acceptance',
        authService: auth,
      );
      addTearDown(api.dispose);
      final directory = Directory.systemTemp.createTempSync(
        'consent-contract-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final clip = File('${directory.path}/synthetic.mp4');
      final bytes = List<int>.generate(65537, (i) => i % 256);
      clip.writeAsBytesSync(bytes);

      final started = await api.startGreenlight();
      final caseId = MinorAccountReviewStatus.fromJson(started).currentCase!.id;
      Future<http.Response> moderate(Map<String, dynamic> body) => client.patch(
        base.resolve('/api/age-review/cases/$caseId'),
        headers: {
          'X-Admin-Key': 'local-consent-admin',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      for (final state in [
        'under_moderator_review',
        'restricted_pending_user_response',
        'restricted_pending_parental_consent',
      ]) {
        final response = await moderate({'state': state});
        expect(response.statusCode, 200, reason: response.body);
      }
      expect(
        MinorAccountReviewStatus.fromJson(
          await api.getMinorAccountReviewStatus(),
        ).restrictionStatus,
        AccountRestrictionStatus.restrictedMinorReview,
      );
      final otherAuth = Nip98AuthService(
        authService: SyntheticConsentSigner(
          '0000000000000000000000000000000000000000000000000000000000000004',
        ),
      );
      addTearDown(otherAuth.dispose);
      final otherApi = ApiService(
        relayManagerBaseUrl: endpoint,
        appVersion: 'local-acceptance',
        authService: otherAuth,
      );
      addTearDown(otherApi.dispose);
      await expectLater(
        otherApi.submitMinorAccountReviewParentConsent(
          caseId: caseId,
          email: 'parent@example.test',
          videoPath: clip.path,
        ),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
      final uploadUrl = base.resolve(
        '/v1/minor-review-cases/$caseId/parent-consent',
      );
      final mismatched = await ConsentUpload.prepare(
        http.MultipartRequest('POST', uploadUrl)
          ..fields['email'] = 'parent@example.test'
          ..files.add(
            await http.MultipartFile.fromPath(
              'video',
              clip.path,
              contentType: MediaType('video', 'mp4'),
            ),
          ),
      );
      addTearDown(mismatched.dispose);
      final mismatchToken = await auth.createAuthToken(
        url: uploadUrl.toString(),
        method: HttpMethod.post,
        payloadHash:
            '0000000000000000000000000000000000000000000000000000000000000000',
        reuseCached: false,
      );
      final mismatchedRequest = mismatched.request;
      mismatchedRequest.headers['Authorization'] =
          mismatchToken!.authorizationHeader;
      final rejected = await client.send(mismatchedRequest);
      expect(rejected.statusCode, 401);
      await rejected.stream.drain<void>();
      final session = ConsentUploadSession();
      addTearDown(session.dispose);
      Future<void> submit() => api.submitMinorAccountReviewParentConsent(
        caseId: caseId,
        email: 'parent@example.test',
        videoPath: clip.path,
        session: session,
      );
      await submit();
      await submit();
      Future<Map<String, dynamic>> state() async => jsonDecode(
        (await client.get(base.resolve('/__test/state'))).body,
      ) as Map<String, dynamic>;
      final after = await state();
      final submissions = after['submissions']! as List<dynamic>;
      expect(submissions, hasLength(1));
      final reviewLinks = (after['comments']! as List<dynamic>).where(
        (dynamic comment) => (comment['body'] as String).contains(
          '/api/age-review/consent-video/',
        ),
      );
      expect(reviewLinks, hasLength(1));
      expect(reviewLinks.single['public'], isFalse);
      expect(submissions.single['status'], 'commented');
      expect(submissions.single['size_bytes'], bytes.length);
      final playback = base.resolve(
        '/api/age-review/consent-video/${submissions.single['receipt_id']}',
      );
      expect((await client.get(playback)).statusCode, 401);
      expect(
        (await client.get(
          playback,
          headers: {'X-Admin-Key': 'local-consent-admin'},
        )).statusCode,
        401,
      );
      for (final mode in ['expired', 'audience']) {
        final token =
            jsonDecode(
                  (await client.get(base.resolve('/__test/token?mode=$mode')))
                      .body,
                )['token']
                as String;
        expect(
          (await client.get(
            playback,
            headers: {'Cf-Access-Jwt-Assertion': token},
          )).statusCode,
          401,
        );
      }
      final token =
          jsonDecode(
                (await client.get(base.resolve('/__test/token'))).body,
              )['token']
              as String;
      final headers = {'Cf-Access-Jwt-Assertion': token};
      final pieces = token.split('.');
      pieces[2] = '${pieces[2][0] == 'A' ? 'B' : 'A'}${pieces[2].substring(1)}';
      expect(
        (await client.get(
          playback,
          headers: {'Cf-Access-Jwt-Assertion': pieces.join('.')},
        )).statusCode,
        401,
      );
      final video = await client.get(playback, headers: headers);
      expect(video.statusCode, 200);
      expect(video.bodyBytes, bytes);
      final range = await client.get(
        playback,
        headers: {...headers, 'Range': 'bytes=1-32'},
      );
      expect(range.statusCode, 206);
      expect(range.bodyBytes, bytes.sublist(1, 33));
      final currentCase = (after['cases']! as List<dynamic>).single;
      expect(currentCase['state'], 'submitted_for_review');
      final approval = await client.patch(
        base.resolve('/api/age-review/cases/$caseId'),
        headers: {
          'X-Admin-Key': 'local-consent-admin',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'state': 'cleared',
          'resolution': 'approved_minor',
          'expected_version': currentCase['version'],
        }),
      );
      expect(approval.statusCode, 200, reason: approval.body);
      final finalStatus = await api.getMinorAccountReviewStatus();
      expect(
        (finalStatus['restriction'] as Map<String, dynamic>)['status'],
        'active',
      );
      final finalState = await state();
      expect((finalState['cases'] as List<dynamic>).single['state'], 'cleared');
      expect(
        finalState['outbound'],
        contains(
          allOf(startsWith('PUT keycast.test/'), endsWith('/verified-minor')),
        ),
      );
      expect(finalState['outbound'], contains('POST relay.test/management'));
      expect(finalState['unexpected'], isEmpty);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
