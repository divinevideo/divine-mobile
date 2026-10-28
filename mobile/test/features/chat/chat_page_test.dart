import 'dart:async';

import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/chat/chat_cubit.dart';
import 'package:openvine/features/chat/chat_mention_providers.dart';
import 'package:openvine/features/chat/chat_mention_repository.dart';
import 'package:openvine/features/chat/chat_page.dart';
import 'package:openvine/features/chat/chat_screen.dart';
import 'package:openvine/features/chat/concord_session.dart';
import 'package:openvine/features/chat/room_activity_provider.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';

class _Relay extends Mock implements RelayGateway {}

class _Cipher extends Mock implements StreamCipher {}

class _Mentions extends Mock implements ChatMentionRepository {}

/// A relay with no traffic, for tests that only need a room to open.
class _SilentRelay implements RelayGateway {
  @override
  Stream<Map<String, dynamic>> subscribe(Map<String, dynamic> filter) =>
      const Stream.empty();
  @override
  Future<void> publish(Map<String, dynamic> event) async {}
}

class _RoomRelay implements RelayGateway {
  _RoomRelay() {
    wraps.onCancel = cancelled.complete;
  }
  final cancelled = Completer<void>.sync();
  final wraps = StreamController<Map<String, dynamic>>();
  @override
  Stream<Map<String, dynamic>> subscribe(Map<String, dynamic> filter) =>
      wraps.stream;
  @override
  Future<void> publish(Map<String, dynamic> event) async {}
}

class _Auth extends Fake implements AuthService {
  _Auth(String pubkey, {this.isAuthenticated = true})
    : currentPublicKeyHex = pubkey,
      currentIdentity = PubkeyOnlyNostrIdentity(pubkey: pubkey);
  @override
  final bool isAuthenticated;
  @override
  final String? currentPublicKeyHex;
  @override
  final NostrIdentity? currentIdentity;
  @override
  AuthState get authState =>
      isAuthenticated ? AuthState.authenticated : AuthState.unauthenticated;
  @override
  Stream<AuthState> get authStateStream => const Stream.empty();
}

void main() {
  group('selectChatRoom', () {
    late ChatCubit cubit;
    setUp(() {
      cubit = ChatCubit(
        ConcordRepository(
          relay: _Relay(),
          store: InMemoryConcordStore('a' * 64),
          cipher: _Cipher(),
        ),
      );
    });
    tearDown(() => cubit.close());

    test('opens the requested channel instead of the default', () {
      expect(
        selectChatRoom(
          cubit,
          communityId: 'community-test',
          channelId: 'introductions',
        ),
        isTrue,
      );
      expect(cubit.state.selectedChannelId, 'introductions');
    });
    test('rejects incomplete and unknown room coordinates', () {
      expect(selectChatRoom(cubit, channelId: 'general'), isFalse);
      expect(
        selectChatRoom(cubit, communityId: 'unknown', channelId: 'general'),
        isFalse,
      );
      expect(
        selectChatRoom(
          cubit,
          communityId: 'community-test',
          channelId: 'unknown',
        ),
        isFalse,
      );
      expect(cubit.state.selectedChannelId, 'general');
    });
    test('the base route opens the catalog default', () {
      expect(selectChatRoom(cubit), isTrue);
      expect(cubit.state.selectedChannelId, 'general');
    });
  });

  group(ChatPage, () {
    late AppDatabase database;

    setUp(() => database = AppDatabase.test(NativeDatabase.memory()));
    tearDown(() => database.close());

    testWidgets(
      'reuses the inbox session and keeps it alive after leaving a room',
      (tester) async {
        late _RoomRelay relay;
        late RoomActivityRepository activity;
        await tester.runAsync(() async {
          relay = _RoomRelay();
          final store = InMemoryConcordStore('a' * 64);
          final key = pocStreamKeyFor('general');
          final repository = ConcordRepository(
            relay: relay,
            store: store,
            cipher: _Cipher(),
            sealedTransport: SealedChatTransport(
              relay: relay,
              signer: (_) async => throw StateError('unused'),
            ),
          );
          activity = RoomActivityRepository(
            ownPubkey: 'a' * 64,
            channels: [
              RoomActivityChannel(
                channelId: pocChannelIdFor('general'),
                repository: repository,
                store: store,
                streamSeedHex: key.seedHex,
                streamPubkey: key.pubkey,
              ),
            ],
          );
          await activity.start();
        });
        addTearDown(() async {
          await tester.runAsync(activity.close);
          await relay.wraps.close();
        });
        expect(relay.wraps.hasListener, isTrue);
        final container = ProviderContainer(
          overrides: [
            authServiceProvider.overrideWithValue(_Auth('a' * 64)),
            databaseProvider.overrideWithValue(database),
            featureFlagStateProvider.overrideWithValue({
              FeatureFlag.concordChat: true,
            }),
            isDmRestrictedProvider.overrideWithValue(false),
            roomActivityRepositoryProvider.overrideWithValue(activity),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ChatPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ChatScreen), findsOneWidget);
        expect(relay.cancelled.isCompleted, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(relay.wraps.hasListener, isTrue);
        await tester.runAsync(activity.close);
      },
    );

    testWidgets('closes a running room when its account loses access', (
      tester,
    ) async {
      final relay = _RoomRelay();
      addTearDown(relay.wraps.close);
      final flags = StateProvider((ref) => true);
      final restricted = StateProvider((ref) => false);
      final container = ProviderContainer(
        overrides: [
          chatMentionRepositoryProvider.overrideWithValue(null),
          authServiceProvider.overrideWithValue(_Auth('a' * 64)),
          databaseProvider.overrideWithValue(database),
          isFeatureEnabledProvider(FeatureFlag.concordChat).overrideWith(
            (ref) => ref.watch(flags),
          ),
          isDmRestrictedProvider.overrideWith((ref) => ref.watch(restricted)),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ChatPage(
              repositoryBuilder:
                  ({required pubkey, required signer, required store}) =>
                      ConcordRepository(
                        relay: relay,
                        store: store,
                        cipher: _Cipher(),
                        sealedTransport: SealedChatTransport(
                          relay: relay,
                          signer: (_) async =>
                              throw StateError('unused signer'),
                        ),
                      ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(relay.wraps.hasListener, isTrue);
      container.read(restricted.notifier).state = true;
      await tester.pumpAndSettle();
      expect(find.byType(ChatScreen), findsNothing);
      await tester.runAsync(() => relay.cancelled.future);
      expect(relay.wraps.hasListener, isFalse);
    });

    List<Override> overrides({
      required AuthService auth,
      bool enabled = true,
      bool restricted = false,
    }) => [
      authServiceProvider.overrideWithValue(auth),
      databaseProvider.overrideWithValue(database),
      featureFlagStateProvider.overrideWithValue({
        FeatureFlag.concordChat: enabled,
      }),
      isDmRestrictedProvider.overrideWithValue(restricted),
    ];

    Future<ProviderContainer> pumpPage(
      WidgetTester tester, {
      AuthService? auth,
      bool enabled = true,
      bool restricted = false,
    }) async {
      final container = ProviderContainer(
        overrides: overrides(
          auth: auth ?? _Auth('a' * 64),
          enabled: enabled,
          restricted: restricted,
        ),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ChatPage(),
          ),
        ),
      );
      return container;
    }

    testWidgets('shows no room when the chat flag is off', (tester) async {
      await pumpPage(tester, enabled: false);
      expect(find.byType(ChatScreen), findsNothing);
    });

    testWidgets('shows no room to a messaging-restricted account', (
      tester,
    ) async {
      await pumpPage(tester, restricted: true);
      expect(find.byType(ChatScreen), findsNothing);
    });

    testWidgets('shows no room once the account is signed out', (
      tester,
    ) async {
      await pumpPage(tester, auth: _Auth('a' * 64, isAuthenticated: false));
      expect(find.byType(ChatScreen), findsNothing);
    });

    group('mention enrollment', () {
      late _Mentions mentions;

      setUp(() {
        mentions = _Mentions();
        when(() => mentions.enroll(any())).thenAnswer((_) async {});
      });

      Future<void> pumpRoom(
        WidgetTester tester, {
        String? communityId,
        String? channelId,
      }) async {
        final container = ProviderContainer(
          overrides: [
            ...overrides(auth: _Auth('a' * 64)),
            chatMentionRepositoryProvider.overrideWithValue(mentions),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ChatPage(
                communityId: communityId,
                channelId: channelId,
                repositoryBuilder:
                    ({required pubkey, required signer, required store}) =>
                        ConcordRepository(
                          relay: _SilentRelay(),
                          store: store,
                          cipher: _Cipher(),
                        ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      testWidgets('enrolls the room the route opened', (tester) async {
        await pumpRoom(
          tester,
          communityId: 'community-test',
          channelId: 'introductions',
        );
        expect(find.byType(ChatScreen), findsOneWidget);
        verify(() => mentions.enroll('introductions')).called(1);
      });

      testWidgets('enrolls the default room when the route names none', (
        tester,
      ) async {
        await pumpRoom(tester);
        verify(() => mentions.enroll('general')).called(1);
      });

      testWidgets('does not enroll a room the route rejects', (tester) async {
        await pumpRoom(tester, communityId: 'unknown', channelId: 'general');
        expect(find.byType(ChatScreen), findsNothing);
        verifyNever(() => mentions.enroll(any()));
      });

      testWidgets('does not enroll again when the page rebuilds', (
        tester,
      ) async {
        await pumpRoom(
          tester,
          channelId: 'general',
          communityId: 'community-test',
        );
        tester.element(find.byType(ChatPage)).markNeedsBuild();
        await tester.pump();
        verify(() => mentions.enroll('general')).called(1);
      });
    });
  });
}
