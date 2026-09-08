// ABOUTME: Tests for ModerationLabelService
// ABOUTME: Validates Kind 1985 label parsing including AI confidence metadata

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/nip05/nip05_validor.dart';
import 'package:openvine/constants/nostr_event_kinds.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

import '../helpers/test_pubkeys.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _FakeFilter extends Fake implements Filter {}

/// Serves a canned `nostr.json` so the NIP-05 leg resolves without a network.
class _FakeNip05Adapter implements HttpClientAdapter {
  _FakeNip05Adapter(this._body);

  final String _body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    _body,
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

/// Fake event for testing label processing.
///
/// [createdAt] defaults to zero because single-page tests do not page. Tests
/// that compare event identity pass explicit ids.
class _FakeLabelEvent extends Fake implements Event {
  _FakeLabelEvent({
    required this.pubkey,
    required this.tags,
    this.id =
        '9999999999999999999999999999999999999999999999999999999999999999',
    this.createdAt = 0,
  });

  @override
  final String id;

  @override
  final int createdAt;

  @override
  final String pubkey;

  @override
  final List<List<String>> tags;
}

void main() {
  late _MockNostrClient mockNostrClient;
  late _MockAuthService mockAuthService;
  late SharedPreferences mockPrefs;
  late ModerationLabelService service;

  setUpAll(() {
    registerFallbackValue(<Filter>[_FakeFilter()]);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockPrefs = await SharedPreferences.getInstance();
    mockNostrClient = _MockNostrClient();
    mockAuthService = _MockAuthService();
    when(() => mockNostrClient.connectedRelayCount).thenReturn(0);
    when(
      () => mockNostrClient.relayStatusStream,
    ).thenAnswer(
      (_) => const Stream<Map<String, RelayConnectionStatus>>.empty(),
    );
    // Default: the live tail (#8255) opens after a labeler latches loaded.
    // A never-closing broadcast stream so the tail stays open (no onDone) and
    // no reconnect timer is scheduled. Tests that exercise the tail override
    // this with their own controllable stream.
    final defaultTail = StreamController<Event>.broadcast();
    when(
      () => mockNostrClient.subscribe(
        any(),
        subscriptionId: any(named: 'subscriptionId'),
        onEose: any(named: 'onEose'),
      ),
    ).thenAnswer((_) => defaultTail.stream);
    service = ModerationLabelService(
      nostrClient: mockNostrClient,
      authService: mockAuthService,
      sharedPreferences: mockPrefs,
    );
  });

  group('pinned-key mismatch logging (#4948 tier 1)', () {
    const pin = ModerationLabelService.fallbackModerationPubkeyHex;
    const divergentKey = syntheticTestPubkey;
    const resolvedPubkeyPrefsKey = 'divine_moderation_resolved_pubkey';

    late LogCaptureService logCapture;
    late HttpClientAdapter originalAdapter;

    setUp(() async {
      logCapture = LogCaptureService();
      await logCapture.clearAllLogs();
      originalAdapter = Nip05Validor.dio.httpClientAdapter;
    });

    tearDown(() async {
      // Restore the shared static adapter: an unrestored swap would strand
      // every later suite in the merged isolate on this fake.
      Nip05Validor.dio.httpClientAdapter = originalAdapter;
      await logCapture.clearAllLogs();
    });

    ModerationLabelService buildService({bool canQueryRelays = false}) =>
        ModerationLabelService(
          nostrClient: mockNostrClient,
          authService: mockAuthService,
          sharedPreferences: mockPrefs,
          canQueryRelays: () => canQueryRelays,
        );

    List<String> pinWarnings() => logCapture
        .getRecentLogs(minLevel: LogLevel.warning)
        .map((entry) => entry.message)
        .where((message) => message.contains('diverges from the key pinned'))
        .toList();

    test('stays silent when the adopted key is the pinned key', () async {
      final service = buildService();

      await service.ensureLoaded();

      expect(service.divineModerationPubkeyHex, pin);
      expect(pinWarnings(), isEmpty);
    });

    test('warns when a persisted key diverges from the pin', () async {
      await mockPrefs.setString(resolvedPubkeyPrefsKey, divergentKey);
      final service = buildService();

      await service.ensureLoaded();

      expect(
        service.divineModerationPubkeyHex,
        divergentKey,
        reason:
            'tier 1 keeps NIP-05 authoritative; the warning is advisory '
            'and must not change which key is trusted',
      );
      expect(pinWarnings(), hasLength(1));
    });

    test('names both keys in full so the warning is actionable', () async {
      await mockPrefs.setString(resolvedPubkeyPrefsKey, divergentKey);

      await buildService().ensureLoaded();

      expect(pinWarnings().single, contains(divergentKey));
      expect(pinWarnings().single, contains(pin));
    });

    test('does not warn when a persisted key differs only by case', () async {
      await mockPrefs.setString(resolvedPubkeyPrefsKey, pin.toUpperCase());

      await buildService().ensureLoaded();

      expect(
        pinWarnings(),
        isEmpty,
        reason:
            'NIP-05 mandates lowercase hex, but an uppercase answer is '
            'the same identity — warning on it would cry wolf',
      );
    });

    test('canonicalizes a persisted key that differs only by case', () async {
      await mockPrefs.setString(resolvedPubkeyPrefsKey, pin.toUpperCase());

      final service = buildService();
      await service.ensureLoaded();

      expect(
        service.divineModerationPubkeyHex,
        pin,
        reason:
            'the adopted identity feeds the subscription filter, and event '
            'authors are lowercase on the wire — storing the uppercase form '
            'would silently match no events',
      );
    });

    test('warns when NIP-05 resolves to a key that is not the pin', () async {
      Nip05Validor.dio.httpClientAdapter = _FakeNip05Adapter(
        '{"names":{"moderation":"$divergentKey"}}',
      );
      when(
        () => mockNostrClient.queryEventsDetailed(
          any(),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      ).thenAnswer(
        (_) async => (events: <Event>[], timedOut: false, noRelays: false),
      );
      final service = buildService(canQueryRelays: true);

      await service.initialize();

      expect(service.divineModerationPubkeyHex, divergentKey);
      expect(pinWarnings(), hasLength(1));
      expect(pinWarnings().single, contains(divergentKey));
    });
  });

  group(ModerationLabelService, () {
    test(
      'addLabeler preserves saved labelers before relay session is ready',
      () async {
        const existingLabeler =
            '1111111111111111111111111111111111111111111111111111111111111111';
        const newLabeler =
            '2222222222222222222222222222222222222222222222222222222222222222';

        SharedPreferences.setMockInitialValues({
          'subscribed_labeler_pubkeys': [existingLabeler],
          'divine_moderation_resolved_pubkey':
              ModerationLabelService.fallbackModerationPubkeyHex,
          'divine_moderation_resolved_at': DateTime.now().toIso8601String(),
        });
        final prefs = await SharedPreferences.getInstance();
        final gatedService = ModerationLabelService(
          nostrClient: mockNostrClient,
          authService: mockAuthService,
          sharedPreferences: prefs,
          canQueryRelays: () => false,
        );

        await gatedService.addLabeler(newLabeler);

        final saved = prefs.getStringList('subscribed_labeler_pubkeys');
        expect(
          saved,
          containsAll([
            existingLabeler,
            newLabeler,
            ModerationLabelService.fallbackModerationPubkeyHex,
          ]),
        );
        verifyNever(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        );
      },
    );

    test('ensureLoaded hydrates prefs without querying relays', () async {
      const existingLabeler =
          '1111111111111111111111111111111111111111111111111111111111111111';

      SharedPreferences.setMockInitialValues({
        'subscribed_labeler_pubkeys': [existingLabeler],
        'following_moderation_enabled': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final localOnlyService = ModerationLabelService(
        nostrClient: mockNostrClient,
        authService: mockAuthService,
        sharedPreferences: prefs,
        canQueryRelays: () => false,
      );

      await localOnlyService.ensureLoaded();

      expect(localOnlyService.isFollowingModerationEnabled, isTrue);
      expect(localOnlyService.customLabelers, contains(existingLabeler));
      verifyNever(
        () => mockNostrClient.queryEventsDetailed(
          any(),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      );
    });

    group('_processLabelEvent', () {
      test('parses basic content-warning label', () async {
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer(
          (_) async => (
            events: <Event>[
              _FakeLabelEvent(
                pubkey: service.divineModerationPubkeyHex,
                tags: [
                  ['L', 'content-warning'],
                  ['l', 'nudity', 'content-warning'],
                  ['e', 'target_event_id_abc'],
                ],
              ),
            ],
            timedOut: false,
            noRelays: false,
          ),
        );

        await service.subscribeToLabeler(service.divineModerationPubkeyHex);

        final warnings = service.getContentWarnings('target_event_id_abc');
        expect(warnings, hasLength(1));
        expect(warnings.first.labelValue, equals('nudity'));
        expect(
          warnings.first.labelerPubkey,
          equals(service.divineModerationPubkeyHex),
        );
      });

      test('parses ai-generated label with confidence metadata', () async {
        const metadata =
            '{"confidence": 0.95, "source": "hiveai", "verified": true}';
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer(
          (_) async => (
            events: <Event>[
              _FakeLabelEvent(
                pubkey: service.divineModerationPubkeyHex,
                tags: [
                  ['L', 'content-warning'],
                  ['l', 'ai-generated', 'content-warning', metadata],
                  ['e', 'event_123'],
                ],
              ),
            ],
            timedOut: false,
            noRelays: false,
          ),
        );

        await service.subscribeToLabeler(service.divineModerationPubkeyHex);

        final warnings = service.getContentWarnings('event_123');
        expect(warnings, hasLength(1));
        expect(warnings.first.labelValue, equals('ai-generated'));
        expect(warnings.first.confidence, equals(0.95));
        expect(warnings.first.source, equals('hiveai'));
        expect(warnings.first.isVerified, isTrue);
      });

      test('handles malformed metadata JSON gracefully', () async {
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer(
          (_) async => (
            events: <Event>[
              _FakeLabelEvent(
                pubkey: service.divineModerationPubkeyHex,
                tags: [
                  ['L', 'content-warning'],
                  ['l', 'ai-generated', 'content-warning', 'not-valid-json'],
                  ['e', 'event_456'],
                ],
              ),
            ],
            timedOut: false,
            noRelays: false,
          ),
        );

        await service.subscribeToLabeler(service.divineModerationPubkeyHex);

        final warnings = service.getContentWarnings('event_456');
        expect(warnings, hasLength(1));
        expect(warnings.first.labelValue, equals('ai-generated'));
        expect(warnings.first.confidence, isNull);
        expect(warnings.first.source, isNull);
        expect(warnings.first.isVerified, isFalse);
      });

      test('indexes labels by content hash from x tag', () async {
        const metadata = '{"confidence": 0.12, "source": "hiveai"}';
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer(
          (_) async => (
            events: <Event>[
              _FakeLabelEvent(
                pubkey: service.divineModerationPubkeyHex,
                tags: [
                  ['L', 'content-warning'],
                  ['l', 'ai-generated', 'content-warning', metadata],
                  ['e', 'event_789'],
                  ['x', 'sha256_hash_of_content'],
                ],
              ),
            ],
            timedOut: false,
            noRelays: false,
          ),
        );

        await service.subscribeToLabeler(service.divineModerationPubkeyHex);

        final result = service.getAIDetectionByHash('sha256_hash_of_content');
        expect(result, isNotNull);
        expect(result!.score, equals(0.12));
        expect(result.source, equals('hiveai'));
        expect(result.isVerified, isFalse);
      });

      test(
        'stores content-warning labels by addressable id from a tag',
        () async {
          const addressableId =
              '30311:creator_pubkey_hex:codex-staging-video-replaceable-id';

          when(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer(
            (_) async => (
              events: <Event>[
                _FakeLabelEvent(
                  pubkey: service.divineModerationPubkeyHex,
                  tags: [
                    ['L', 'content-warning'],
                    ['l', 'nudity', 'content-warning'],
                    ['a', addressableId],
                  ],
                ),
              ],
              timedOut: false,
              noRelays: false,
            ),
          );

          await service.subscribeToLabeler(service.divineModerationPubkeyHex);

          final labels = service.getContentWarningsByAddressableId(
            addressableId,
          );
          expect(labels, hasLength(1));
          expect(labels.first.labelValue, equals('nudity'));
        },
      );

      test(
        'stores content-warning labels by content hash from x tag',
        () async {
          when(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer(
            (_) async => (
              events: <Event>[
                _FakeLabelEvent(
                  pubkey: service.divineModerationPubkeyHex,
                  tags: [
                    ['L', 'content-warning'],
                    ['l', 'graphic-media', 'content-warning'],
                    ['x', 'sha256_content_warning_hash'],
                  ],
                ),
              ],
              timedOut: false,
              noRelays: false,
            ),
          );

          await service.subscribeToLabeler(service.divineModerationPubkeyHex);

          final labels = service.getContentWarningsByHash(
            'sha256_content_warning_hash',
          );
          expect(labels, hasLength(1));
          expect(labels.first.labelValue, equals('graphic-media'));
        },
      );

      test('stores labels by pubkey when p tag present', () async {
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer(
          (_) async => (
            events: <Event>[
              _FakeLabelEvent(
                pubkey: service.divineModerationPubkeyHex,
                tags: [
                  ['L', 'content-warning'],
                  ['l', 'spam', 'content-warning'],
                  ['p', 'target_pubkey_xyz'],
                ],
              ),
            ],
            timedOut: false,
            noRelays: false,
          ),
        );

        await service.subscribeToLabeler(service.divineModerationPubkeyHex);

        final labels = service.getLabelsForPubkey('target_pubkey_xyz');
        expect(labels, hasLength(1));
        expect(labels.first.labelValue, equals('spam'));
      });

      test('keeps every content-warning label with its metadata', () async {
        const aiMetadata =
            '{"confidence": 0.91, "source": "hiveai", "verified": true}';
        const violenceMetadata =
            '{"confidence": 0.42, "source": "human-review"}';
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer(
          (_) async => (
            events: <Event>[
              _FakeLabelEvent(
                pubkey: service.divineModerationPubkeyHex,
                tags: [
                  ['L', 'content-warning'],
                  ['l', 'ai-generated', 'content-warning', aiMetadata],
                  ['l', 'violence', 'content-warning', violenceMetadata],
                  ['e', 'multi_label_event'],
                ],
              ),
            ],
            timedOut: false,
            noRelays: false,
          ),
        );

        await service.subscribeToLabeler(service.divineModerationPubkeyHex);

        final warnings = service.getContentWarnings('multi_label_event');
        expect(warnings.map((label) => label.labelValue), [
          'ai-generated',
          'violence',
        ]);
        expect(warnings[0].confidence, equals(0.91));
        expect(warnings[0].source, equals('hiveai'));
        expect(warnings[0].isVerified, isTrue);
        expect(warnings[1].confidence, equals(0.42));
        expect(warnings[1].source, equals('human-review'));
        expect(warnings[1].isVerified, isFalse);

        final aiResult = service.getAIDetectionResult('multi_label_event');
        expect(aiResult, isNotNull);
        expect(aiResult!.score, equals(0.91));
        expect(aiResult.source, equals('hiveai'));
        expect(aiResult.isVerified, isTrue);
      });

      test(
        'indexes each repeated event and pubkey target separately',
        () async {
          when(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer(
            (_) async => (
              events: <Event>[
                _FakeLabelEvent(
                  pubkey: service.divineModerationPubkeyHex,
                  tags: [
                    ['L', 'content-warning'],
                    ['l', 'nudity', 'content-warning'],
                    ['e', 'target_event_1'],
                    ['e', 'target_event_2'],
                    ['p', 'target_pubkey_1'],
                    ['p', 'target_pubkey_2'],
                  ],
                ),
              ],
              timedOut: false,
              noRelays: false,
            ),
          );

          await service.subscribeToLabeler(service.divineModerationPubkeyHex);

          for (final eventId in ['target_event_1', 'target_event_2']) {
            final labels = service.getContentWarnings(eventId);
            expect(labels, hasLength(1));
            expect(labels.single.labelValue, equals('nudity'));
            expect(labels.single.targetEventId, equals(eventId));
            expect(labels.single.targetPubkey, isNull);
          }
          for (final pubkey in ['target_pubkey_1', 'target_pubkey_2']) {
            final labels = service.getLabelsForPubkey(pubkey);
            expect(labels, hasLength(1));
            expect(labels.single.labelValue, equals('nudity'));
            expect(labels.single.targetPubkey, equals(pubkey));
            expect(labels.single.targetEventId, isNull);
          }
        },
      );

      test(
        'accepts unmarked labels only for a single content-warning L',
        () async {
          when(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer(
            (_) async => (
              events: <Event>[
                _FakeLabelEvent(
                  pubkey: service.divineModerationPubkeyHex,
                  tags: [
                    ['L', 'content-warning'],
                    ['l', 'nudity'],
                    ['e', 'unmarked_single_namespace_event'],
                  ],
                ),
                _FakeLabelEvent(
                  pubkey: service.divineModerationPubkeyHex,
                  tags: [
                    ['l', 'violence'],
                    ['e', 'unmarked_no_namespace_event'],
                  ],
                ),
                _FakeLabelEvent(
                  pubkey: service.divineModerationPubkeyHex,
                  tags: [
                    ['L', 'content-warning'],
                    ['L', 'other-namespace'],
                    ['l', 'graphic-media'],
                    ['e', 'unmarked_ambiguous_namespace_event'],
                  ],
                ),
              ],
              timedOut: false,
              noRelays: false,
            ),
          );

          await service.subscribeToLabeler(service.divineModerationPubkeyHex);

          expect(
            service
                .getContentWarnings('unmarked_single_namespace_event')
                .map((label) => label.labelValue),
            ['nudity'],
          );
          expect(
            service.hasContentWarning('unmarked_no_namespace_event'),
            isFalse,
          );
          expect(
            service.hasContentWarning('unmarked_ambiguous_namespace_event'),
            isFalse,
          );
        },
      );

      test('trims and case-folds content-warning namespace only', () async {
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer(
          (_) async => (
            events: <Event>[
              _FakeLabelEvent(
                pubkey: service.divineModerationPubkeyHex,
                tags: [
                  ['L', ' Content-Warning '],
                  ['l', 'nudity', ' CONTENT-WARNING '],
                  ['e', 'case_folded_namespace_event'],
                ],
              ),
              _FakeLabelEvent(
                pubkey: service.divineModerationPubkeyHex,
                tags: [
                  ['L', 'content_warning'],
                  ['l', 'violence', 'content_warning'],
                  ['e', 'underscore_namespace_event'],
                ],
              ),
            ],
            timedOut: false,
            noRelays: false,
          ),
        );

        await service.subscribeToLabeler(service.divineModerationPubkeyHex);

        expect(
          service
              .getContentWarnings('case_folded_namespace_event')
              .map((label) => label.labelValue),
          ['nudity'],
        );
        expect(
          service.hasContentWarning('underscore_namespace_event'),
          isFalse,
        );
      });

      test('ignores events without content-warning namespace', () async {
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer(
          (_) async => (
            events: <Event>[
              _FakeLabelEvent(
                pubkey: service.divineModerationPubkeyHex,
                tags: [
                  ['L', 'other-namespace'],
                  ['l', 'some-label', 'other-namespace'],
                  ['e', 'ignored_event'],
                ],
              ),
            ],
            timedOut: false,
            noRelays: false,
          ),
        );

        await service.subscribeToLabeler(service.divineModerationPubkeyHex);

        expect(service.hasContentWarning('ignored_event'), isFalse);
      });
    });

    group('getAIDetectionResult', () {
      test('returns result for event with ai-generated label', () async {
        const metadata = '{"confidence": 0.73, "source": "hiveai"}';
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer(
          (_) async => (
            events: <Event>[
              _FakeLabelEvent(
                pubkey: service.divineModerationPubkeyHex,
                tags: [
                  ['L', 'content-warning'],
                  ['l', 'ai-generated', 'content-warning', metadata],
                  ['e', 'ai_event_1'],
                ],
              ),
            ],
            timedOut: false,
            noRelays: false,
          ),
        );

        await service.subscribeToLabeler(service.divineModerationPubkeyHex);

        final result = service.getAIDetectionResult('ai_event_1');
        expect(result, isNotNull);
        expect(result!.score, equals(0.73));
        expect(result.source, equals('hiveai'));
      });

      test('returns null for event without ai-generated label', () async {
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer(
          (_) async => (
            events: <Event>[
              _FakeLabelEvent(
                pubkey: service.divineModerationPubkeyHex,
                tags: [
                  ['L', 'content-warning'],
                  ['l', 'nudity', 'content-warning'],
                  ['e', 'non_ai_event'],
                ],
              ),
            ],
            timedOut: false,
            noRelays: false,
          ),
        );

        await service.subscribeToLabeler(service.divineModerationPubkeyHex);

        final result = service.getAIDetectionResult('non_ai_event');
        expect(result, isNull);
      });

      test('returns null for unknown event ID', () {
        final result = service.getAIDetectionResult('unknown_id');
        expect(result, isNull);
      });
    });

    group('getAIDetectionByHash', () {
      test('returns null for unknown hash', () {
        final result = service.getAIDetectionByHash('unknown_hash');
        expect(result, isNull);
      });
    });

    group('hasContentWarning', () {
      test('returns false for unknown event', () {
        expect(service.hasContentWarning('unknown'), isFalse);
      });
    });

    group('followed labelers', () {
      test('enables followed pubkeys as trusted labelers', () async {
        const followedLabeler =
            'abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd';
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer(
          (_) async => (
            events: <Event>[
              _FakeLabelEvent(
                pubkey: followedLabeler,
                tags: [
                  ['L', 'content-warning'],
                  ['l', 'nudity', 'content-warning'],
                  ['e', 'followed_event'],
                ],
              ),
            ],
            timedOut: false,
            noRelays: false,
          ),
        );

        await service.setFollowingModerationEnabled(
          true,
          followedPubkeys: [followedLabeler],
        );

        expect(service.isFollowingModerationEnabled, isTrue);
        expect(service.getContentWarnings('followed_event'), hasLength(1));
      });

      test('retries followed labelers enabled before relay readiness', () async {
        const followedLabeler =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        var canQueryRelays = false;
        final gatedService = ModerationLabelService(
          nostrClient: mockNostrClient,
          authService: mockAuthService,
          sharedPreferences: mockPrefs,
          canQueryRelays: () => canQueryRelays,
        );
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer(
          (_) async => (
            events: <Event>[
              _FakeLabelEvent(
                pubkey: followedLabeler,
                tags: [
                  ['L', 'content-warning'],
                  ['l', 'nudity', 'content-warning'],
                  ['e', 'deferred_followed_event'],
                ],
              ),
            ],
            timedOut: false,
            noRelays: false,
          ),
        );

        await gatedService.setFollowingModerationEnabled(
          true,
          followedPubkeys: [followedLabeler],
        );

        expect(gatedService.isFollowingModerationEnabled, isTrue);
        expect(
          gatedService.getContentWarnings('deferred_followed_event'),
          isEmpty,
        );
        verifyNever(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        );

        canQueryRelays = true;
        await gatedService.syncFollowedLabelers([followedLabeler]);

        expect(
          gatedService.getContentWarnings('deferred_followed_event'),
          hasLength(1),
        );
        verify(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).called(1);
      });

      test('coalesces concurrent labeler subscriptions', () async {
        const labeler =
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
        final events =
            Completer<({List<Event> events, bool timedOut, bool noRelays})>();
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer((_) => events.future);

        final firstSubscribe = service.subscribeToLabeler(labeler);
        final secondSubscribe = service.subscribeToLabeler(labeler);
        await Future<void>.delayed(Duration.zero);

        verify(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).called(1);

        events.complete((
          events: <Event>[
            _FakeLabelEvent(
              pubkey: labeler,
              tags: [
                ['L', 'content-warning'],
                ['l', 'nudity', 'content-warning'],
                ['e', 'coalesced_event'],
              ],
            ),
          ],
          timedOut: false,
          noRelays: false,
        ));
        await Future.wait([firstSubscribe, secondSubscribe]);

        expect(service.getContentWarnings('coalesced_event'), hasLength(1));
      });

      test('refollow during a cancelled load starts a fresh load', () async {
        const labeler =
            'abababababababababababababababababababababababababababababababab';
        final firstPage =
            Completer<({List<Event> events, bool timedOut, bool noRelays})>();
        var queryCount = 0;
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer((_) {
          queryCount++;
          if (queryCount == 1) return firstPage.future;
          return Future.value((
            events: <Event>[
              _FakeLabelEvent(
                pubkey: labeler,
                tags: [
                  ['L', 'content-warning'],
                  ['l', 'nudity', 'content-warning'],
                  ['e', 'refollowed_event'],
                ],
              ),
            ],
            timedOut: false,
            noRelays: false,
          ));
        });

        final initialFollow = service.setFollowingModerationEnabled(
          true,
          followedPubkeys: [labeler],
        );
        await pumpEventQueue();

        await service.syncFollowedLabelers(const []);
        final refollow = service.syncFollowedLabelers([labeler]);
        firstPage.complete((
          events: <Event>[],
          timedOut: false,
          noRelays: false,
        ));
        await Future.wait([initialFollow, refollow]);

        expect(queryCount, 2, reason: 'the refollow needs a new generation');
        expect(service.getContentWarnings('refollowed_event'), hasLength(1));
      });

      test('disabling followed labelers removes their cached labels', () async {
        const followedLabeler =
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer(
          (_) async => (
            events: <Event>[
              _FakeLabelEvent(
                pubkey: followedLabeler,
                tags: [
                  ['L', 'content-warning'],
                  ['l', 'violence', 'content-warning'],
                  ['e', 'followed_event_2'],
                ],
              ),
            ],
            timedOut: false,
            noRelays: false,
          ),
        );

        await service.setFollowingModerationEnabled(
          true,
          followedPubkeys: [followedLabeler],
        );
        expect(service.getContentWarnings('followed_event_2'), hasLength(1));

        await service.setFollowingModerationEnabled(false);

        expect(service.isFollowingModerationEnabled, isFalse);
        expect(service.getContentWarnings('followed_event_2'), isEmpty);
      });

      test(
        'disabling followed labelers keeps explicitly subscribed labelers',
        () async {
          const explicitLabeler =
              'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
          when(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer(
            (_) async => (
              events: <Event>[
                _FakeLabelEvent(
                  pubkey: explicitLabeler,
                  tags: [
                    ['L', 'content-warning'],
                    ['l', 'graphic-media', 'content-warning'],
                    ['e', 'explicit_event'],
                  ],
                ),
              ],
              timedOut: false,
              noRelays: false,
            ),
          );

          await service.addLabeler(explicitLabeler);
          await service.setFollowingModerationEnabled(
            true,
            followedPubkeys: [explicitLabeler],
          );
          await service.setFollowingModerationEnabled(false);

          expect(service.getContentWarnings('explicit_event'), hasLength(1));
        },
      );

      test(
        'disabling followed moderation cancels a queued labeler retry',
        () async {
          const followedLabeler =
              'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
          final statuses =
              StreamController<Map<String, RelayConnectionStatus>>.broadcast();
          addTearDown(statuses.close);
          when(
            () => mockNostrClient.relayStatusStream,
          ).thenAnswer((_) => statuses.stream);
          when(() => mockNostrClient.connectedRelayCount).thenReturn(0);
          when(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer(
            (_) async => (
              events: <Event>[
                _FakeLabelEvent(
                  pubkey: followedLabeler,
                  tags: [
                    ['L', 'content-warning'],
                    ['l', 'violence', 'content-warning'],
                    ['e', 'removed_followed_event'],
                  ],
                ),
              ],
              timedOut: true,
              noRelays: false,
            ),
          );

          await service.setFollowingModerationEnabled(
            true,
            followedPubkeys: [followedLabeler],
          );
          expect(
            service.getContentWarnings('removed_followed_event'),
            hasLength(1),
          );

          await service.setFollowingModerationEnabled(false);
          statuses.add({
            'wss://relay.example': RelayConnectionStatus.connected(
              'wss://relay.example',
            ),
          });
          await pumpEventQueue();

          expect(service.getContentWarnings('removed_followed_event'), isEmpty);
          verify(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).called(1);
        },
      );
    });

    group('incomplete labeler loads (#8214)', () {
      const labeler =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

      _FakeLabelEvent labelFor(String eventId) => _FakeLabelEvent(
        pubkey: labeler,
        tags: [
          ['L', 'content-warning'],
          ['l', 'nudity', 'content-warning'],
          ['e', eventId],
        ],
      );

      test(
        'a timed-out load is not latched, so a later call retries',
        () async {
          when(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer(
            (_) async => (events: <Event>[], timedOut: true, noRelays: false),
          );

          await service.subscribeToLabeler(labeler);
          expect(service.getContentWarnings('timed_out_event'), isEmpty);

          when(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer(
            (_) async => (
              events: <Event>[labelFor('timed_out_event')],
              timedOut: false,
              noRelays: false,
            ),
          );

          await service.subscribeToLabeler(labeler);

          expect(service.getContentWarnings('timed_out_event'), hasLength(1));
        },
      );

      test('a no-relay load is not latched, so a later call retries', () async {
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer(
          (_) async => (events: <Event>[], timedOut: false, noRelays: true),
        );

        await service.subscribeToLabeler(labeler);
        expect(service.getContentWarnings('no_relay_event'), isEmpty);

        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer(
          (_) async => (
            events: <Event>[labelFor('no_relay_event')],
            timedOut: false,
            noRelays: false,
          ),
        );

        await service.subscribeToLabeler(labeler);

        expect(service.getContentWarnings('no_relay_event'), hasLength(1));
      });

      test(
        'an answered-but-empty load still latches, so there is no retry storm',
        () async {
          when(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer(
            (_) async => (events: <Event>[], timedOut: false, noRelays: false),
          );

          await service.subscribeToLabeler(labeler);
          await service.subscribeToLabeler(labeler);

          verify(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).called(1);
        },
      );

      test('retries an abandoned labeler when a relay connects', () async {
        // Broadcast, like the real relayStatusStream: a single-subscription
        // controller's close() never completes when nothing listened.
        final statuses =
            StreamController<Map<String, RelayConnectionStatus>>.broadcast();
        addTearDown(statuses.close);
        when(
          () => mockNostrClient.relayStatusStream,
        ).thenAnswer((_) => statuses.stream);
        when(() => mockNostrClient.connectedRelayCount).thenReturn(0);
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer(
          (_) async => (events: <Event>[], timedOut: true, noRelays: false),
        );

        await service.subscribeToLabeler(labeler);
        expect(service.getContentWarnings('relay_ready_event'), isEmpty);

        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer(
          (_) async => (
            events: <Event>[labelFor('relay_ready_event')],
            timedOut: false,
            noRelays: false,
          ),
        );

        statuses.add({
          'wss://relay.example': RelayConnectionStatus.connected(
            'wss://relay.example',
          ),
        });
        await pumpEventQueue();

        expect(
          service.getContentWarnings('relay_ready_event'),
          hasLength(1),
          reason: 'the labeler must reload once a relay is available',
        );
      });

      test('dispose cancels the pending relay-ready retry', () async {
        // Broadcast, like the real relayStatusStream: a single-subscription
        // controller's close() never completes when nothing listened.
        final statuses =
            StreamController<Map<String, RelayConnectionStatus>>.broadcast();
        addTearDown(statuses.close);
        when(
          () => mockNostrClient.relayStatusStream,
        ).thenAnswer((_) => statuses.stream);
        when(() => mockNostrClient.connectedRelayCount).thenReturn(0);
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer(
          (_) async => (events: <Event>[], timedOut: true, noRelays: false),
        );

        await service.subscribeToLabeler(labeler);
        expect(
          statuses.hasListener,
          isTrue,
          reason: 'an abandoned load must be waiting on relay status',
        );

        service.dispose();
        await pumpEventQueue();

        expect(statuses.hasListener, isFalse);
      });

      test(
        'does not spin when a relay is connected but the load keeps timing out',
        () async {
          final statuses =
              StreamController<Map<String, RelayConnectionStatus>>();
          addTearDown(statuses.close);
          when(
            () => mockNostrClient.relayStatusStream,
          ).thenAnswer((_) => statuses.stream);
          // A relay IS connected — the query still does not settle.
          when(() => mockNostrClient.connectedRelayCount).thenReturn(1);
          var calls = 0;
          when(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer((_) async {
            calls++;
            return (events: <Event>[], timedOut: true, noRelays: false);
          });

          await service.subscribeToLabeler(labeler);
          await pumpEventQueue();

          expect(
            calls,
            1,
            reason: 'an abandoned load must not immediately re-drive itself',
          );
        },
      );

      test(
        'does not retry for unrelated status churn while a relay stays connected',
        () async {
          final statuses =
              StreamController<Map<String, RelayConnectionStatus>>.broadcast();
          addTearDown(statuses.close);
          when(
            () => mockNostrClient.relayStatusStream,
          ).thenAnswer((_) => statuses.stream);
          when(() => mockNostrClient.connectedRelayCount).thenReturn(1);
          when(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer(
            (_) async => (events: <Event>[], timedOut: true, noRelays: false),
          );

          await service.subscribeToLabeler(labeler);
          statuses.add({
            'wss://stable.example': RelayConnectionStatus.connected(
              'wss://stable.example',
            ),
            'wss://flapping.example': RelayConnectionStatus.connecting(
              'wss://flapping.example',
            ),
          });
          await pumpEventQueue();

          verify(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).called(1);
        },
      );

      test(
        'applies cached labels even when the relay did not answer',
        () async {
          final statuses =
              StreamController<Map<String, RelayConnectionStatus>>();
          addTearDown(statuses.close);
          when(
            () => mockNostrClient.relayStatusStream,
          ).thenAnswer((_) => statuses.stream);
          when(() => mockNostrClient.connectedRelayCount).thenReturn(0);
          // queryEventsDetailed merges cached rows into `events` regardless of
          // timedOut/noRelays, so an unanswered query can still carry labels.
          when(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer(
            (_) async => (
              events: <Event>[labelFor('cached_event')],
              timedOut: true,
              noRelays: false,
            ),
          );

          await service.subscribeToLabeler(labeler);

          expect(
            service.getContentWarnings('cached_event'),
            hasLength(1),
            reason:
                'a cached label must not be dropped just because the relay '
                'never answered',
          );
        },
      );

      test('a load completing after dispose does not re-arm a retry', () async {
        // Broadcast, like the real relayStatusStream: a single-subscription
        // controller's close() never completes when nothing listened.
        final statuses =
            StreamController<Map<String, RelayConnectionStatus>>.broadcast();
        addTearDown(statuses.close);
        when(
          () => mockNostrClient.relayStatusStream,
        ).thenAnswer((_) => statuses.stream);
        when(() => mockNostrClient.connectedRelayCount).thenReturn(0);
        final inFlight =
            Completer<({List<Event> events, bool timedOut, bool noRelays})>();
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer((_) => inFlight.future);

        final pending = service.subscribeToLabeler(labeler);
        await Future<void>.delayed(Duration.zero);

        service.dispose();

        inFlight.complete((events: <Event>[], timedOut: true, noRelays: false));
        await pending;
        await pumpEventQueue();

        expect(
          statuses.hasListener,
          isFalse,
          reason: 'a disposed service must not subscribe to relay status',
        );
      });

      test(
        'a retry replaces the labeler rows instead of appending them',
        () async {
          when(() => mockNostrClient.relayStatusStream).thenAnswer(
            (_) => const Stream<Map<String, RelayConnectionStatus>>.empty(),
          );
          when(() => mockNostrClient.connectedRelayCount).thenReturn(0);
          // First attempt: cache rows present, relay silent.
          when(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer(
            (_) async => (
              events: <Event>[labelFor('repeat_event')],
              timedOut: true,
              noRelays: false,
            ),
          );
          await service.subscribeToLabeler(labeler);
          expect(service.getContentWarnings('repeat_event'), hasLength(1));

          // Retry: the relay answers with the same event.
          when(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer(
            (_) async => (
              events: <Event>[labelFor('repeat_event')],
              timedOut: false,
              noRelays: false,
            ),
          );
          await service.subscribeToLabeler(labeler);

          expect(
            service.getContentWarnings('repeat_event'),
            hasLength(1),
            reason: 'reprocessing the same label must not accumulate rows',
          );
        },
      );

      test('an empty incomplete retry preserves known label rows', () async {
        when(() => mockNostrClient.relayStatusStream).thenAnswer(
          (_) => const Stream<Map<String, RelayConnectionStatus>>.empty(),
        );
        when(() => mockNostrClient.connectedRelayCount).thenReturn(0);
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer(
          (_) async => (
            events: <Event>[labelFor('preserved_event')],
            timedOut: true,
            noRelays: false,
          ),
        );
        await service.subscribeToLabeler(labeler);
        expect(service.getContentWarnings('preserved_event'), hasLength(1));

        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer(
          (_) async => (events: <Event>[], timedOut: false, noRelays: true),
        );
        await service.subscribeToLabeler(labeler);

        expect(
          service.getContentWarnings('preserved_event'),
          hasLength(1),
          reason: 'an inconclusive empty read must not erase known warnings',
        );
      });
    });

    group('labeler history paging (#8252)', () {
      const labeler =
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

      _FakeLabelEvent labelEvent(
        String id,
        int createdAt,
        String targetEventId,
      ) => _FakeLabelEvent(
        pubkey: labeler,
        id: id,
        createdAt: createdAt,
        tags: [
          ['L', 'content-warning'],
          ['l', 'nudity', 'content-warning'],
          ['e', targetEventId],
        ],
      );

      ModerationLabelService pagedService(int pageSize) =>
          ModerationLabelService(
            nostrClient: mockNostrClient,
            authService: mockAuthService,
            sharedPreferences: mockPrefs,
            canQueryRelays: () => true,
            labelerHistoryPageSize: pageSize,
          );

      test(
        'the first-page query carries an explicit limit and no until',
        () async {
          final capturedFilters = <List<Filter>>[];
          when(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer((invocation) async {
            capturedFilters.add(
              invocation.positionalArguments.first as List<Filter>,
            );
            return (events: <Event>[], timedOut: false, noRelays: false);
          });

          await service.subscribeToLabeler(labeler);

          final filter = capturedFilters.single.single;
          expect(
            filter.limit,
            ModerationLabelService.defaultLabelerHistoryPageSize,
          );
          expect(filter.until, isNull);
          expect(filter.authors, [labeler]);
          expect(filter.kinds, [NostrEventKinds.label]);
        },
      );

      test(
        'pages backward until a short page, applying every label once across '
        'the inclusive boundary',
        () async {
          final paged = pagedService(2);
          when(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer((invocation) async {
            final until = (invocation.positionalArguments.first as List<Filter>)
                .single
                .until;
            if (until == null) {
              return (
                events: <Event>[
                  labelEvent('id_a', 100, 'target_a'),
                  labelEvent('id_b', 90, 'target_b'),
                ],
                timedOut: false,
                noRelays: false,
              );
            }
            if (until == 90) {
              return (
                events: <Event>[
                  labelEvent('id_b', 90, 'target_b'), // inclusive boundary
                  labelEvent('id_c', 80, 'target_c'),
                ],
                timedOut: false,
                noRelays: false,
              );
            }
            // until == 80: only the boundary repeats -> short page ends paging.
            return (
              events: <Event>[labelEvent('id_c', 80, 'target_c')],
              timedOut: false,
              noRelays: false,
            );
          });

          await paged.subscribeToLabeler(labeler);

          expect(paged.getContentWarnings('target_a'), hasLength(1));
          expect(paged.getContentWarnings('target_b'), hasLength(1));
          expect(paged.getContentWarnings('target_c'), hasLength(1));
          verify(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).called(3);
        },
      );

      test(
        'stops when a full page is entirely duplicates so it cannot spin',
        () async {
          final paged = pagedService(2);
          when(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer((invocation) async {
            // A misbehaving relay ignores `until` and returns the same full
            // page every time; the cursor cannot advance, so paging must stop.
            return (
              events: <Event>[
                labelEvent('id_a', 100, 'target_a'),
                labelEvent('id_b', 90, 'target_b'),
              ],
              timedOut: false,
              noRelays: false,
            );
          });

          await paged.subscribeToLabeler(labeler);

          expect(paged.getContentWarnings('target_a'), hasLength(1));
          expect(paged.getContentWarnings('target_b'), hasLength(1));

          // The relay, not the protocol, stopped this walk by ignoring until.
          // It must remain retryable instead of latching truncated history.
          await paged.subscribeToLabeler(labeler);
          verify(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).called(4);
        },
      );

      test(
        'a timed-out later page applies the collected labels but does not latch',
        () async {
          final paged = pagedService(2);
          when(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer((invocation) async {
            final until = (invocation.positionalArguments.first as List<Filter>)
                .single
                .until;
            if (until == null) {
              return (
                events: <Event>[
                  labelEvent('id_a', 100, 'target_a'),
                  labelEvent('id_b', 90, 'target_b'),
                ],
                timedOut: false,
                noRelays: false,
              );
            }
            // The second page never settles.
            return (events: <Event>[], timedOut: true, noRelays: false);
          });

          await paged.subscribeToLabeler(labeler);
          expect(paged.getContentWarnings('target_a'), hasLength(1));
          expect(paged.getContentWarnings('target_b'), hasLength(1));

          // Not latched: a later call re-walks rather than short-circuiting.
          await paged.subscribeToLabeler(labeler);
          verify(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).called(4);
        },
      );

      test(
        'pages past a second that fills a whole page so older history still '
        'loads',
        () async {
          final paged = pagedService(2);
          // Second 90 holds a full page (b, c) with older history (d@80)
          // behind it. A relay that honours `until` + `limit` newest-first
          // must not let that dense second wall off the older label.
          final history = <_FakeLabelEvent>[
            labelEvent('id_a', 100, 'target_a'),
            labelEvent('id_b', 90, 'target_b'),
            labelEvent('id_c', 90, 'target_c'),
            labelEvent('id_d', 80, 'target_d'),
          ];
          when(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer((invocation) async {
            final until = (invocation.positionalArguments.first as List<Filter>)
                .single
                .until;
            final matching =
                history
                    .where((e) => until == null || e.createdAt <= until)
                    .toList()
                  ..sort((x, y) => y.createdAt.compareTo(x.createdAt));
            return (
              events: matching.take(2).toList(),
              timedOut: false,
              noRelays: false,
            );
          });

          await paged.subscribeToLabeler(labeler);

          expect(paged.getContentWarnings('target_a'), hasLength(1));
          expect(paged.getContentWarnings('target_b'), hasLength(1));
          expect(paged.getContentWarnings('target_c'), hasLength(1));
          expect(
            paged.getContentWarnings('target_d'),
            hasLength(1),
            reason: 'a full page at one second must not wall off older history',
          );
        },
      );

      test(
        'stops at the page cap against a relay that never signals the end',
        () async {
          final paged = ModerationLabelService(
            nostrClient: mockNostrClient,
            authService: mockAuthService,
            sharedPreferences: mockPrefs,
            canQueryRelays: () => true,
            labelerHistoryPageSize: 2,
            maxLabelerHistoryPages: 3,
          );
          // A hostile relay fabricates a full page at exactly the requested
          // `until` on every response, so the cursor steps backward forever.
          // Without the cap this never terminates.
          when(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer((invocation) async {
            final until = (invocation.positionalArguments.first as List<Filter>)
                .single
                .until;
            final ts = until ?? 100;
            return (
              events: <Event>[
                labelEvent('dup_1', ts, 'target_dup_1'),
                labelEvent('dup_2', ts, 'target_dup_2'),
              ],
              timedOut: false,
              noRelays: false,
            );
          });

          await paged.subscribeToLabeler(labeler);

          // Terminated at the cap rather than hanging, and applied what it had.
          verify(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).called(3);
          expect(paged.getContentWarnings('target_dup_1'), hasLength(1));
          expect(paged.getContentWarnings('target_dup_2'), hasLength(1));
        },
      );

      test(
        'a walk that spends its time budget stops paging and stays retryable',
        () async {
          final paged = ModerationLabelService(
            nostrClient: mockNostrClient,
            authService: mockAuthService,
            sharedPreferences: mockPrefs,
            canQueryRelays: () => true,
            labelerHistoryPageSize: 2,
            // The page cap stays at its default, far beyond what this walk
            // reaches: the budget, not the cap, has to stop a relay that
            // answers endlessly.
            labelerHistoryBudget: Duration.zero,
          );
          when(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer((invocation) async {
            final until = (invocation.positionalArguments.first as List<Filter>)
                .single
                .until;
            final ts = until ?? 100;
            return (
              events: <Event>[
                labelEvent('dup_1', ts, 'target_dup_1'),
                labelEvent('dup_2', ts, 'target_dup_2'),
              ],
              timedOut: false,
              noRelays: false,
            );
          });

          await paged.subscribeToLabeler(labeler);
          // One page, then the budget stops it — and the first page's labels
          // are applied rather than discarded.
          verify(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).called(1);
          expect(paged.getContentWarnings('target_dup_1'), hasLength(1));

          // Not latched: an incomplete walk must stay retryable.
          await paged.subscribeToLabeler(labeler);
          verify(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).called(1);
        },
      );

      test(
        'a labeler unfollowed mid-walk does not get its labels reapplied',
        () async {
          final paged = pagedService(2);
          when(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer((invocation) async {
            final until = (invocation.positionalArguments.first as List<Filter>)
                .single
                .until;
            if (until == null) {
              return (
                events: <Event>[
                  labelEvent('id_a', 100, 'target_a'),
                  labelEvent('id_b', 90, 'target_b'),
                ],
                timedOut: false,
                noRelays: false,
              );
            }
            // The user unfollows the labeler while the walk is mid-flight.
            await paged.removeLabeler(labeler);
            return (
              events: <Event>[labelEvent('id_b', 90, 'target_b')],
              timedOut: false,
              noRelays: false,
            );
          });

          await paged.subscribeToLabeler(labeler);

          expect(
            paged.getContentWarnings('target_a'),
            isEmpty,
            reason: 'the walk must not restore rows the unload just dropped',
          );
          expect(paged.getContentWarnings('target_b'), isEmpty);
        },
      );

      test(
        'a disposed service stops walking instead of querying for more pages',
        () async {
          late final ModerationLabelService paged;
          paged = ModerationLabelService(
            nostrClient: mockNostrClient,
            authService: mockAuthService,
            sharedPreferences: mockPrefs,
            canQueryRelays: () => true,
            labelerHistoryPageSize: 2,
            maxLabelerHistoryPages: 5,
          );
          var queries = 0;
          when(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer((invocation) async {
            queries++;
            final until = (invocation.positionalArguments.first as List<Filter>)
                .single
                .until;
            final ts = until ?? 100;
            // A relay that keeps handing back a full page would walk to the
            // cap; dispose() during the second page must stop it sooner.
            if (queries == 2) paged.dispose();
            return (
              events: <Event>[
                labelEvent('dup_1', ts, 'target_dup_1'),
                labelEvent('dup_2', ts, 'target_dup_2'),
              ],
              timedOut: false,
              noRelays: false,
            );
          });

          await paged.subscribeToLabeler(labeler);

          expect(queries, 2, reason: 'the walk must stop at the next check');
          expect(paged.getContentWarnings('target_dup_1'), isEmpty);
        },
      );

      test(
        'a walk stopped by the page cap stays retryable rather than latching '
        'the omitted history',
        () async {
          final paged = ModerationLabelService(
            nostrClient: mockNostrClient,
            authService: mockAuthService,
            sharedPreferences: mockPrefs,
            canQueryRelays: () => true,
            labelerHistoryPageSize: 2,
            maxLabelerHistoryPages: 2,
          );
          when(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer((invocation) async {
            final until = (invocation.positionalArguments.first as List<Filter>)
                .single
                .until;
            final ts = until ?? 100;
            return (
              events: <Event>[
                labelEvent('dup_1', ts, 'target_dup_1'),
                labelEvent('dup_2', ts, 'target_dup_2'),
              ],
              timedOut: false,
              noRelays: false,
            );
          });

          await paged.subscribeToLabeler(labeler);
          await paged.subscribeToLabeler(labeler);

          // 2 pages per walk. Latching the labeler after the cap fired would
          // short-circuit the second call and leave the omitted history gone
          // for the rest of the session.
          verify(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).called(4);
        },
      );
    });
  });

  group('live tail subscription (#8255)', () {
    Event liveLabelFrom(String labeler, String id, String targetEventId) =>
        _FakeLabelEvent(
          pubkey: labeler,
          id: id,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          tags: [
            ['L', 'content-warning'],
            ['l', 'nudity', 'content-warning'],
            ['e', targetEventId],
          ],
        );

    Event liveLabel(String id, String targetEventId) =>
        liveLabelFrom(service.divineModerationPubkeyHex, id, targetEventId);

    void stubCompletedBackfill() {
      when(
        () => mockNostrClient.queryEventsDetailed(
          any(),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      ).thenAnswer(
        (_) async => (events: <Event>[], timedOut: false, noRelays: false),
      );
    }

    test(
      'all followed labelers share one live relay subscription',
      () async {
        stubCompletedBackfill();
        final tails = <StreamController<Event>>[];
        var activeListeners = 0;
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            onEose: any(named: 'onEose'),
          ),
        ).thenAnswer((_) {
          late final StreamController<Event> tail;
          tail = StreamController<Event>.broadcast(
            onListen: () => activeListeners++,
            onCancel: () => activeListeners--,
          );
          tails.add(tail);
          return tail.stream;
        });
        addTearDown(() async {
          service.dispose();
          await Future.wait(tails.map((tail) => tail.close()));
        });

        const followed = [
          '1111111111111111111111111111111111111111111111111111111111111111',
          '2222222222222222222222222222222222222222222222222222222222222222',
          '3333333333333333333333333333333333333333333333333333333333333333',
        ];
        await service.setFollowingModerationEnabled(
          true,
          followedPubkeys: followed,
        );

        expect(activeListeners, 1);
        final captured = verify(
          () => mockNostrClient.subscribe(
            captureAny(),
            subscriptionId: any(named: 'subscriptionId'),
            onEose: any(named: 'onEose'),
          ),
        ).captured;
        expect(captured, hasLength(1));
        final filter = (captured.single as List<Filter>).single;
        expect(filter.authors, unorderedEquals(followed));
        expect(filter.kinds, [NostrEventKinds.label]);
      },
    );

    test('changing labelers replaces the shared author filter', () async {
      stubCompletedBackfill();
      final tails = <StreamController<Event>>[];
      var activeListeners = 0;
      when(
        () => mockNostrClient.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          onEose: any(named: 'onEose'),
        ),
      ).thenAnswer((_) {
        late final StreamController<Event> tail;
        tail = StreamController<Event>.broadcast(
          onListen: () => activeListeners++,
          onCancel: () => activeListeners--,
        );
        tails.add(tail);
        return tail.stream;
      });
      addTearDown(() async {
        service.dispose();
        await Future.wait(tails.map((tail) => tail.close()));
      });

      const first =
          '4444444444444444444444444444444444444444444444444444444444444444';
      const second =
          '5555555555555555555555555555555555555555555555555555555555555555';
      await service.addLabeler(first);
      await service.addLabeler(second);
      await service.removeLabeler(first);

      expect(activeListeners, 1);
      final captured = verify(
        () => mockNostrClient.subscribe(
          captureAny(),
          subscriptionId: any(named: 'subscriptionId'),
          onEose: any(named: 'onEose'),
        ),
      ).captured;
      final lastFilter = (captured.last as List<Filter>).single;
      expect(lastFilter.authors, [second]);
    });

    test('an event without a Nostr id is rejected', () async {
      when(
        () => mockNostrClient.queryEventsDetailed(
          any(),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      ).thenAnswer(
        (_) async => (
          events: <Event>[
            _FakeLabelEvent(
              pubkey: service.divineModerationPubkeyHex,
              id: '',
              tags: [
                ['L', 'content-warning'],
                ['l', 'nudity', 'content-warning'],
                ['e', 'invalid_id_target'],
              ],
            ),
          ],
          timedOut: false,
          noRelays: false,
        ),
      );

      await service.subscribeToLabeler(service.divineModerationPubkeyHex);

      expect(service.getContentWarnings('invalid_id_target'), isEmpty);
    });

    test(
      'a label published after the initial load reaches the maps without a '
      'restart',
      () async {
        // Backfill returns nothing and completes, so the labeler latches loaded
        // and the service opens its live tail.
        stubCompletedBackfill();
        final tail = StreamController<Event>.broadcast();
        addTearDown(tail.close);
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            onEose: any(named: 'onEose'),
          ),
        ).thenAnswer((_) => tail.stream);

        await service.subscribeToLabeler(service.divineModerationPubkeyHex);
        expect(service.getContentWarnings('live_target'), isEmpty);

        // A moderator labels a video mid-session.
        tail.add(liveLabel('live_evt_1', 'live_target'));
        await pumpEventQueue();

        final warnings = service.getContentWarnings('live_target');
        expect(warnings, hasLength(1));
        expect(warnings.first.labelValue, 'nudity');
      },
    );

    test(
      'the same tail event arriving twice produces one label row (dedup)',
      () async {
        // A re-issued REQ across a reconnect replays the relay's stored window,
        // so the same kind-1985 event arrives again. It must not double-count.
        stubCompletedBackfill();
        final tail = StreamController<Event>.broadcast();
        addTearDown(tail.close);
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            onEose: any(named: 'onEose'),
          ),
        ).thenAnswer((_) => tail.stream);

        await service.subscribeToLabeler(service.divineModerationPubkeyHex);

        tail.add(liveLabel('dup_evt', 'dup_target'));
        tail.add(liveLabel('dup_evt', 'dup_target'));
        await pumpEventQueue();

        expect(service.getContentWarnings('dup_target'), hasLength(1));
      },
    );

    test(
      'an older replay is ignored after an author watermark advances',
      () async {
        stubCompletedBackfill();
        final tail = StreamController<Event>.broadcast();
        addTearDown(tail.close);
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            onEose: any(named: 'onEose'),
          ),
        ).thenAnswer((_) => tail.stream);

        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        await service.subscribeToLabeler(service.divineModerationPubkeyHex);
        tail.add(
          _FakeLabelEvent(
            pubkey: service.divineModerationPubkeyHex,
            id: 'newer_evt',
            createdAt: now + 1,
            tags: [
              ['L', 'content-warning'],
              ['l', 'nudity', 'content-warning'],
              ['e', 'newer_target'],
            ],
          ),
        );
        tail.add(
          _FakeLabelEvent(
            pubkey: service.divineModerationPubkeyHex,
            id: 'older_evt',
            createdAt: now,
            tags: [
              ['L', 'content-warning'],
              ['l', 'nudity', 'content-warning'],
              ['e', 'older_target'],
            ],
          ),
        );
        await pumpEventQueue();

        expect(service.getContentWarnings('newer_target'), hasLength(1));
        expect(service.getContentWarnings('older_target'), isEmpty);
      },
    );

    test(
      'removing a labeler cancels its live tail so later labels do not land',
      () async {
        const custom =
            'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1';
        stubCompletedBackfill();
        final tail = StreamController<Event>.broadcast();
        addTearDown(tail.close);
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            onEose: any(named: 'onEose'),
          ),
        ).thenAnswer((_) => tail.stream);

        await service.addLabeler(custom);

        tail.add(liveLabelFrom(custom, 'before_evt', 'before_target'));
        await pumpEventQueue();
        expect(service.getContentWarnings('before_target'), hasLength(1));

        await service.removeLabeler(custom);

        // A label published after removal must not reach the maps.
        tail.add(liveLabelFrom(custom, 'after_evt', 'after_target'));
        await pumpEventQueue();
        expect(service.getContentWarnings('after_target'), isEmpty);
      },
    );

    test(
      'a dropped tail stream reconnects so later labels still land',
      () async {
        final svc = ModerationLabelService(
          nostrClient: mockNostrClient,
          authService: mockAuthService,
          sharedPreferences: mockPrefs,
          tailReconnectDelay: Duration.zero,
        );
        stubCompletedBackfill();
        final first = StreamController<Event>.broadcast();
        final second = StreamController<Event>.broadcast();
        addTearDown(() {
          first.close();
          second.close();
          svc.dispose();
        });
        var calls = 0;
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            onEose: any(named: 'onEose'),
          ),
        ).thenAnswer((_) {
          calls++;
          return calls == 1 ? first.stream : second.stream;
        });

        const custom =
            'b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2';
        await svc.addLabeler(custom);
        expect(calls, 1);

        // The relay ends the subscription; the Dart stream closes.
        await first.close();
        await pumpEventQueue();

        expect(calls, 2, reason: 'the tail should reopen after it drops');
        final messages = LogCaptureService().getRecentLogs().map(
          (entry) => entry.message,
        );
        expect(
          messages,
          contains('Moderation label tail dropped (stream closed)'),
        );
        expect(messages, contains('Re-subscribing to moderation labels in 0s'));
        second.add(liveLabelFrom(custom, 'post', 'reconnect_tgt'));
        await pumpEventQueue();
        expect(svc.getContentWarnings('reconnect_tgt'), hasLength(1));
      },
    );

    test('dispose cancels the live tail so no later label lands', () async {
      const custom =
          'c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3';
      stubCompletedBackfill();
      final tail = StreamController<Event>.broadcast();
      addTearDown(tail.close);
      when(
        () => mockNostrClient.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          onEose: any(named: 'onEose'),
        ),
      ).thenAnswer((_) => tail.stream);

      await service.addLabeler(custom);
      service.dispose();

      tail.add(liveLabelFrom(custom, 'post_dispose', 'disposed_tgt'));
      await pumpEventQueue();
      expect(service.getContentWarnings('disposed_tgt'), isEmpty);
    });

    test(
      'a reload reapplies a labelers rows instead of dropping them as '
      'duplicates (guards the dedup clear on reprocess)',
      () async {
        const custom =
            'd4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4';
        // The same real-id event on two loads: an incomplete load applies it
        // (so the dedup set holds its id) without latching, then a complete
        // load reprocesses. _removeLabelsForLabeler must clear the dedup set so
        // the reprocess reapplies rather than skipping every event as a dup.
        var complete = false;
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer(
          (_) async => (
            events: <Event>[
              _FakeLabelEvent(
                pubkey: custom,
                id: 'reload_evt_1',
                createdAt: 100,
                tags: [
                  ['L', 'content-warning'],
                  ['l', 'nudity', 'content-warning'],
                  ['e', 'reload_tgt'],
                ],
              ),
            ],
            timedOut: !complete,
            noRelays: false,
          ),
        );

        await service.addLabeler(custom);
        expect(service.getContentWarnings('reload_tgt'), hasLength(1));

        complete = true;
        await service.subscribeToLabeler(custom);

        expect(
          service.getContentWarnings('reload_tgt'),
          hasLength(1),
          reason: 'a reload must reapply the labeler rows, not drop them',
        );
      },
    );
  });
}
