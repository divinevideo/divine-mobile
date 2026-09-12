// ABOUTME: Tests the share-sheet wrapper that fills sharePositionOrigin.
// ABOUTME: iPad refuses a share whose anchor is empty or outside the view.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/utils/share_sheet.dart';

const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

void main() {
  late List<Map<Object?, Object?>> shareCalls;

  setUp(() {
    shareCalls = <Map<Object?, Object?>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_shareChannel, (call) async {
          if (call.method != 'share') return null;
          shareCalls.add(call.arguments as Map<Object?, Object?>);
          return 'com.apple.UIKit.activity.CopyToPasteboard';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_shareChannel, null);
  });

  Rect originOf(Map<Object?, Object?> call) => Rect.fromLTWH(
    call['originX']! as double,
    call['originY']! as double,
    call['originWidth']! as double,
    call['originHeight']! as double,
  );

  group('showShareSheet', () {
    testWidgets('anchors the share sheet on the calling widget', (
      tester,
    ) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: SizedBox(key: key, width: 120, height: 48)),
        ),
      );

      await showShareSheet(
        key.currentContext!,
        ShareParams(text: 'divine.video'),
      );

      expect(shareCalls, hasLength(1));
      final box = key.currentContext!.findRenderObject()! as RenderBox;
      expect(
        originOf(shareCalls.single),
        box.localToGlobal(Offset.zero) & box.size,
      );
    });

    testWidgets('falls back to the view when the widget has no size', (
      tester,
    ) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.shrink(key: key),
          ),
        ),
      );

      await showShareSheet(
        key.currentContext!,
        ShareParams(text: 'divine.video'),
      );

      final origin = originOf(shareCalls.single);
      expect(origin.isEmpty, isFalse);
      expect(origin, Offset.zero & MediaQuery.sizeOf(key.currentContext!));
    });

    testWidgets('clips an anchor that reaches outside the view', (
      tester,
    ) async {
      final key = GlobalKey();
      final viewSize = tester.view.physicalSize / tester.view.devicePixelRatio;
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: OverflowBox(
              alignment: Alignment.topLeft,
              maxWidth: viewSize.width * 2,
              maxHeight: viewSize.height * 2,
              child: SizedBox(
                key: key,
                width: viewSize.width * 2,
                height: viewSize.height * 2,
              ),
            ),
          ),
        ),
      );

      await showShareSheet(
        key.currentContext!,
        ShareParams(text: 'divine.video'),
      );

      final origin = originOf(shareCalls.single);
      expect(origin, Offset.zero & viewSize);
    });

    testWidgets('falls back to the view when the anchor is fully off-screen', (
      tester,
    ) async {
      final key = GlobalKey();
      final viewSize = tester.view.physicalSize / tester.view.devicePixelRatio;
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: Transform.translate(
              offset: Offset(-viewSize.width, -viewSize.height),
              child: SizedBox(key: key, width: 120, height: 48),
            ),
          ),
        ),
      );

      await showShareSheet(
        key.currentContext!,
        ShareParams(text: 'divine.video'),
      );

      // Nothing of the anchor is left after clipping, and iPad refuses an
      // empty rect exactly as firmly as a missing one — so the view has to
      // stand in rather than the zero-area intersection being passed along.
      final origin = originOf(shareCalls.single);
      expect(origin.isEmpty, isFalse);
      expect(origin, Offset.zero & viewSize);
    });

    testWidgets('keeps an anchor the caller set explicitly', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: SizedBox(key: key, width: 120, height: 48)),
        ),
      );

      await showShareSheet(
        key.currentContext!,
        ShareParams(
          text: 'divine.video',
          sharePositionOrigin: const Rect.fromLTWH(4, 8, 16, 32),
        ),
      );

      expect(originOf(shareCalls.single), const Rect.fromLTWH(4, 8, 16, 32));
    });
  });

  group('showShareSheetAtOrigin', () {
    test('forwards the anchor resolved by the caller', () async {
      await showShareSheetAtOrigin(
        ShareParams(text: 'divine.video'),
        sharePositionOrigin: const Rect.fromLTWH(1, 2, 3, 4),
      );

      expect(originOf(shareCalls.single), const Rect.fromLTWH(1, 2, 3, 4));
    });
  });

  group('shareParamsWithPositionOrigin', () {
    test('carries every ShareParams field across the copy', () {
      final thumbnail = XFile('thumbnail.png');
      final file = XFile('clip.mp4');
      final params = ShareParams(
        text: 'text',
        subject: 'subject',
        title: 'title',
        previewThumbnail: thumbnail,
        files: [file],
        fileNameOverrides: const ['renamed.mp4'],
        downloadFallbackEnabled: false,
        mailToFallbackEnabled: false,
        excludedCupertinoActivities: const [
          CupertinoActivityType.postToFacebook,
        ],
      );

      final copy = shareParamsWithPositionOrigin(
        params,
        const Rect.fromLTWH(1, 2, 3, 4),
      );

      expect(copy.text, params.text);
      expect(copy.subject, params.subject);
      expect(copy.title, params.title);
      expect(copy.previewThumbnail, same(thumbnail));
      expect(copy.files, same(params.files));
      expect(copy.fileNameOverrides, same(params.fileNameOverrides));
      expect(copy.downloadFallbackEnabled, isFalse);
      expect(copy.mailToFallbackEnabled, isFalse);
      expect(
        copy.excludedCupertinoActivities,
        same(params.excludedCupertinoActivities),
      );
      expect(copy.sharePositionOrigin, const Rect.fromLTWH(1, 2, 3, 4));
    });

    test('carries a uri, which cannot be combined with text', () {
      final copy = shareParamsWithPositionOrigin(
        ShareParams(uri: Uri.parse('https://divine.video')),
        const Rect.fromLTWH(1, 2, 3, 4),
      );

      expect(copy.uri, Uri.parse('https://divine.video'));
      expect(copy.sharePositionOrigin, const Rect.fromLTWH(1, 2, 3, 4));
    });
  });
}
