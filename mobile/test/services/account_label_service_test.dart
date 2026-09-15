// ABOUTME: Tests account-label persistence and Kind 1985 publication.
// ABOUTME: Pins the storage key shared with account cleanup.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/constants/nostr_event_kinds.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/services/account_label_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockNostrClient extends Mock implements NostrClient {}

class _FakeEvent extends Fake implements Event {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => registerFallbackValue(_FakeEvent()));

  group(AccountLabelService, () {
    late _MockAuthService authService;
    late _MockNostrClient nostrClient;
    late AccountLabelService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      authService = _MockAuthService();
      nostrClient = _MockNostrClient();
      service = AccountLabelService(
        authService: authService,
        nostrClient: nostrClient,
      );
      when(() => authService.currentPublicKeyHex).thenReturn(null);
    });

    test(
      'initialize loads persisted defaults before initialized resolves',
      () async {
        SharedPreferences.setMockInitialValues({
          AccountLabelService.accountLabelStorageKey: 'nudity,violence',
        });
        service = AccountLabelService(
          authService: authService,
          nostrClient: nostrClient,
        );

        await service.initialize();
        await service.initialized;

        expect(service.accountLabels, {
          ContentLabel.nudity,
          ContentLabel.violence,
        });
        expect(service.defaultVideoLabels, service.accountLabels);
        expect(service.hasAccountLabels, isTrue);
      },
    );

    test('persists labels and publishes a self-label event', () async {
      const pubkey =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final event = Event(pubkey, NostrEventKinds.label, const [], '');
      when(() => authService.currentPublicKeyHex).thenReturn(pubkey);
      when(
        () => authService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => event);
      when(
        () => nostrClient.publishEvent(any()),
      ).thenAnswer((_) async => PublishSuccess(event: event));

      await service.setAccountLabels({
        ContentLabel.nudity,
        ContentLabel.violence,
      });

      final prefs = await SharedPreferences.getInstance();
      expect(
        ContentLabel.fromCsv(
          prefs.getString(AccountLabelService.accountLabelStorageKey),
        ),
        {ContentLabel.nudity, ContentLabel.violence},
      );
      final call = verify(
        () => authService.createAndSignEvent(
          kind: captureAny(named: 'kind'),
          content: captureAny(named: 'content'),
          tags: captureAny(named: 'tags'),
        ),
      ).captured;
      expect(call[0], NostrEventKinds.label);
      expect(call[1], isEmpty);
      expect(
        call[2],
        containsAll(<List<String>>[
          ['L', 'content-warning'],
          ['l', 'nudity', 'content-warning'],
          ['l', 'violence', 'content-warning'],
          ['p', pubkey, 'wss://relay.divine.video'],
        ]),
      );
      verify(() => nostrClient.publishEvent(event)).called(1);
    });

    test('clearing labels removes persistence without publishing', () async {
      SharedPreferences.setMockInitialValues({
        AccountLabelService.accountLabelStorageKey: 'nudity',
      });

      await service.setAccountLabels({});

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.containsKey(AccountLabelService.accountLabelStorageKey),
        isFalse,
      );
      expect(service.buildProfileTags(), isEmpty);
      verifyNever(
        () => authService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      );
    });
  });
}
