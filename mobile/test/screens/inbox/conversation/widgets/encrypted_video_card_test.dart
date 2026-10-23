// ABOUTME: Widget tests for EncryptedVideoCard and its MessageBubble branch.
// ABOUTME: A kind 15 video DM renders a local blurhash placeholder and never a
// ABOUTME: network image, because fetching the encrypted thumbnail would reuse
// ABOUTME: the AES-GCM nonce.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/inbox/conversation/widgets/encrypted_video_card.dart';
import 'package:openvine/screens/inbox/conversation/widgets/message_bubble.dart';
import 'package:openvine/widgets/blurhash_display.dart';

const _blurhash = 'L6Pj0^jE.AyE_3t7t7R**0o#DgR4';

DmFileMetadata _videoMetadata({String? blurhash = _blurhash}) => DmFileMetadata(
  fileType: 'video/mp4',
  encryptionAlgorithm: 'aes-gcm',
  decryptionKey: '00' * 32,
  decryptionNonce: '00' * 12,
  fileHash: 'ab' * 32,
  dimensions: '1080x1920',
  blurhash: blurhash,
);

DmMessage _videoMessage({String? blurhash = _blurhash}) => DmMessage(
  id: 'a' * 64,
  conversationId: 'conversation',
  senderPubkey: 'b' * 64,
  content: 'https://blossom.example/encrypted',
  createdAt: 1757385263,
  giftWrapId: 'c' * 64,
  messageKind: 15,
  fileMetadata: _videoMetadata(blurhash: blurhash),
);

/// Writes a small PNG standing in for a kept frame and returns its path. The
/// engine encodes it, so this runs on the real event loop.
Future<String> _writeKeptFrame() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const Color(0xFF27C58B),
  );
  final image = await recorder.endRecording().toImage(4, 4);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final dir = Directory.systemTemp.createTempSync('encrypted_video_card_');
  final file = File('${dir.path}/frame.png')
    ..writeAsBytesSync(png!.buffer.asUint8List());
  return file.path;
}

/// The card's image of the kept frame at [path], decoded or not.
Finder _keptFrame(String path) => find.byWidgetPredicate(
  (widget) =>
      widget is Image &&
      widget.image is ResizeImage &&
      (widget.image as ResizeImage).imageProvider is FileImage &&
      ((widget.image as ResizeImage).imageProvider as FileImage).file.path ==
          path,
);

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

Widget _bubbleFrom(DmMessage message, {required bool isSent}) => _host(
  MessageBubble(
    message: message.content,
    timestamp: '2:30 PM',
    isSent: isSent,
    fileMetadata: message.fileMetadata,
  ),
);

void main() {
  final strings = AppLocalizationsEn();

  group('EncryptedVideoCard', () {
    testWidgets('renders at the shared video card geometry', (tester) async {
      await tester.pumpWidget(
        _host(
          EncryptedVideoCard(
            fileMetadata: _videoMetadata(),
            isSent: false,
          ),
        ),
      );

      final size = tester.getSize(find.byType(EncryptedVideoCard));
      expect(size.width, 248);
      expect(size.height, 350);
    });

    testWidgets('labels a clip shared from a library', (tester) async {
      await tester.pumpWidget(
        _host(
          EncryptedVideoCard(
            fileMetadata: _videoMetadata(),
            isSent: false,
            isClip: true,
          ),
        ),
      );

      expect(find.text(strings.dmClipBadge), findsOneWidget);
    });

    testWidgets(
      'draws a play icon over a blurhash preview, so it still reads as a '
      'video to tap',
      (tester) async {
        await tester.pumpWidget(
          _host(
            EncryptedVideoCard(fileMetadata: _videoMetadata(), isSent: false),
          ),
        );

        final playIcon = find.byWidgetPredicate(
          (widget) =>
              widget is DivineIcon &&
              (widget.icon == DivineIconName.play ||
                  widget.icon == DivineIconName.playCircleFill),
        );
        expect(find.byType(BlurhashDisplay), findsOneWidget);
        expect(playIcon, findsOneWidget);
        expect(
          tester.getCenter(playIcon),
          tester.getCenter(find.byType(BlurhashDisplay)),
        );
      },
    );

    testWidgets(
      'keeps the blurhash showing while the kept frame decodes, so the card '
      'never goes blank',
      (tester) async {
        const framePath = '/kept/dm_videos/owner/clip.preview.jpg';
        await tester.pumpWidget(
          _host(
            EncryptedVideoCard(
              fileMetadata: _videoMetadata(),
              isSent: false,
              framePath: framePath,
            ),
          ),
        );

        expect(find.byType(BlurhashDisplay), findsOneWidget);
        expect(_keptFrame(framePath), findsOneWidget);
      },
    );

    testWidgets(
      'draws the kept frame over the blurhash, under a play icon, once it '
      'decodes',
      (tester) async {
        await tester.runAsync(() async {
          final framePath = await _writeKeptFrame();
          addTearDown(
            () => File(framePath).parent.deleteSync(recursive: true),
          );
          await tester.pumpWidget(
            _host(
              EncryptedVideoCard(
                fileMetadata: _videoMetadata(),
                isSent: false,
                framePath: framePath,
              ),
            ),
          );
          final frame = tester.element(find.byType(Image));
          await precacheImage((frame.widget as Image).image, frame);
        });
        await tester.pump();

        // A Stack paints each child over the ones before it.
        expect(
          find
              .byWidgetPredicate(
                (widget) =>
                    widget is BlurhashDisplay ||
                    (widget is RawImage && widget.image != null) ||
                    (widget is DivineIcon &&
                        widget.icon == DivineIconName.play),
              )
              .evaluate()
              .map((element) => element.widget.runtimeType),
          orderedEquals([BlurhashDisplay, RawImage, DivineIcon]),
        );
      },
    );

    testWidgets(
      'keeps showing the blurhash when the kept frame is gone',
      (tester) async {
        final missing = '${Directory.systemTemp.path}/no_such_frame.jpg';
        await tester.runAsync(() async {
          await tester.pumpWidget(
            _host(
              EncryptedVideoCard(
                fileMetadata: _videoMetadata(),
                isSent: false,
                framePath: missing,
              ),
            ),
          );
          // The card's own provider, resized, so its own load is the one
          // waited for, and fails.
          final frame = tester.element(find.byType(Image));
          await precacheImage(
            (frame.widget as Image).image,
            frame,
            onError: (_, _) {},
          );
        });
        await tester.pump();

        expect(find.byType(BlurhashDisplay), findsOneWidget);
        // The failed frame draws nothing over it, not even a broken-image box.
        expect(find.byType(RawImage), findsNothing);
        expect(find.byType(Placeholder), findsNothing);
      },
    );

    testWidgets('does not label a plain video as a clip', (tester) async {
      await tester.pumpWidget(
        _host(
          EncryptedVideoCard(fileMetadata: _videoMetadata(), isSent: false),
        ),
      );

      expect(find.text(strings.dmClipBadge), findsNothing);
    });

    group('held back', () {
      const framePath = '/kept/dm_videos/owner/clip.preview.jpg';

      testWidgets("keeps a request's blurhash, shows no frame and asks for a "
          'tap', (tester) async {
        await tester.pumpWidget(
          _host(
            EncryptedVideoCard(
              fileMetadata: _videoMetadata(),
              isSent: false,
              framePath: framePath,
              hold: DmVideoHold.request,
            ),
          ),
        );

        expect(find.byType(BlurhashDisplay), findsOneWidget);
        expect(_keptFrame(framePath), findsNothing);
        expect(find.text(strings.dmVideoCardTapToLoad), findsOneWidget);
      });

      testWidgets("keeps a blurred card's blurhash, shows no frame and offers "
          'to play it', (tester) async {
        await tester.pumpWidget(
          _host(
            EncryptedVideoCard(
              fileMetadata: _videoMetadata(),
              isSent: false,
              framePath: framePath,
              hold: DmVideoHold.blurred,
            ),
          ),
        );

        expect(find.byType(BlurhashDisplay), findsOneWidget);
        expect(_keptFrame(framePath), findsNothing);
        expect(find.text(strings.dmVideoCardTapToWatch), findsOneWidget);
      });

      testWidgets(
        'blurs with the blurhash read from the frame when the sender sent '
        'none',
        (tester) async {
          const frameBlurhash = 'LEHV6nWB2yk8pyo0adR*.7kCMdnj';
          await tester.pumpWidget(
            _host(
              EncryptedVideoCard(
                fileMetadata: _videoMetadata(blurhash: null),
                isSent: false,
                framePath: framePath,
                hold: DmVideoHold.blurred,
                frameBlurhash: frameBlurhash,
              ),
            ),
          );

          expect(
            tester
                .widget<BlurhashDisplay>(find.byType(BlurhashDisplay))
                .blurhash,
            frameBlurhash,
          );
          expect(_keptFrame(framePath), findsNothing);
        },
      );

      testWidgets(
        'shows a placeholder, never the frame, while a blurred card has no '
        'blurhash',
        (tester) async {
          await tester.pumpWidget(
            _host(
              EncryptedVideoCard(
                fileMetadata: _videoMetadata(blurhash: null),
                isSent: false,
                framePath: framePath,
                hold: DmVideoHold.blurred,
              ),
            ),
          );

          expect(find.byType(BlurhashDisplay), findsNothing);
          expect(_keptFrame(framePath), findsNothing);
          expect(find.text(strings.dmVideoCardTapToWatch), findsOneWidget);
        },
      );

      for (final (hold, hint) in [
        (DmVideoHold.blocked, strings.dmVideoCardHiddenSenderBlocked),
        (DmVideoHold.muted, strings.dmVideoCardHiddenSenderMuted),
      ]) {
        testWidgets("hides a ${hold.name} sender's preview and says why", (
          tester,
        ) async {
          await tester.pumpWidget(
            _host(
              EncryptedVideoCard(
                fileMetadata: _videoMetadata(),
                isSent: false,
                framePath: framePath,
                hold: hold,
              ),
            ),
          );

          expect(find.byType(BlurhashDisplay), findsNothing);
          expect(_keptFrame(framePath), findsNothing);
          expect(find.text(hint), findsOneWidget);
        });
      }

      for (final hold in DmVideoHold.values) {
        testWidgets('still plays a ${hold.name} card on tap', (tester) async {
          var taps = 0;
          await tester.pumpWidget(
            _host(
              EncryptedVideoCard(
                fileMetadata: _videoMetadata(),
                isSent: false,
                framePath: framePath,
                hold: hold,
                onTap: () => taps++,
              ),
            ),
          );

          await tester.tap(find.byType(EncryptedVideoCard));

          expect(taps, 1);
        });
      }

      testWidgets('tells screen readers why there is no preview', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          _host(
            EncryptedVideoCard(
              fileMetadata: _videoMetadata(),
              isSent: false,
              hold: DmVideoHold.blocked,
              onTap: () {},
            ),
          ),
        );

        final card = tester.getSemantics(
          find.bySemanticsLabel(
            RegExp(RegExp.escape(strings.videoPlayerPlayVideo)),
          ),
        );
        expect(card.hint, strings.dmVideoCardHiddenSenderBlocked);
        semantics.dispose();
      });
    });
  });

  group('MessageBubble encrypted video branch', () {
    testWidgets(
      'renders EncryptedVideoCard and a blurhash placeholder for kind 15',
      (tester) async {
        await tester.pumpWidget(_bubbleFrom(_videoMessage(), isSent: false));
        await tester.pump();

        expect(find.byType(EncryptedVideoCard), findsOneWidget);
        expect(find.byType(BlurhashDisplay), findsOneWidget);
        expect(find.byType(Image), findsNothing);
        expect(
          find.byWidgetPredicate(
            (widget) => widget is Image && widget.image is NetworkImage,
          ),
          findsNothing,
        );
      },
    );

    testWidgets('shows the kept frame it is given', (tester) async {
      const framePath = '/kept/dm_videos/owner/clip.preview.jpg';
      await tester.pumpWidget(
        _host(
          MessageBubble(
            message: _videoMessage().content,
            timestamp: '2:30 PM',
            isSent: false,
            fileMetadata: _videoMessage().fileMetadata,
            encryptedVideoFramePath: framePath,
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(EncryptedVideoCard),
          matching: _keptFrame(framePath),
        ),
        findsOneWidget,
      );
    });

    testWidgets('never renders the encrypted file URL as text', (tester) async {
      await tester.pumpWidget(_bubbleFrom(_videoMessage(), isSent: false));
      await tester.pump();

      expect(find.textContaining('blossom.example'), findsNothing);
    });

    testWidgets('aligns left when received and right when sent', (
      tester,
    ) async {
      await tester.pumpWidget(_bubbleFrom(_videoMessage(), isSent: true));
      await tester.pump();
      expect(
        tester.widget<Align>(find.byType(Align).first).alignment,
        AlignmentDirectional.centerEnd,
      );

      await tester.pumpWidget(_bubbleFrom(_videoMessage(), isSent: false));
      await tester.pump();
      expect(
        tester.widget<Align>(find.byType(Align).first).alignment,
        AlignmentDirectional.centerStart,
      );
    });

    testWidgets(
      'shows a play placeholder, not an unavailable warning, without a '
      'blurhash',
      (tester) async {
        await tester.pumpWidget(
          _bubbleFrom(_videoMessage(blurhash: null), isSent: false),
        );
        await tester.pump();

        expect(find.byType(EncryptedVideoCard), findsOneWidget);
        expect(find.byType(BlurhashDisplay), findsNothing);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is DivineIcon &&
                widget.icon == DivineIconName.playCircleFill,
          ),
          findsOneWidget,
        );
        expect(find.text(strings.notificationsVideoUnavailable), findsNothing);
      },
    );

    testWidgets('labels the tappable card for screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          MessageBubble(
            message: _videoMessage().content,
            timestamp: '2:30 PM',
            isSent: false,
            fileMetadata: _videoMetadata(blurhash: null),
            onOpenEncryptedVideo: () {},
          ),
        ),
      );
      await tester.pump();

      expect(
        find.bySemanticsLabel(
          RegExp(RegExp.escape(strings.videoPlayerPlayVideo)),
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('passes why a preview is held back to its card', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          MessageBubble(
            message: _videoMessage().content,
            timestamp: '2:30 PM',
            isSent: false,
            fileMetadata: _videoMetadata(),
            encryptedVideoHold: DmVideoHold.request,
          ),
        ),
      );

      expect(find.text(strings.dmVideoCardTapToLoad), findsOneWidget);
    });

    testWidgets('passes the blurhash read from the frame to its card', (
      tester,
    ) async {
      const frameBlurhash = 'LEHV6nWB2yk8pyo0adR*.7kCMdnj';
      await tester.pumpWidget(
        _host(
          MessageBubble(
            message: _videoMessage().content,
            timestamp: '2:30 PM',
            isSent: false,
            fileMetadata: _videoMetadata(blurhash: null),
            encryptedVideoHold: DmVideoHold.blurred,
            encryptedVideoFrameBlurhash: frameBlurhash,
          ),
        ),
      );

      expect(
        tester.widget<BlurhashDisplay>(find.byType(BlurhashDisplay)).blurhash,
        frameBlurhash,
      );
    });

    testWidgets('forwards a card tap to onOpenEncryptedVideo', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          MessageBubble(
            message: _videoMessage().content,
            timestamp: '2:30 PM',
            isSent: false,
            fileMetadata: _videoMetadata(),
            onOpenEncryptedVideo: () => taps++,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(EncryptedVideoCard));

      expect(taps, 1);
    });

    testWidgets('ignores a non-video file attachment', (tester) async {
      final imageMessage = DmMessage(
        id: 'a' * 64,
        conversationId: 'conversation',
        senderPubkey: 'b' * 64,
        content: 'https://blossom.example/image',
        createdAt: 1757385263,
        giftWrapId: 'c' * 64,
        messageKind: 15,
        fileMetadata: DmFileMetadata(
          fileType: 'image/jpeg',
          encryptionAlgorithm: 'aes-gcm',
          decryptionKey: '00' * 32,
          decryptionNonce: '00' * 12,
          fileHash: 'ab' * 32,
        ),
      );

      await tester.pumpWidget(_bubbleFrom(imageMessage, isSent: false));
      await tester.pump();

      expect(find.byType(EncryptedVideoCard), findsNothing);
    });
  });
}
