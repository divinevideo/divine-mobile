import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/services/api_service.dart';

void main() {
  group('startGreenlight', () {
    test(
      'starts an owned Greenlight case on the configured review service',
      () async {
        late http.Request request;
        final api = ApiService(
          relayManagerBaseUrl: 'https://review.example.com',
          appVersion: '1.0.0',
          client: MockClient((value) async {
            request = value;
            return http.Response(
              jsonEncode({
                'restriction': {'status': 'active'},
                'minorReviewCase': {'id': 'application-1'},
              }),
              201,
            );
          }),
        );
        final result = await api.startGreenlight();
        expect(
          request.url.toString(),
          'https://review.example.com/v1/minor-review-cases/greenlight',
        );
        expect(request.method, 'POST');
        expect(jsonDecode(request.body), <String, dynamic>{});
        expect((result['minorReviewCase'] as Map)['id'], 'application-1');
      },
    );
    test(
      'keeps a failed start visible instead of uploading without a case',
      () async {
        final api = ApiService(
          relayManagerBaseUrl: 'https://review.example.com',
          appVersion: '1.0.0',
          client: MockClient((_) async => http.Response('{}', 503)),
        );
        await expectLater(api.startGreenlight(), throwsA(isA<ApiException>()));
      },
    );
  });
}
