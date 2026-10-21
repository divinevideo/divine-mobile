// ABOUTME: Tests for DmVideoPreviewScope: which video DMs download as soon as
// ABOUTME: they show, which hold back their preview and why, and the frame.

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
import 'package:openvine/screens/inbox/conversation/widgets/encrypted_video_card.dart'
    show DmVideoHold;
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
        stillWanted: any(named: 'stillWanted'),
      ),
    ).thenAnswer((_) async => File(_framePath));
  });

  tearDown(() => kept.close());

  Widget host({
    required bool accepted,
    bool blocked = false,
    bool muted = false,
    Stream<FollowRelationship>? relationship,
    List<(String?, DmVideoHold?)>? built,
  }) => ProviderScope(
    overrides: [
      dmVideoStoreProvider.overrideWithValue(store),
      followRelationshipProvider.overrideWith(
        (ref, pubkey) => relationship ?? Stream.value(FollowRelationship.none),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DmVideoPreviewScope(
        message: _videoMessage(),
        accepted: accepted,
        blocked: blocked,
        muted: muted,
        builder: (context, framePath, hold) {
          built?.add((framePath, hold));
          return Text('${framePath ?? 'no frame'} ${hold?.name ?? 'shown'}');
        },
      ),
    ),
  );

  void expectNoStoreRead() => verifyNever(
    () => store.previewFor(
      any(),
      stillWanted: any(named: 'stillWanted'),
    ),
  );

  void expectDownloadedOnce() => verify(
    () => store.previewFor(
      any(),
      stillWanted: any(named: 'stillWanted'),
    ),
  ).called(1);

  group(DmVideoPreviewScope, () {
    group('trusted', () {
      testWidgets('downloads at once in a chat the user has posted in', (
        tester,
      ) async {
        final built = <(String?, DmVideoHold?)>[];
        await tester.pumpWidget(host(accepted: true, built: built));
        await tester.pump();

        expectDownloadedOnce();
        expect(built.map((entry) => entry.$2), everyElement(isNull));
      });

      testWidgets('downloads at once from someone the user follows', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(
            accepted: false,
            relationship: Stream.value(FollowRelationship.youFollow),
          ),
        );
        await tester.pump();
        await tester.pump();

        expectDownloadedOnce();
      });
    });

    group('held back', () {
      testWidgets('holds back a request: no download, no frame, and asks for a '
          'tap', (tester) async {
        final built = <(String?, DmVideoHold?)>[];
        await tester.pumpWidget(
          host(
            accepted: false,
            relationship: Stream.value(FollowRelationship.followsYou),
            built: built,
          ),
        );
        await tester.pump();
        await tester.pump();

        expectNoStoreRead();
        expect(built.last, (null, DmVideoHold.request));
      });

      for (final (name, blocked, muted, hold) in [
        ('blocked', true, false, DmVideoHold.blocked),
        ('muted', false, true, DmVideoHold.muted),
      ]) {
        testWidgets('holds back a $name sender, even in a chat the user '
            'posted in and from someone they follow', (tester) async {
          final built = <(String?, DmVideoHold?)>[];
          await tester.pumpWidget(
            host(
              accepted: true,
              blocked: blocked,
              muted: muted,
              relationship: Stream.value(FollowRelationship.youFollow),
              built: built,
            ),
          );
          await tester.pump();
          await tester.pump();

          expectNoStoreRead();
          expect(built.last, (null, hold));
        });
      }

      testWidgets('never shows a frame read before the sender was blocked', (
        tester,
      ) async {
        when(() => store.knownPreviewPathFor(any())).thenReturn(_framePath);
        final built = <(String?, DmVideoHold?)>[];
        await tester.pumpWidget(
          host(accepted: true, blocked: true, built: built),
        );
        await tester.pump();

        expect(built, everyElement((null, DmVideoHold.blocked)));
      });

      testWidgets('neither downloads nor says why until it knows whether the '
          'user follows the sender', (tester) async {
        final relationship = StreamController<FollowRelationship>();
        addTearDown(relationship.close);
        final built = <(String?, DmVideoHold?)>[];
        await tester.pumpWidget(
          host(
            accepted: false,
            relationship: relationship.stream,
            built: built,
          ),
        );
        await tester.pump();

        expectNoStoreRead();
        expect(built, everyElement((null, null)));
      });
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
                  muted: false,
                  builder: (context, framePath, hold) =>
                      Text(framePath ?? 'no frame'),
                ),
              ),
            ),
          );
          relationships.single.add(FollowRelationship.youFollow);
          await tester.pump();
          await tester.pump();
          expectDownloadedOnce();

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

          expectNoStoreRead();
        },
      );
    });

    group('blocked later', () {
      testWidgets('drops the frame once the sender is blocked while it shows', (
        tester,
      ) async {
        final blocked = ValueNotifier(false);
        addTearDown(blocked.dispose);
        final built = <(String?, DmVideoHold?)>[];
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dmVideoStoreProvider.overrideWithValue(store),
              followRelationshipProvider.overrideWith(
                (ref, pubkey) => Stream.value(FollowRelationship.none),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ValueListenableBuilder<bool>(
                valueListenable: blocked,
                builder: (context, isBlocked, _) => DmVideoPreviewScope(
                  message: _videoMessage(),
                  accepted: true,
                  blocked: isBlocked,
                  muted: false,
                  builder: (context, framePath, hold) {
                    built.add((framePath, hold));
                    return Text(framePath ?? 'no frame');
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(built.last, (_framePath, null));

        blocked.value = true;
        await tester.pump();

        expect(built.last, (null, DmVideoHold.blocked));
      });
    });

    group('renders', () {
      testWidgets('builds the bubble with the kept frame', (tester) async {
        final built = <(String?, DmVideoHold?)>[];
        await tester.pumpWidget(host(accepted: true, built: built));
        await tester.pump();

        expect(find.text('$_framePath shown'), findsOneWidget);
        expect(built.first, (null, null));
        expect(built.last, (_framePath, null));
      });
    });
  });
}
