import 'dart:async';
import 'dart:typed_data';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/video_publish/video_publish_provider_state.dart';
import 'package:openvine/providers/draft_transfer_provider.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/inbox/conversation/widgets/editable_draft_card.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
import 'package:openvine/services/dm_video_decryptor.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/draft_transfer_service.dart';
import 'package:openvine/widgets/blurhash_display.dart';

import '../../../../helpers/test_provider_overrides.dart';

const _sender =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _recipient =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

class _Session extends NostrSession {
  @override
  NostrSessionReadiness build() =>
      const NostrSessionReadiness.identityKnown(pubkey: _recipient);
}

class _MockStorage extends Mock implements DraftStorageService {}

class _MockBlocklist extends Mock implements ContentBlocklistRepository {}

class _MockDecryptor extends Mock implements DmVideoDecryptor {}

class _MockTransfer extends Mock implements DraftTransferService {}

class _Publisher extends VideoPublishNotifier {
  @override
  VideoPublishProviderState build() => const VideoPublishProviderState();

  @override
  Future<void> clearAll({bool keepAutosavedDraft = false}) async {}
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final message = DmMessage(
    id: '1' * 64,
    conversationId: 'conversation',
    senderPubkey: _sender,
    content: 'https://media.example.test/encrypted',
    createdAt: 1,
    giftWrapId: '2' * 64,
    messageKind: 15,
  );

  setUpAll(() {
    registerFallbackValue(() => true);
    registerFallbackValue(() async => Uint8List(0));
  });

  group(EditableDraftCard, () {
    group('renders', () {
      const blurhash = 'LEHV6nWB2yk8pyo0adR*.7kCMdnj';
      DmMessage sharedDraft({String? title, String? cover}) => DmMessage(
        id: '3' * 64,
        conversationId: 'conversation',
        senderPubkey: _sender,
        content: 'https://media.example.test/encrypted',
        createdAt: 1,
        giftWrapId: '4' * 64,
        messageKind: 15,
        tags: [
          if (title != null) ['title', title],
        ],
        fileMetadata: DmFileMetadata(
          fileType: DmFileMetadata.editableDraftMimeType,
          encryptionAlgorithm: 'aes-gcm',
          decryptionKey: 'a' * 64,
          decryptionNonce: 'b' * 24,
          fileHash: 'c' * 64,
          blurhash: cover,
        ),
      );

      Future<void> pumpCard(
        WidgetTester tester,
        DmMessage message, {
        bool showPreview = true,
      }) => tester.pumpWidget(
        testMaterialApp(
          home: Scaffold(
            body: EditableDraftCard(
              message: message,
              canOpen: false,
              showPreview: showPreview,
            ),
          ),
        ),
      );

      testWidgets("the draft's title and cover", (tester) async {
        await pumpCard(
          tester,
          sharedDraft(title: 'Beach cut', cover: blurhash),
        );

        expect(find.text(l10n.dmSharedDraft), findsOneWidget);
        expect(find.text('Beach cut'), findsOneWidget);
        expect(
          tester.widget<BlurhashDisplay>(find.byType(BlurhashDisplay)).blurhash,
          blurhash,
        );
      });

      testWidgets('only the label for an untitled draft without a cover', (
        tester,
      ) async {
        await pumpCard(tester, sharedDraft());

        expect(find.text(l10n.dmSharedDraft), findsOneWidget);
        expect(find.byType(BlurhashDisplay), findsNothing);
      });

      testWidgets('neither title nor cover when the preview is held back', (
        tester,
      ) async {
        await pumpCard(
          tester,
          sharedDraft(title: 'Beach cut', cover: blurhash),
          showPreview: false,
        );

        expect(find.text(l10n.dmSharedDraft), findsOneWidget);
        expect(find.text('Beach cut'), findsNothing);
        expect(find.byType(BlurhashDisplay), findsNothing);
      });
    });

    group('navigation', () {
      for (final leaveChat in [false, true]) {
        testWidgets(
          leaveChat
              ? 'keeps the next page open when an import finishes in the background'
              : 'opens the imported draft in the normal draft editor route',
          (tester) async {
            final storage = _MockStorage();
            final importer = _MockTransfer();
            final blocklist = _MockBlocklist();
            when(() => storage.ownerPubkey).thenReturn(_recipient);
            when(() => blocklist.isBlocked(_sender)).thenReturn(false);

            final draft = DivineVideoDraft.create(
              id: 'imported-draft',
              clips: [],
              title: 'Received project',
              description: '',
              hashtags: {},
              selectedApproach: 'camera',
            );
            final imported = Completer<DivineVideoDraft>();
            when(
              () => importer.importDraft(
                messageId: message.id,
                senderPubkey: _sender,
                storage: storage,
                download: any(named: 'download'),
                stillWanted: any(named: 'stillWanted'),
              ),
            ).thenAnswer((_) => imported.future);

            String? editorOrigin;
            final router = GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) => Scaffold(
                    body: EditableDraftCard(message: message, canOpen: true),
                  ),
                ),
                GoRoute(
                  path: '/profile',
                  builder: (_, _) => const Scaffold(body: Text('Profile')),
                ),
                GoRoute(
                  path: VideoEditorScreen.draftPathWithId,
                  builder: (_, state) {
                    editorOrigin = state.uri.queryParameters['from'];
                    return Scaffold(
                      body: Text(state.pathParameters['draftId']!),
                    );
                  },
                ),
              ],
            );
            addTearDown(router.dispose);

            await tester.pumpWidget(
              testProviderScope(
                mockAuthService: createMockAuthService(
                  currentPublicKeyHex: _recipient,
                ),
                additionalOverrides: [
                  nostrSessionProvider.overrideWith(_Session.new),
                  draftStorageServiceProvider.overrideWithValue(storage),
                  dmVideoDecryptorProvider.overrideWithValue(_MockDecryptor()),
                  draftTransferServiceProvider.overrideWithValue(importer),
                  contentBlocklistRepositoryProvider.overrideWithValue(
                    blocklist,
                  ),
                  videoPublishProvider.overrideWith(_Publisher.new),
                ],
                child: MaterialApp.router(
                  routerConfig: router,
                  theme: VineTheme.theme,
                  localizationsDelegates: appLocalizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                ),
              ),
            );

            verifyZeroInteractions(importer);
            await tester.tap(find.text(l10n.dmOpenDraft));
            await tester.pump();
            if (leaveChat) {
              unawaited(router.push<void>('/profile'));
              await tester.pumpAndSettle();
            }
            imported.complete(draft);
            await tester.pumpAndSettle();
            if (leaveChat) {
              expect(find.text('Profile'), findsOneWidget);
              expect(editorOrigin, isNull);
            } else {
              expect(find.text(draft.id), findsOneWidget);
              expect(editorOrigin, VideoEditorScreen.libraryOrigin);
            }
          },
        );
      }
    });
  });
}
