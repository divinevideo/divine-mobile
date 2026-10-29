import 'dart:async';

import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/chat/concord_session.dart';
import 'package:openvine/features/chat/room_activity_provider.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/moderation_presentation.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/messages/messages_home_page.dart';
import 'package:openvine/screens/inbox/messages/messages_home_view.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends Fake implements AuthService {
  _Auth(this.currentPublicKeyHex, {this.isAuthenticated = true});
  @override
  final bool isAuthenticated;
  @override
  final String? currentPublicKeyHex;
  @override
  AuthState get authState =>
      isAuthenticated ? AuthState.authenticated : AuthState.unauthenticated;
  @override
  Stream<AuthState> get authStateStream => const Stream.empty();
}

final String _own = 'a' * 64;
final String _peer = 'b' * 64;

class _Cipher implements StreamCipher {
  @override
  String open(String ciphertext, String streamId) =>
      throw UnsupportedError('No legacy envelopes');

  @override
  String seal(String plaintext, String streamId) =>
      throw UnsupportedError('No legacy envelopes');
}

class _RoomRelay implements RelayGateway {
  final wraps = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> subscribe(Map<String, dynamic> filter) =>
      wraps.stream;

  @override
  Future<void> publish(Map<String, dynamic> event) async {}
}

class _LimitedRelay extends _RoomRelay implements RelayHistoryStatus {
  @override
  Future<void> get historyReady => Future.value();

  @override
  bool get historyLimited => true;
}

class _Store extends InMemoryConcordStore {
  _Store() : super(_own);

  bool failRead = false;

  @override
  Future<String?> get(String key) async {
    if (failRead) throw StateError('storage unavailable');
    return super.get(key);
  }
}

/// A catalog room holding [unread] stored messages from someone else.
Future<RoomActivityChannel> _room(
  String channel, {
  required int seed,
  required int unread,
  RelayGateway? relay,
  _Store? store,
}) async {
  final roomStore = store ?? _Store();
  final roomRelay = relay ?? _RoomRelay();
  final channelId = pocChannelIdFor(channel);
  final key = pocStreamKeyFor(channel);
  final sentAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60;
  final ids = [
    for (var i = 1; i <= unread; i++) '$seed$i'.padLeft(64, '0'),
  ];
  await roomStore.writeBatch({
    'index': ids.join(','),
    for (final id in ids) ...{
      'msg:$id': 'Hello from the room',
      'meta:$id': '$channelId|$_peer|$sentAt|',
      'sent:$id': '1',
    },
  });
  return RoomActivityChannel(
    channelId: channelId,
    repository: ConcordRepository(
      relay: roomRelay,
      store: roomStore,
      cipher: _Cipher(),
      sealedTransport: SealedChatTransport(
        relay: roomRelay,
        signer: (_) async => throw StateError('unused'),
      ),
    ),
    store: roomStore,
    streamSeedHex: key.seedHex,
    streamPubkey: key.pubkey,
  );
}

void main() {
  group(MessagesHomePage, () {
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    Future<ProviderContainer> pumpPage(
      WidgetTester tester, {
      bool enabled = true,
      bool restricted = false,
      String? account,
      RoomActivityRepository? activity,
    }) async {
      final container = ProviderContainer(
        overrides: [
          roomActivityRepositoryProvider.overrideWithValue(activity),
          authServiceProvider.overrideWithValue(_Auth(account)),
          sharedPreferencesProvider.overrideWithValue(prefs),
          featureFlagStateProvider.overrideWithValue({
            FeatureFlag.concordChat: enabled,
          }),
          isDmRestrictedProvider.overrideWithValue(restricted),
          if (activity != null) ...[
            fetchUserProfileProvider(_peer).overrideWith((ref) async => null),
            profileIdentityResolvingProvider(_peer).overrideWithValue(false),
            profileVanishedProvider(_peer).overrideWith((ref) => false),
            moderationPresentationProvider(
              _peer,
            ).overrideWithValue(ModerationPresentation.ordinary),
          ],
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessagesHomePage(direct: Text('direct-content')),
            ),
          ),
        ),
      );
      return container;
    }

    for (final scenario in [
      (enabled: false, restricted: false, account: 'a' * 64),
      (enabled: true, restricted: true, account: 'a' * 64),
      (enabled: true, restricted: false, account: null),
    ]) {
      testWidgets('keeps Direct only for access gate $scenario', (
        tester,
      ) async {
        await pumpPage(
          tester,
          enabled: scenario.enabled,
          restricted: scenario.restricted,
          account: scenario.account,
        );
        expect(find.text('direct-content'), findsOneWidget);
        expect(find.byType(MessagesHomeView), findsNothing);
      });
    }

    testWidgets('tapping a room asks the router for that room', (tester) async {
      Map<String, String>? opened;
      final container = ProviderContainer(
        overrides: [
          roomActivityRepositoryProvider.overrideWithValue(null),
          authServiceProvider.overrideWithValue(_Auth('a' * 64)),
          sharedPreferencesProvider.overrideWithValue(prefs),
          featureFlagStateProvider.overrideWithValue({
            FeatureFlag.concordChat: true,
          }),
          isDmRestrictedProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: MessagesHomePage(direct: Text('direct-content')),
            ),
          ),
          GoRoute(
            path: '/chat',
            name: 'chat',
            builder: (_, state) {
              opened = state.uri.queryParameters;
              return const SizedBox.shrink();
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l10n.messagesRooms));
      await tester.pump();
      await tester.tap(find.text('introductions'));
      await tester.pumpAndSettle();
      expect(opened, {
        'community': 'community-test',
        'channel': 'introductions',
      });
    });

    testWidgets('auth teardown hides Rooms even before the key is cleared', (
      tester,
    ) async {
      final container = await pumpPage(tester, account: 'a' * 64);
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l10n.messagesRooms));
      await tester.pump();
      container.updateOverrides([
        roomActivityRepositoryProvider.overrideWithValue(null),
        authServiceProvider.overrideWithValue(
          _Auth('a' * 64, isAuthenticated: false),
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
        featureFlagStateProvider.overrideWithValue({
          FeatureFlag.concordChat: true,
        }),
        isDmRestrictedProvider.overrideWithValue(false),
      ]);
      await tester.pump();
      expect(find.text(l10n.messagesPublicTestRooms), findsNothing);
      expect(find.byType(MessagesHomeView), findsNothing);
    });

    testWidgets('switching accounts clears the previous Rooms selection', (
      tester,
    ) async {
      final container = await pumpPage(tester, account: 'a' * 64);
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l10n.messagesRooms));
      await tester.pump();
      expect(find.text(l10n.messagesPublicTestRooms), findsOneWidget);
      container.updateOverrides([
        roomActivityRepositoryProvider.overrideWithValue(null),
        authServiceProvider.overrideWithValue(_Auth('b' * 64)),
        sharedPreferencesProvider.overrideWithValue(prefs),
        featureFlagStateProvider.overrideWithValue({
          FeatureFlag.concordChat: true,
        }),
        isDmRestrictedProvider.overrideWithValue(false),
      ]);
      await tester.pump();
      expect(find.text('direct-content'), findsOneWidget);
      expect(find.text(l10n.messagesPublicTestRooms), findsNothing);
    });

    group('room activity', () {
      final l10n = lookupAppLocalizations(const Locale('en'));

      testWidgets('totals unread on Rooms and shows each room by its id', (
        tester,
      ) async {
        late RoomActivityRepository activity;
        await tester.runAsync(() async {
          activity = RoomActivityRepository(
            ownPubkey: _own,
            channels: [
              await _room('general', seed: 1, unread: 2),
              await _room(
                'introductions',
                seed: 2,
                unread: 3,
                relay: _LimitedRelay(),
              ),
            ],
          );
          await activity.start();
        });
        addTearDown(() => tester.runAsync(activity.close));
        await pumpPage(tester, account: _own, activity: activity);
        final rooms = l10n.messagesRoomsWithUnread('5+');
        expect(find.text(rooms), findsOneWidget);
        await tester.tap(find.text(rooms));
        await tester.pump();
        expect(find.text(l10n.messagesRoomNewCount(2, '2')), findsOneWidget);
        expect(find.text(l10n.messagesRoomNewCount(3, '3+')), findsOneWidget);
      });

      testWidgets('starts room activity when Messages opens', (tester) async {
        // Built in the test zone: the page starts it there, and its timers
        // must be cancelled by close before the test ends.
        final activity = RoomActivityRepository(
          ownPubkey: _own,
          channels: [
            await _room('general', seed: 1, unread: 2),
            await _room('introductions', seed: 2, unread: 0),
          ],
        );
        await pumpPage(tester, account: _own, activity: activity);
        await tester.pump();
        expect(find.text(l10n.messagesRoomsWithUnread('2')), findsOneWidget);
        // close cancels the room timers synchronously; the pump drains the
        // rest of its work, which nothing flushes after the last pump.
        unawaited(activity.close());
        await tester.pump();
      });

      testWidgets('retry reloads a room whose activity failed', (tester) async {
        final store = _Store()..failRead = true;
        final activity = RoomActivityRepository(
          ownPubkey: _own,
          channels: [
            await _room('general', seed: 1, unread: 2, store: store),
            await _room('introductions', seed: 2, unread: 0),
          ],
        );
        await activity.start();
        await pumpPage(tester, account: _own, activity: activity);
        await tester.tap(find.text(l10n.messagesRooms));
        await tester.pump();
        expect(find.text(l10n.messagesRoomLoadFailed), findsOneWidget);
        store.failRead = false;
        await tester.tap(find.text(l10n.commonRetry));
        await tester.pump();
        await tester.pump();
        expect(find.text(l10n.messagesRoomNewCount(2, '2')), findsOneWidget);
        // close cancels the room timers synchronously; the pump drains the
        // rest of its work, which nothing flushes after the last pump.
        unawaited(activity.close());
        await tester.pump();
      });
    });
  });
}
