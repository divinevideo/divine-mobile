import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/chat/chat_cubit.dart';
import 'package:openvine/features/chat/chat_page.dart';
import 'package:openvine/features/chat/chat_screen.dart';
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
  });
}
