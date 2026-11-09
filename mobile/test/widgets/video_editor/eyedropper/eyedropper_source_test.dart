// ABOUTME: Tests for EyedropperSources and EyedropperSourceRegion: which video
// ABOUTME: view a color sheet picks from, and the eyedropper screen a pick opens.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/eyedropper/color_eyedropper.dart';
import 'package:openvine/widgets/video_editor/eyedropper/eyedropper_snapshot.dart';
import 'package:openvine/widgets/video_editor/eyedropper/eyedropper_source.dart';

const _magenta = Color(0xFFC000C0);

void main() {
  group(EyedropperSources, () {
    late GlobalKey<NavigatorState> navigatorKey;

    setUp(() => navigatorKey = GlobalKey<NavigatorState>());

    Future<void> pump(
      WidgetTester tester,
      Widget home, {
      bool withHost = true,
    }) async {
      final app = MaterialApp(
        navigatorKey: navigatorKey,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: home),
      );
      await tester.pumpWidget(withHost ? EyedropperSources(child: app) : app);
    }

    EyedropperSource? visible() =>
        EyedropperSources.visibleOf(navigatorKey.currentContext!);

    EyedropperSource regionAt(WidgetTester tester, int index) =>
        tester.state(find.byType(EyedropperSourceRegion).at(index))
            as EyedropperSource;

    group('visibleOf', () {
      testWidgets('is the newest region on screen', (tester) async {
        await pump(
          tester,
          const Column(
            children: [
              EyedropperSourceRegion(child: SizedBox(width: 50, height: 50)),
              EyedropperSourceRegion(child: SizedBox(width: 50, height: 50)),
            ],
          ),
        );

        expect(visible(), same(regionAt(tester, 1)));
      });

      testWidgets('skips a region an opaque screen covers', (tester) async {
        await pump(
          tester,
          const EyedropperSourceRegion(child: SizedBox(width: 50, height: 50)),
        );
        expect(visible(), same(regionAt(tester, 0)));

        navigatorKey.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => const Scaffold()),
        );
        await tester.pumpAndSettle();

        expect(visible(), isNull);
      });

      testWidgets('forgets a region once it is gone', (tester) async {
        await pump(
          tester,
          const EyedropperSourceRegion(child: SizedBox(width: 50, height: 50)),
        );
        expect(visible(), isNotNull);

        await pump(tester, const SizedBox(width: 50, height: 50));

        expect(visible(), isNull);
      });

      testWidgets('is nothing without the registry above', (tester) async {
        await pump(
          tester,
          const EyedropperSourceRegion(child: SizedBox(width: 50, height: 50)),
          withHost: false,
        );

        expect(visible(), isNull);
      });
    });

    group('pick', () {
      /// A region whose capture is a single magenta pixel.
      Future<void> pumpMagentaRegion(WidgetTester tester) async {
        final image = await tester.runAsync(
          () => createTestImage(cache: false),
        );
        await pump(
          tester,
          Center(
            child: EyedropperSourceRegion(
              capture: (boundary, {required pixelRatio}) async =>
                  EyedropperSnapshot(
                    image: image!,
                    pixels: ByteData(4)..setUint32(0, 0xC000C0FF),
                    size: boundary.size,
                  ),
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        );
      }

      testWidgets('opens the eyedropper and resolves with the pick', (
        tester,
      ) async {
        await pumpMagentaRegion(tester);
        Color? picked;
        unawaited(
          visible()!
              .pick(navigatorKey.currentContext!)
              .then((color) => picked = color),
        );
        await tester.pump();
        await tester.pump();
        expect(find.byType(ColorEyedropper), findsOneWidget);

        await tester.tapAt(
          tester.getCenter(find.byType(EyedropperSourceRegion)),
        );
        await tester.pump();

        expect(picked, _magenta);
        expect(find.byType(ColorEyedropper), findsNothing);
      });

      testWidgets('resolves with no color when back closes it', (tester) async {
        await pumpMagentaRegion(tester);
        var resolved = false;
        Color? picked = _magenta;
        unawaited(
          visible()!.pick(navigatorKey.currentContext!).then((color) {
            resolved = true;
            picked = color;
          }),
        );
        await tester.pump();
        await tester.pump();

        await tester.binding.handlePopRoute();
        await tester.pump();

        expect(resolved, isTrue);
        expect(picked, isNull);
        expect(find.byType(ColorEyedropper), findsNothing);
        // The region is still there to pick from again.
        expect(visible(), isNotNull);
      });
    });
  });
}
