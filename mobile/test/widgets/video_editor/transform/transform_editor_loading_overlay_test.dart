// ABOUTME: Pins the transform editor's loading overlay against MaterialApp's
// ABOUTME: unstyled-text fallback, which the editor's OverlayEntry exposes it to.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_editor/transform/transform_editor_configs.dart';

void main() {
  group(TransformEditorLoadingOverlay, () {
    const label = 'Transforming your frame';

    /// Mounts the overlay the way pro_image_editor does: as an `OverlayEntry`
    /// on the app's `Navigator`, with no route `Material` above it.
    Future<void> pumpInOverlay(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      );

      final overlay = tester.state<OverlayState>(find.byType(Overlay));
      overlay.insert(
        OverlayEntry(
          builder: (_) => const TransformEditorLoadingOverlay(label: label),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders the label and a spinner', (tester) async {
      await pumpInOverlay(tester);

      expect(find.text(label), findsOneWidget);
      expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
    });

    testWidgets('does not inherit the unstyled-text error decoration', (
      tester,
    ) async {
      // Without a Material ancestor the label merges with MaterialApp's
      // fallback style — red monospace under a yellow double underline — which
      // is exactly what shipped as "the processing text is yellow".
      await pumpInOverlay(tester);

      final rendered = tester.widget<RichText>(
        find.descendant(
          of: find.text(label),
          matching: find.byType(RichText),
        ),
      );
      final style = rendered.text.style!;

      expect(style.decoration ?? TextDecoration.none, TextDecoration.none);
      expect(style.color, VineTheme.onSurface);
    });
  });
}
