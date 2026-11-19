// ABOUTME: Exercises real Blossom server fallback through the video DM pipeline.
// ABOUTME: Each PUT gets progress liveness without extending the overall deadline.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:dio/dio.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/services/dm_video_encryption.dart';
import 'package:openvine/services/dm_video_send_cancellation.dart';
import 'package:openvine/services/dm_video_send_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Encryption extends Mock implements DmVideoEncryption {}

class _File extends Mock implements File {}

class _Auth implements BlossomAuthProvider {
  @override
  bool get isAuthenticated => true;

  @override
  Future<BlossomSignedEvent?> createAndSignEvent({
    required int kind,
    required String content,
    required List<List<String>> tags,
  }) async => BlossomSignedEvent(
    json: {
      'id': '2' * 64,
      'pubkey': '1' * 64,
      'created_at': 0,
      'kind': kind,
      'tags': tags,
      'content': content,
      'sig': '3' * 128,
    },
  );
}

class _Repository extends Fake implements DmRepository {
  final publishedUrls = <String>[];

  @override
  Future<bool> waitForConnectedRelay({
    Duration timeout = dmFileSendRelayWait,
  }) async => true;

  @override
  Future<NIP17SendResult> sendFileMessage({
    required String recipientPubkey,
    required String fileUrl,
    required DmFileMetadata fileMetadata,
    String? replyToId,
    List<List<String>> extraTags = const [],
  }) async {
    publishedUrls.add(fileUrl);
    return NIP17SendResult.success(
      rumorEventId: '4' * 64,
      messageEventId: '5' * 64,
      recipientPubkey: recipientPubkey,
    );
  }
}

class _Transfer {
  _Transfer(this.options);

  final RequestOptions options;
  final response = Completer<ResponseBody>();
  bool cancelled = false;

  void progress(int sent) => options.onSendProgress!(sent, 100);

  void complete(int statusCode, String hash) => response.complete(
    ResponseBody.fromString(
      jsonEncode({'sha256': hash, 'url': 'https://default.example/$hash'}),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    ),
  );
}

class _Transport implements HttpClientAdapter {
  final transfers = <_Transfer>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) {
    final transfer = _Transfer(options);
    transfers.add(transfer);
    unawaited(cancelFuture?.then((_) => transfer.cancelled = true));
    return transfer.response.future;
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DmVideoSendService server fallback', () {
    for (final increasing in [true, false]) {
      test(
        increasing
            ? 'healthy fallback can progress below the previous PUT high-water mark'
            : 'repeated progress on one fallback PUT still expires',
        () async {
          SharedPreferences.setMockInitialValues({
            'blossom_server_url': 'https://custom.example',
            'use_blossom_upload': true,
          });
          await SharedPreferences.getInstance();
          fakeAsync((clock) {
            final payload = Uint8List.fromList(List.filled(100, 7));
            final hash = HashUtil.sha256Hash(payload);
            final ciphertext = _File();
            when(ciphertext.openRead).thenAnswer((_) => Stream.value(payload));
            when(ciphertext.delete).thenAnswer((_) async => ciphertext);
            final video = File('/virtual/video.mp4');
            final encryption = _Encryption();
            when(() => encryption.encryptFile(video)).thenAnswer(
              (_) async => EncryptedVideoFile(
                ciphertextFile: ciphertext,
                key: '6' * 64,
                nonce: '7' * 24,
                ciphertextHash: hash,
                plaintextHash: '8' * 64,
                ciphertextSize: 100,
              ),
            );
            final transport = _Transport();
            final dio = Dio()..httpClientAdapter = transport;
            final repository = _Repository();
            final attempt = DmVideoSendCancellation(
              now: () => DateTime.utc(2026).add(clock.elapsed),
            );
            NIP17SendResult? delivered;
            Object? failure;
            final service = DmVideoSendService(
              dmRepository: repository,
              blossom: BlossomUploadService(
                authProvider: _Auth(),
                dio: dio,
                defaultServerUrl: 'https://default.example',
              ),
              encryption: encryption,
              readPreview: (_) async => (blurhash: null, dimensions: null),
            );
            unawaited(
              service
                  .uploadVideo(
                    videoFile: video,
                    mimeType: 'video/mp4',
                    cancellation: attempt,
                  )
                  .then(
                    (uploaded) => service.publishVideo(
                      recipientPubkey: '9' * 64,
                      uploaded: uploaded,
                      cancellation: attempt,
                    ),
                  )
                  .then<void>(
                    (result) {
                      delivered = result;
                    },
                    onError: (Object error) {
                      failure = error;
                    },
                  ),
            );
            clock.elapse(Duration.zero);
            expect(failure, isNull);
            expect(
              transport.transfers.single.options.uri.host,
              'custom.example',
            );
            transport.transfers.single.progress(100);
            transport.transfers.single.complete(500, hash);
            clock.elapse(Duration.zero);
            expect(transport.transfers, hasLength(2));
            final fallback = transport.transfers.last;
            expect(fallback.options.uri.host, 'default.example');
            fallback.progress(10);
            for (var minute = 1; minute <= 3; minute++) {
              clock.elapse(const Duration(minutes: 1));
              fallback.progress(increasing ? 10 + minute * 10 : 10);
              clock.elapse(Duration.zero);
            }
            try {
              expect(attempt.uploadCancelToken.isCancelled, !increasing);
              expect(fallback.cancelled, !increasing);
              if (increasing) {
                expect(failure, isNull);
                fallback.complete(201, hash);
                clock.elapse(Duration.zero);
                expect(delivered?.success, isTrue);
                expect(repository.publishedUrls, hasLength(1));
              } else {
                expect(failure, isA<DmVideoSendCancelled>());
                expect(repository.publishedUrls, isEmpty);
              }
            } finally {
              attempt.finish();
              if (!fallback.response.isCompleted) fallback.complete(201, hash);
              clock.elapse(Duration.zero);
              dio.close(force: true);
            }
          });
        },
      );
    }
  });
}
