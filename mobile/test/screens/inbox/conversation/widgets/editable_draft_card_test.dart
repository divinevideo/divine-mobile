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
