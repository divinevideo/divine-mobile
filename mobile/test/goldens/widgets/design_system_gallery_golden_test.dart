// ABOUTME: Image goldens for the divine_ui components the app renders most.
// ABOUTME: Run only by the dedicated `Goldens` CI job / scripts/golden.sh.
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

/// These render `divine_ui` components from the *app's* test context on
/// purpose: `divine_ui` bundles no fonts of its own, so `VineTheme`
/// typography cannot resolve inside the package's own tests. Package-local
/// goldens are tracked in #6235.
void main() {
  group('divine_ui gallery goldens', () {
    testWidgets('button types', (tester) async {
      await _pumpGallery(
        tester,
        size: const Size(360, 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            for (final type in DivineButtonType.values)
              DivineButton(label: type.name, type: type, onPressed: _noop),
          ],
        ),
      );

      await expectLater(
        find.byKey(_galleryKey),
        matchesGoldenFile('goldens/divine_button_types.png'),
      );
    }, tags: ['golden']);

    testWidgets('button sizes and disabled state', (tester) async {
      await _pumpGallery(
        tester,
        size: const Size(360, 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            for (final size in DivineButtonSize.values)
              DivineButton(label: size.name, size: size, onPressed: _noop),
            // onPressed: null is the disabled state. Pinned because #6143
            // reshaped these paddings to reach the 48dp tap target and the
            // visible chip was supposed to stay the size it was.
            const DivineButton(label: 'disabled', onPressed: null),
            const DivineButton(
              label: 'disabled secondary',
              type: DivineButtonType.secondary,
              onPressed: null,
            ),
          ],
        ),
      );

      await expectLater(
        find.byKey(_galleryKey),
        matchesGoldenFile('goldens/divine_button_sizes.png'),
      );
    }, tags: ['golden']);

    testWidgets('snackbars', (tester) async {
      await _pumpGallery(
        tester,
        size: const Size(400, 320),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            DivineSnackbarContainer(label: 'Vine saved to your profile'),
            DivineSnackbarContainer(
              label: 'Could not reach the relay',
              error: true,
            ),
            DivineSnackbarContainer(
              label: 'Removed from Literature',
              actionLabel: 'Undo',
              onActionPressed: _noop,
            ),
          ],
        ),
      );

      await expectLater(
        find.byKey(_galleryKey),
        matchesGoldenFile('goldens/divine_snackbars.png'),
      );
    }, tags: ['golden']);
  });
}

const ValueKey<String> _galleryKey = ValueKey('golden-gallery');

void _noop() {}

/// Pumps [child] at a fixed surface size and device pixel ratio, with every
/// font it uses registered before the frame that gets captured.
///
/// Size and pixel ratio are pinned rather than inherited: the golden is
/// compared byte-for-byte against a reference generated on the Ubuntu CI
/// runner, so an inherited view config would make the image depend on whose
/// machine ran it.
///
/// The font drain is the load-bearing part. `VineTheme` renders through
/// google_fonts, which resolves the bundled `assets/fonts/` files
/// asynchronously and per *variant* — so `loadAppFonts()` in
/// `flutter_test_config.dart` is not enough, and neither is warming the
/// theme's own styles, because a widget can be the first to ask for a weight
/// the theme never uses. Left alone, the first test in the isolate captures
/// Ahem and a later one captures real glyphs, which is how one golden set ends
/// up with two equally plausible-looking references (#6141). `runAsync` is
/// required: the load is real file I/O the widget tester's fake async would
/// otherwise never complete.
Future<void> _pumpGallery(
  WidgetTester tester, {
  required Widget child,
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: VineTheme.theme,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          // The surface has to live *inside* the boundary being captured —
          // a Scaffold background outside it leaves the golden transparent,
          // which renders as white and makes dark-theme foregrounds look
          // broken in review.
          child: RepaintBoundary(
            key: _galleryKey,
            child: ColoredBox(
              color: VineTheme.theme.colorScheme.surface,
              child: Padding(padding: const EdgeInsets.all(16), child: child),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.runAsync(GoogleFonts.pendingFonts);
  await tester.pumpAndSettle();
}
