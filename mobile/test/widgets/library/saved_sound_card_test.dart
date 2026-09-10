// ABOUTME: Tests rich saved-sound cards and their source/private metadata.
// ABOUTME: Ensures music-only fallbacks stay quiet and actions remain distinct.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/widgets/library/saved_sound_card.dart';
import 'package:openvine/widgets/stereo_waveform_painter.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

import '../../helpers/contrast.dart';

SavedSound _richSound() => SavedSound(
  audio: AudioEvent(
    id: 'sound-id',
    pubkey: 'creator',
    createdAt: 1,
    title: 'Audio fallback title',
    duration: 6,
  ),
  personalLabel: 'Morning inspiration',
  personalHashtags: const ['ideas', 'funny'],
  catalogTags: const ['field recording', 'birds'],
  waveformSamples: const [0.1, 0.8, 0.4],
  sourceContext: const SavedSoundSourceContext(
    title: 'A tiny bird visits',
    creatorName: 'Alice',
    description: 'Filmed outside before breakfast.',
    thumbnailUrl: 'https://example.com/thumb.jpg',
    transcript: 'Listen to that little bird.',
  ),
);

Widget _app(
  SavedSound sound, {
  VoidCallback? onTap,
  VoidCallback? onPreview,
  VoidCallback? onEdit,
  VoidCallback? onRemove,
  ThemeData? theme,
  bool isPlaying = false,
  bool isMissingFile = false,
  Stream<double>? progress,
  double progressValue = 0,
}) => MaterialApp(
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: theme ?? ThemeData.dark(),
  home: Scaffold(
    body: SingleChildScrollView(
      child: SavedSoundCard(
        sound: sound,
        isMissingFile: isMissingFile,
        isPlaying: isPlaying,
        progress: progress,
        progressValue: progressValue,
        onTap: onTap ?? () {},
        onPreview: onPreview ?? () {},
        onEdit: onEdit ?? () {},
        onRemove: onRemove ?? () {},
      ),
    ),
  ),
);

DivineIconName? _previewIcon(WidgetTester tester) => tester
    .widget<DivineIconButton>(find.byKey(const Key('saved_sound_preview')))
    .icon;

double _waveformProgress(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byKey(const Key('saved_sound_waveform')),
      matching: find.byType(CustomPaint),
    ),
  );
  return (paint.painter! as StereoWaveformPainter).progress;
}

void main() {
  group('missing audio file', () {
    testWidgets('says the file is gone and drops the preview', (tester) async {
      var previewed = false;
      var opened = false;
      await tester.pumpWidget(
        _app(
          _richSound(),
          isMissingFile: true,
          onPreview: () => previewed = true,
          onTap: () => opened = true,
        ),
      );

      final en = lookupAppLocalizations(const Locale('en'));
      expect(find.text(en.savedSoundFileMissing), findsOneWidget);
      expect(
        find.byKey(const Key('saved_sound_preview')),
        findsNothing,
        reason:
            'A preview that plays silence is the bug — there is nothing to '
            'start (#8023).',
      );
      expect(
        find.byKey(const Key('saved_sound_remove')),
        findsOneWidget,
        reason: 'Removal is the only action left that changes anything.',
      );
      expect(
        tester
            .getSemantics(find.byType(SavedSoundCard))
            .flagsCollection
            .isButton,
        isFalse,
        reason: 'A card with no card-level tap must not announce as a button.',
      );

      await tester.tap(find.byType(SavedSoundCard));
      await tester.pump();
      expect(previewed, isFalse);
      expect(opened, isFalse);
    });

    testWidgets('leaves a playable sound alone', (tester) async {
      await tester.pumpWidget(_app(_richSound()));

      final en = lookupAppLocalizations(const Locale('en'));
      expect(find.text(en.savedSoundFileMissing), findsNothing);
      expect(find.byKey(const Key('saved_sound_preview')), findsOneWidget);
    });
  });

  group(SavedSoundCard, () {
    testWidgets('shows rich source, private, and catalog context', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_richSound()));

      expect(find.byType(VineCachedImage), findsOneWidget);
      expect(find.text('Morning inspiration'), findsOneWidget);
      expect(find.text('A tiny bird visits'), findsOneWidget);
      expect(find.text('By Alice'), findsOneWidget);
      expect(find.text('Filmed outside before breakfast.'), findsOneWidget);
      expect(find.text('Listen to that little bird.'), findsOneWidget);
      expect(find.byKey(const Key('saved_sound_waveform')), findsOneWidget);
      expect(find.text('#ideas'), findsOneWidget);
      expect(find.text('#funny'), findsOneWidget);
      expect(find.text('field recording'), findsOneWidget);
      expect(find.text('birds'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('opens details when the card body is tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_app(_richSound(), onTap: () => tapped = true));

      await tester.tap(find.text('Morning inspiration'));

      expect(tapped, isTrue);
    });

    testWidgets(
      'music-only sound has a quiet fallback without transcript error',
      (tester) async {
        final sound = SavedSound(
          audio: AudioEvent(
            id: 'music',
            pubkey: 'creator',
            createdAt: 1,
            title: 'Instrumental loop',
          ),
          personalHashtags: const [],
          catalogTags: const [],
          waveformSamples: const [],
        );

        await tester.pumpWidget(_app(sound));

        expect(find.text('Instrumental loop'), findsOneWidget);
        expect(
          find.byKey(const Key('saved_sound_thumbnail_fallback')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('saved_sound_transcript')), findsNothing);
        expect(find.byKey(const Key('saved_sound_waveform')), findsNothing);
        expect(
          find.textContaining('transcript', findRichText: true),
          findsNothing,
        );
      },
    );

    testWidgets('falls back to localized generic title shape', (tester) async {
      final sound = SavedSound(
        audio: AudioEvent(id: 'empty', pubkey: 'creator', createdAt: 1),
        personalHashtags: const [],
        catalogTags: const [],
        waveformSamples: const [],
      );

      await tester.pumpWidget(_app(sound));

      expect(find.text('Saved sound'), findsOneWidget);
    });

    testWidgets('semantic label includes display title and duration', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(_richSound()));

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Morning inspiration, 0:06',
        ),
        findsOneWidget,
      );

      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('preview edit and remove callbacks stay distinct', (
      tester,
    ) async {
      var previews = 0;
      var edits = 0;
      var removes = 0;
      await tester.pumpWidget(
        _app(
          _richSound(),
          onPreview: () => previews++,
          onEdit: () => edits++,
          onRemove: () => removes++,
        ),
      );

      await tester.tap(find.byKey(const Key('saved_sound_preview')));
      await tester.tap(find.byKey(const Key('saved_sound_edit')));
      await tester.tap(find.byKey(const Key('saved_sound_remove')));

      expect((previews, edits, removes), (1, 1, 1));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('preview button turns into pause while the sound plays', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_richSound()));
      expect(_previewIcon(tester), DivineIconName.play);

      await tester.pumpWidget(_app(_richSound(), isPlaying: true));
      expect(_previewIcon(tester), DivineIconName.pause);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('waveform fills as the preview position advances', (
      tester,
    ) async {
      final position = StreamController<double>();
      addTearDown(position.close);

      await tester.pumpWidget(_app(_richSound()));
      expect(_waveformProgress(tester), 0);

      await tester.pumpWidget(
        _app(_richSound(), isPlaying: true, progress: position.stream),
      );
      position.add(0.42);
      await tester.pumpAndSettle();

      expect(_waveformProgress(tester), 0.42);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('waveform keeps its fill when remounted while paused', (
      tester,
    ) async {
      final position = StreamController<double>.broadcast();
      addTearDown(position.close);

      await tester.pumpWidget(
        _app(_richSound(), progress: position.stream, progressValue: 0.42),
      );

      // No new position events while paused — only the seeded value.
      expect(_waveformProgress(tester), 0.42);

      // Remount the same paused preview (list rebuild / scroll recycle).
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        _app(_richSound(), progress: position.stream, progressValue: 0.42),
      );
      expect(_waveformProgress(tester), 0.42);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('preview button labels resume while paused mid-preview', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final position = StreamController<double>.broadcast();
      addTearDown(position.close);

      await tester.pumpWidget(_app(_richSound(), progress: position.stream));

      expect(
        tester
            .widget<DivineIconButton>(
              find.byKey(const Key('saved_sound_preview')),
            )
            .semanticLabel,
        l10n.savedSoundResumePreviewAction,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    for (final (name, theme) in [
      ('dark', VineTheme.theme),
      ('light', VineTheme.lightTheme),
    ]) {
      testWidgets('card text stays legible on the $name theme', (tester) async {
        await tester.pumpWidget(_app(_richSound(), theme: theme));

        final cardFill = find
            .descendant(
              of: find.byType(SavedSoundCard),
              matching: find.byType(DecoratedBox),
            )
            .first;
        final decoration =
            tester.widget<DecoratedBox>(cardFill).decoration as BoxDecoration;

        for (final label in [
          'Morning inspiration',
          'A tiny bird visits',
          'Filmed outside before breakfast.',
          'Listen to that little bird.',
        ]) {
          final color = tester.widget<Text>(find.text(label)).style!.color!;
          expect(
            contrastRatio(color, decoration.color!),
            greaterThanOrEqualTo(4.5),
            reason: '"$label" is unreadable on the card fill',
          );
        }

        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  });
}
