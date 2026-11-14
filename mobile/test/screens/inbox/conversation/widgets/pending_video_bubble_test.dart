// ABOUTME: Widget tests for PendingVideoBubble: one per outgoing video phase,
// ABOUTME: the frame or placeholder, the failure actions and the semantics.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/inbox/conversation/widgets/pending_video_bubble.dart';
import 'package:openvine/services/video_dm_outbox.dart';

OutgoingVideoDm _entry({
  OutgoingVideoDmPhase phase = OutgoingVideoDmPhase.queued,
  double? uploadProgress,
  OutgoingVideoDmFailure? failure,
  Uint8List? frame,
}) => OutgoingVideoDm(
  id: 'entry',
  conversationId: 'conversation',
  recipientPubkey: 'b' * 64,
  localPath: '/video.mp4',
  requestedAt: DateTime.utc(2026, 11, 13),
  phase: phase,
  uploadProgress: uploadProgress,
  failure: failure,
  frame: frame,
);

Widget _host(
  OutgoingVideoDm entry, {
  VoidCallback? onRetry,
  VoidCallback? onRemove,
}) => MaterialApp(
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: PendingVideoBubble(
      entry: entry,
      onRetry: onRetry ?? () {},
      onRemove: onRemove ?? () {},
    ),
  ),
);

Future<Uint8List> _pngBytes() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const Color(0xFF27C58B),
  );
  final image = await recorder.endRecording().toImage(4, 4);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return png!.buffer.asUint8List();
}

DivineCircularProgressIndicator _ring(WidgetTester tester) =>
    tester.widget<DivineCircularProgressIndicator>(
      find.byType(DivineCircularProgressIndicator),
    );

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(PendingVideoBubble, () {
    group('in flight', () {
      testWidgets('queued shows an indeterminate ring and Waiting', (
        tester,
      ) async {
        await tester.pumpWidget(_host(_entry()));

        expect(find.text(l10n.dmPendingVideoWaiting), findsOneWidget);
        expect(_ring(tester).value, isNull);
      });

      for (final phase in [
        OutgoingVideoDmPhase.checking,
        OutgoingVideoDmPhase.encrypting,
      ]) {
        testWidgets('$phase shows Preparing', (tester) async {
          await tester.pumpWidget(_host(_entry(phase: phase)));

          expect(find.text(l10n.dmPendingVideoPreparing), findsOneWidget);
          expect(_ring(tester).value, isNull);
        });
      }

      testWidgets('uploading shows a determinate ring and the percent', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            _entry(
              phase: OutgoingVideoDmPhase.uploading,
              uploadProgress: 0.42,
            ),
          ),
        );

        expect(find.text(l10n.dmPendingVideoUploading(42)), findsOneWidget);
        expect(_ring(tester).value, equals(0.42));
      });

      testWidgets('uploading without progress yet reads 0 percent', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(_entry(phase: OutgoingVideoDmPhase.uploading)),
        );

        expect(find.text(l10n.dmPendingVideoUploading(0)), findsOneWidget);
      });

      testWidgets('publishing shows Sending', (tester) async {
        await tester.pumpWidget(
          _host(_entry(phase: OutgoingVideoDmPhase.publishing)),
        );

        expect(find.text(l10n.dmPendingVideoSending), findsOneWidget);
      });
    });

    group('preview', () {
      testWidgets('shows the frame when there is one', (tester) async {
        final bytes = await tester.runAsync(_pngBytes);
        await tester.pumpWidget(_host(_entry(frame: bytes)));

        expect(find.byType(Image), findsOneWidget);
        expect(find.byType(DivineIcon), findsNothing);
      });

      testWidgets('shows the placeholder without a frame', (tester) async {
        await tester.pumpWidget(_host(_entry()));

        expect(find.byType(Image), findsNothing);
        expect(find.byType(DivineIcon), findsOneWidget);
      });
    });

    group('failed', () {
      testWidgets('a retryable failure offers Retry and Remove', (
        tester,
      ) async {
        var retried = 0;
        var removed = 0;
        await tester.pumpWidget(
          _host(
            _entry(
              phase: OutgoingVideoDmPhase.failed,
              failure: OutgoingVideoDmFailure.failed,
            ),
            onRetry: () => retried++,
            onRemove: () => removed++,
          ),
        );

        expect(find.text(l10n.dmVideoSendFailed), findsOneWidget);
        expect(find.byType(DivineCircularProgressIndicator), findsNothing);

        await tester.tap(find.text(l10n.commonRetry));
        expect(retried, equals(1));
        expect(removed, equals(0));

        await tester.tap(find.text(l10n.dmPendingVideoRemove));
        expect(removed, equals(1));
      });

      testWidgets('too large offers Remove only, with the size limit', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            _entry(
              phase: OutgoingVideoDmPhase.failed,
              failure: OutgoingVideoDmFailure.tooLarge,
            ),
          ),
        );

        expect(
          find.text(l10n.dmVideoTooLarge('$videoDmMaxMegabytes')),
          findsOneWidget,
        );
        expect(find.text(l10n.commonRetry), findsNothing);
        expect(find.text(l10n.dmPendingVideoRemove), findsOneWidget);
      });

      testWidgets('an unverified clip offers Remove only', (tester) async {
        await tester.pumpWidget(
          _host(
            _entry(
              phase: OutgoingVideoDmPhase.failed,
              failure: OutgoingVideoDmFailure.clipNotVerified,
            ),
          ),
        );

        expect(find.text(l10n.dmClipSendNotVerified), findsOneWidget);
        expect(find.text(l10n.commonRetry), findsNothing);
        expect(find.text(l10n.dmPendingVideoRemove), findsOneWidget);
      });
    });

    group('semantics', () {
      testWidgets('uploading merges into one label with the percent', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _host(
            _entry(
              phase: OutgoingVideoDmPhase.uploading,
              uploadProgress: 0.42,
            ),
          ),
        );

        expect(
          find.bySemanticsLabel(l10n.dmPendingVideoSemantics(42)),
          findsOneWidget,
        );
        handle.dispose();
      });

      testWidgets('a non-uploading phase is labelled by its status line', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _host(_entry(phase: OutgoingVideoDmPhase.encrypting)),
        );

        expect(
          find.bySemanticsLabel(l10n.dmPendingVideoPreparing),
          findsOneWidget,
        );
        handle.dispose();
      });

      testWidgets('a failed video is labelled as failed', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _host(
            _entry(
              phase: OutgoingVideoDmPhase.failed,
              failure: OutgoingVideoDmFailure.failed,
            ),
          ),
        );

        expect(
          find.bySemanticsLabel(l10n.dmPendingVideoFailedSemantics),
          findsOneWidget,
        );
        handle.dispose();
      });
    });
  });
}
