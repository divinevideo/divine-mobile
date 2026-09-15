// ABOUTME: Widget tests for EncryptedVideoCard and its MessageBubble branch.
// ABOUTME: A kind 15 video DM renders a local blurhash placeholder and never a
// ABOUTME: network image, because fetching the encrypted thumbnail would reuse
// ABOUTME: the AES-GCM nonce.

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

    testWidgets('falls back to the unavailable pattern without a blurhash', (
      tester,
    ) async {
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
              widget.icon == DivineIconName.warningCircle,
        ),
        findsOneWidget,
      );
      expect(find.text(strings.notificationsVideoUnavailable), findsOneWidget);
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
