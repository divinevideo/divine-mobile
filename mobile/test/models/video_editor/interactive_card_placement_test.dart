// ABOUTME: Tests where a poll, quiz or slider may stand on a video: above the
// ABOUTME: other layers, and moved or shrunk into the part the feed leaves clear.

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/models/video_editor/interactive_card_placement.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

WidgetLayer _layer(String id, {bool poll = false}) {
  final meta = poll
      ? const SocialStickerData(
          kind: SocialStickerKind.poll,
          pollQuestion: 'Which one?',
          pollOptions: ['Red', 'Blue'],
        ).toMeta()
      : const SocialStickerData(
          kind: SocialStickerKind.hashtag,
          hashtag: 'summer',
        ).toMeta();
  return WidgetLayer(
    id: id,
    widget: const SizedBox(),
    meta: meta,
    exportConfigs: WidgetLayerExportConfigs(id: id, meta: meta),
  );
}

final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

/// A poll or a hashtag that takes up [size] on the real editor's canvas.
WidgetLayer _sized(String id, Size size, {bool poll = false}) {
  final layer = _layer(id, poll: poll);
  return WidgetLayer(
    id: id,
    widget: SizedBox.fromSize(size: size),
    width: size.width,
    interaction: poll ? interactiveCardInteraction() : null,
    meta: layer.meta,
    exportConfigs: layer.exportConfigs,
  );
}

Future<ProImageEditorState> _pumpEditor(WidgetTester tester) async {
  final key = GlobalKey<ProImageEditorState>();
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ProImageEditor.memory(
        _png,
        key: key,
        configs: const ProImageEditorConfigs(
          progressIndicatorConfigs: ProgressIndicatorConfigs(
            widgets: ProgressIndicatorWidgets(
              circularProgressIndicator: SizedBox.shrink(),
            ),
          ),
          imageGeneration: ImageGenerationConfigs(
            enableIsolateGeneration: false,
            enableBackgroundGeneration: false,
          ),
        ),
        callbacks: ProImageEditorCallbacks(
          onImageEditingComplete: (Uint8List bytes) async {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final editor = key.currentState!;
  await tester.runAsync(editor.decodeImage);
  await tester.pumpAndSettle();
  return editor;
}

/// The ids of the layers a draft would restore from [editor]'s saved history.
Future<List<String>> _savedLayerIds(ProImageEditorState editor) async {
  final exported = await editor.exportStateHistory(
    configs: const ExportEditorConfigs(
      historySpan: .currentAndBackward,
      enableMinify: false,
    ),
  );
  final history = ImportStateHistory.fromMap(
    await exported.toMap(),
    configs: ImportEditorConfigs(
      widgetLoader: (id, {meta}) => const SizedBox(),
    ),
  );
  return [
    for (final layer in history.stateHistory[history.editorPosition].layers)
      layer.exportConfigsId,
  ];
}

extension on Layer {
  String get exportConfigsId => (this as WidgetLayer).exportConfigs.id!;
}

/// Runs [keepInteractiveCardInPlace] and says whether it asked to save the history.
bool _keep(ProImageEditorState editor) {
  var save = false;
  keepInteractiveCardInPlace(
    editor,
    targetAspectRatio: 9 / 16,
    onChanged: () => save = true,
  );
  return save;
}

void main() {
  group('keepInteractiveCardInPlace', () {
    testWidgets('moves a poll back on top, in the history a draft saves', (
      tester,
    ) async {
      final editor = await _pumpEditor(tester);
      editor
        ..addLayer(
          _sized('p', const Size(100, 80), poll: true),
          blockSelectLayer: true,
        )
        ..addLayer(_sized('a', const Size(100, 80)), blockSelectLayer: true);
      await tester.pumpAndSettle();
      expect(
        await tester.runAsync(() => _savedLayerIds(editor)),
        equals(['p', 'a']),
      );

      final save = _keep(editor);

      expect(save, isTrue);
      expect(
        await tester.runAsync(() => _savedLayerIds(editor)),
        equals(['a', 'p']),
      );
    });

    testWidgets('moves and shrinks a poll let go outside the box', (
      tester,
    ) async {
      final editor = await _pumpEditor(tester);
      final poll = _sized('p', const Size(300, 200), poll: true)
        ..offset = const Offset(200, 200);
      editor.addLayer(poll, blockSelectLayer: true);
      await tester.pumpAndSettle();

      final save = _keep(editor);
      await tester.pumpAndSettle();

      expect(save, isTrue);
      final placed = editor.activeLayers.single;
      expect(placed.scale, lessThan(1));
      expect(placed.offset.dx, lessThan(200));
    });

    testWidgets('sets upright and locks a poll that stands turned', (
      tester,
    ) async {
      final editor = await _pumpEditor(tester);
      editor.addLayer(
        _sized('p', const Size(100, 80), poll: true)..rotation = 0.5,
        blockSelectLayer: true,
      );
      await tester.pumpAndSettle();

      final save = _keep(editor);

      expect(save, isTrue);
      final placed = editor.activeLayers.single;
      expect(placed.rotation, equals(0));
      expect(interactiveCardNeedsLocking(placed), isFalse);
    });

    testWidgets('changes nothing once a poll stands where it should', (
      tester,
    ) async {
      final editor = await _pumpEditor(tester);
      editor.addLayer(
        _sized('p', const Size(100, 80), poll: true),
        blockSelectLayer: true,
      );
      await tester.pumpAndSettle();
      _keep(editor);
      await tester.pumpAndSettle();

      expect(_keep(editor), isFalse);
    });

    testWidgets('changes nothing without a poll', (tester) async {
      final editor = await _pumpEditor(tester);
      editor.addLayer(_sized('a', const Size(100, 80)), blockSelectLayer: true);
      await tester.pumpAndSettle();

      expect(_keep(editor), isFalse);
    });
  });

  group('interactiveCardIndexBelowTop', () {
    test('finds a poll with another layer above it', () {
      expect(
        interactiveCardIndexBelowTop([
          _layer('a'),
          _layer('p', poll: true),
          _layer('b'),
        ]),
        equals(1),
      );
    });

    test('leaves a poll on top, and a video without one, alone', () {
      expect(
        interactiveCardIndexBelowTop([_layer('a'), _layer('p', poll: true)]),
        isNull,
      );
      expect(interactiveCardIndexBelowTop([_layer('a'), _layer('b')]), isNull);
    });
  });

  group('layerDropBehindInteractiveCard', () {
    TimelineOverlayItem bar(String id, int row, {bool poll = false}) =>
        TimelineOverlayItem(
          id: id,
          type: TimelineOverlayType.layer,
          startTime: Duration.zero,
          endTime: const Duration(seconds: 3),
          row: row,
          layer: _layer(id, poll: poll),
        );

    final items = [bar('a', 0), bar('p', 1, poll: true)];

    test('knows the bar of a poll', () {
      expect(isInteractiveCardTimelineItem(items.last), isTrue);
      expect(isInteractiveCardTimelineItem(items.first), isFalse);
    });

    test('keeps a drop above the poll as it is', () {
      expect(
        layerDropBehindInteractiveCard(
          items: items,
          row: 0,
          insertAbove: false,
        ),
        equals((row: 0, insertAbove: false)),
      );
      expect(
        layerDropBehindInteractiveCard(items: items, row: 1, insertAbove: true),
        equals((row: 1, insertAbove: true)),
      );
    });

    test('lifts a drop below the poll to its row, pushing the poll down', () {
      expect(
        layerDropBehindInteractiveCard(
          items: items,
          row: 1,
          insertAbove: false,
        ),
        equals((row: 1, insertAbove: true)),
      );
      expect(
        layerDropBehindInteractiveCard(items: items, row: 4, insertAbove: true),
        equals((row: 1, insertAbove: true)),
      );
    });

    test('leaves every drop alone without a poll', () {
      expect(
        layerDropBehindInteractiveCard(
          items: [bar('a', 0)],
          row: 3,
          insertAbove: false,
        ),
        equals((row: 3, insertAbove: false)),
      );
    });
  });

  group('interactiveCardSafeRect', () {
    test('marks the safe part of the frame an export keeps', () {
      // A 9:16 export keeps 400 by 711.1 of this body, from 44.4 down.
      final rect = interactiveCardSafeRect(
        bodySize: const Size(400, 800),
        targetAspectRatio: 9 / 16,
      );

      expect(rect.left, closeTo(24, 1e-9));
      expect(rect.right, closeTo(328, 1e-9));
      expect(rect.top, closeTo(165.33, 0.01));
      expect(rect.bottom, closeTo(627.56, 0.01));
    });
  });

  group('interactiveCardNeedsLocking', () {
    test('locks a poll that can still turn or resize, or stands turned', () {
      final free = _layer('p', poll: true);
      final locked = _layer('p', poll: true)
        ..interaction = interactiveCardInteraction();
      final turned = _layer('p', poll: true)
        ..interaction = interactiveCardInteraction()
        ..rotation = 0.3;

      expect(interactiveCardNeedsLocking(free), isTrue);
      expect(interactiveCardNeedsLocking(locked), isFalse);
      expect(interactiveCardNeedsLocking(turned), isTrue);
    });

    test('lets a poll move but not turn or resize', () {
      final interaction = interactiveCardInteraction();

      expect(interaction.enableMove, isTrue);
      expect(interaction.enableRotate, isFalse);
      expect(interaction.enableScale, isFalse);
    });
  });

  group('fitInteractiveCardIntoSafeArea', () {
    // A 9:16 export keeps 400 by 711.1 of this body, from 44.4 down, so the
    // safe area runs from 24 to 328 across and from 165.3 to 627.6 down.
    const body = Size(400, 800);

    ({Offset shift, double scale})? fit(
      Offset offset,
      Size size, {
      double rotation = 0,
    }) => fitInteractiveCardIntoSafeArea(
      offset: offset,
      size: size,
      rotation: rotation,
      bodySize: body,
      targetAspectRatio: 9 / 16,
    );

    test('leaves a poll inside the safe area where it is', () {
      expect(fit(const Offset(-16, 0), const Size(200, 150)), isNull);
    });

    test('moves a poll pushed under the buttons on the right back', () {
      final result = fit(const Offset(150, 0), const Size(200, 150));

      expect(result?.scale, equals(1));
      expect(result?.shift.dx, closeTo(-122, 1e-9));
      expect(result?.shift.dy, equals(0));
    });

    test('shrinks a poll wider than the safe area, and keeps it inside', () {
      final result = fit(Offset.zero, const Size(400, 150))!;

      expect(result.scale, closeTo(304 / 400, 1e-9));
      // Shrunk to 304 wide about the body's centre, it runs from 48 to 352,
      // 24 past the right edge of the safe area.
      expect(result.shift.dx, closeTo(-24, 1e-9));
    });

    test('measures a turned poll by the box it covers', () {
      // Turned a quarter, 200 wide and 100 high covers 100 by 200; centred
      // 200 down it reaches from 100, 65.3 above the safe area.
      final result = fit(
        const Offset(-16, -200),
        const Size(200, 100),
        rotation: math.pi / 2,
      );

      expect(result?.scale, closeTo(1, 1e-9));
      expect(result?.shift.dx, closeTo(0, 1e-9));
      expect(result?.shift.dy, closeTo(65.33, 0.01));
    });
  });
}
