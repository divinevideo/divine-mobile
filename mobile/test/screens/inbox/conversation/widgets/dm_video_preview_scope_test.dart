// ABOUTME: Tests for DmVideoPreviewScope: which video DMs download as soon as
// ABOUTME: they show, and the kept frame reaching the bubble it builds.

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart'
    show FollowRelationship;
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/follow_relationship_provider.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/screens/inbox/conversation/widgets/dm_video_preview_scope.dart';
import 'package:openvine/services/dm_video_store.dart';

class _MockDmVideoStore extends Mock implements DmVideoStore {}

/// Stands in for the follower cache the real follow relationship watches.
final _followerCache = StateProvider<int>((ref) => 0);

const _framePath = '/kept/dm_videos/owner/clip.preview.jpg';
final String _sender = 'b' * 64;

DmMessage _videoMessage() => DmMessage(
  id: 'a' * 64,
  conversationId: 'conversation',
  senderPubkey: _sender,
  content: 'https://blossom.example/encrypted',
  createdAt: 1757385263,
  giftWrapId: 'c' * 64,
  messageKind: 15,
  fileMetadata: const DmFileMetadata(
    fileType: 'video/mp4',
    encryptionAlgorithm: 'aes-gcm',
    decryptionKey: '00',
    decryptionNonce: '00',
    fileHash: 'ab',
  ),
);

void main() {
  late _MockDmVideoStore store;
  late StreamController<String> kept;

  setUpAll(() => registerFallbackValue(_videoMessage()));

  setUp(() {
    store = _MockDmVideoStore();
    kept = StreamController<String>.broadcast();
    when(() => store.kept).thenAnswer((_) => kept.stream);
    when(
      () => store.previewFor(
        any(),
        download: any(named: 'download'),
        stillWanted: any(named: 'stillWanted'),
      ),
    ).thenAnswer((_) async => File(_framePath));
  });

  tearDown(() => kept.close());

  Widget host({
    required bool accepted,
    bool blocked = false,
    FollowRelationship relationship = FollowRelationship.none,
    List<String?>? framePaths,
  }) => ProviderScope(
    overrides: [
      dmVideoStoreProvider.overrideWithValue(store),
      followRelationshipProvider.overrideWith(
        (ref, pubkey) => Stream.value(relationship),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DmVideoPreviewScope(
        message: _videoMessage(),
        accepted: accepted,
        blocked: blocked,
        builder: (context, framePath) {
          framePaths?.add(framePath);
          return Text(framePath ?? 'no frame');
        },
      ),
    ),
  );

  group(DmVideoPreviewScope, () {
    group('download', () {
      testWidgets('downloads at once in a chat the user has posted in', (
        tester,
      ) async {
        await tester.pumpWidget(host(accepted: true));
        await tester.pump();

        verify(
          () => store.previewFor(
            any(),
            download: true,
            decode: any(named: 'decode'),
            stillWanted: any(named: 'stillWanted'),
          ),
        ).called(1);
      });

      testWidgets('downloads at once from someone the user follows', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(accepted: false, relationship: FollowRelationship.youFollow),
        );
        await tester.pump();
        await tester.pump();

        verify(
          () => store.previewFor(
            any(),
            download: true,
            decode: any(named: 'decode'),
            stillWanted: any(named: 'stillWanted'),
          ),
        ).called(1);
      });

      testWidgets(
        'waits for a tap on a request from someone the user does not follow',
        (tester) async {
          await tester.pumpWidget(
            host(accepted: false, relationship: FollowRelationship.followsYou),
          );
          await tester.pump();
          await tester.pump();

          verifyNever(
            () => store.previewFor(
              any(),
              download: true,
              decode: any(named: 'decode'),
              stillWanted: any(named: 'stillWanted'),
            ),
          );
          verify(
            () => store.previewFor(
              any(),
              download: false,
              stillWanted: any(named: 'stillWanted'),
            ),
          ).called(1);
        },
      );
    });

    group('follow state', () {
      testWidgets(
        'keeps one preview while the follow state reloads, instead of '
        'starting over',
        (tester) async {
          final relationships = <StreamController<FollowRelationship>>[];
          addTearDown(() async {
            for (final controller in relationships) {
              await controller.close();
            }
          });
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                dmVideoStoreProvider.overrideWithValue(store),
                followRelationshipProvider.overrideWith((ref, pubkey) {
                  ref.watch(_followerCache);
                  final controller = StreamController<FollowRelationship>();
                  relationships.add(controller);
                  return controller.stream;
                }),
              ],
              child: MaterialApp(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: DmVideoPreviewScope(
                  message: _videoMessage(),
                  accepted: false,
                  blocked: false,
                  builder: (context, framePath) =>
                      Text(framePath ?? 'no frame'),
                ),
              ),
            ),
          );
          relationships.single.add(FollowRelationship.youFollow);
          await tester.pump();
          await tester.pump();
          verify(
            () => store.previewFor(
              any(),
              download: true,
              decode: any(named: 'decode'),
              stillWanted: any(named: 'stillWanted'),
            ),
          ).called(1);

          // The follower cache lands, so the relationship rebuilds and has
          // not answered yet.
          ProviderScope.containerOf(
            tester.element(find.byType(DmVideoPreviewScope)),
          ).read(_followerCache.notifier).state++;
          await tester.pump();
          await tester.pump();
          relationships.last.add(FollowRelationship.youFollow);
          await tester.pump();
          await tester.pump();

          verifyNever(
            () => store.previewFor(
              any(),
              download: true,
              decode: any(named: 'decode'),
              stillWanted: any(named: 'stillWanted'),
            ),
          );
        },
      );
    });

    group('blocked senders', () {
      testWidgets(
        'never downloads by itself from a blocked or muted sender, even in a '
        'chat the user posted in or from someone they follow',
        (tester) async {
          await tester.pumpWidget(
            host(
              accepted: true,
              blocked: true,
              relationship: FollowRelationship.youFollow,
            ),
          );
          await tester.pump();
          await tester.pump();

          verifyNever(
            () => store.previewFor(
              any(),
              download: true,
              decode: any(named: 'decode'),
              stillWanted: any(named: 'stillWanted'),
            ),
          );
          verify(
            () => store.previewFor(
              any(),
              download: false,
              decode: false,
              stillWanted: any(named: 'stillWanted'),
            ),
          ).called(1);
        },
      );
    });

    group('renders', () {
      testWidgets('builds the bubble with the kept frame', (tester) async {
        final framePaths = <String?>[];
        await tester.pumpWidget(host(accepted: true, framePaths: framePaths));
        await tester.pump();

        expect(find.text(_framePath), findsOneWidget);
        expect(framePaths.first, isNull);
        expect(framePaths.last, equals(_framePath));
      });
    });
  });
}
