// ABOUTME: Tests the My Sounds row and the fuller view heading its menu.
// ABOUTME: Covers preview taps, unavailable sounds, the waveform and contrast.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/models/sound_cover.dart';
import 'package:openvine/widgets/library/saved_sound_tile.dart';
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

SavedSound _plainSound() => SavedSound(
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

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

Widget _app(Widget child, {ThemeData? theme}) => MaterialApp(
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: theme ?? VineTheme.theme,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Widget _tile(
  SavedSound sound, {
  VoidCallback? onPreview,
  VoidCallback? onOpenMore,
  ThemeData? theme,
  bool isMissingFile = false,
  bool cannotBeReused = false,
  bool isPreviewing = false,
  bool isPlaying = false,
  Stream<double>? progress,
  double progressValue = 0,
}) => _app(
  SavedSoundTile(
    sound: sound,
    cover: SoundCover.forSavedSound(sound, sourceCovers: null),
    isMissingFile: isMissingFile,
    cannotBeReused: cannotBeReused,
    isPreviewing: isPreviewing,
    isPlaying: isPlaying,
    progress: progress,
    progressValue: progressValue,
    onPreview: onPreview ?? () {},
    onOpenMore: onOpenMore ?? () {},
  ),
  theme: theme,
);

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
  group(SavedSoundTile, () {
    group('renders', () {
      testWidgets('the label, duration, creator, hashtags and cover', (
        tester,
      ) async {
        await tester.pumpWidget(_tile(_richSound()));

        expect(find.text('Morning inspiration'), findsOneWidget);
        expect(find.textContaining('00:06', findRichText: true), findsOne);
        expect(
          find.textContaining(
            _l10n.soundCreatorBy('Alice'),
            findRichText: true,
          ),
          findsOne,
        );
        expect(find.text('#ideas #funny'), findsOneWidget);
        expect(find.byType(VineCachedImage), findsOneWidget);
      });

      testWidgets('leaves the source context to its menu', (tester) async {
        await tester.pumpWidget(_tile(_richSound()));

        expect(find.text('Filmed outside before breakfast.'), findsNothing);
        expect(find.text('Listen to that little bird.'), findsNothing);
        expect(find.text('field recording'), findsNothing);
      });

      testWidgets('a sound with no cover or hashtags quietly', (tester) async {
        await tester.pumpWidget(_tile(_plainSound()));

        expect(find.text('Instrumental loop'), findsOneWidget);
        expect(find.byKey(const Key('sound_cover_fallback')), findsOneWidget);
        expect(find.byKey(const Key('saved_sound_hashtags')), findsNothing);
      });

      testWidgets('the localized fallback title', (tester) async {
        final sound = SavedSound(
          audio: AudioEvent(id: 'empty', pubkey: 'creator', createdAt: 1),
          personalHashtags: const [],
          catalogTags: const [],
          waveformSamples: const [],
        );

        await tester.pumpWidget(_tile(sound));

        expect(find.text(_l10n.savedSoundFallbackTitle), findsOneWidget);
      });

      Color? titleColor(WidgetTester tester) =>
          tester.widget<Text>(find.text('Morning inspiration')).style?.color;

      testWidgets('the previewing title in green', (tester) async {
        await tester.pumpWidget(_tile(_richSound()));
        expect(titleColor(tester), VineTheme.darkColors.onSurface);

        await tester.pumpWidget(_tile(_richSound(), isPreviewing: true));

        expect(titleColor(tester), VineTheme.darkColors.accentPositive);
      });

      testWidgets('an unavailable title muted, even while previewing', (
        tester,
      ) async {
        await tester.pumpWidget(
          _tile(_richSound(), cannotBeReused: true, isPreviewing: true),
        );

        expect(titleColor(tester), VineTheme.darkColors.onSurfaceVariant);
      });

      testWidgets('the playing bars beside the menu button', (tester) async {
        Widget? trailing() =>
            tester.widget<ListTile>(find.byType(ListTile)).trailing;

        await tester.pumpWidget(_tile(_richSound()));
        expect(trailing(), isA<DivineIconButton>());

        await tester.pumpWidget(
          _tile(_richSound(), isPreviewing: true, isPlaying: true),
        );

        final row = trailing();
        expect(row, isA<Row>());
        final children = (row! as Row).children;
        expect(children, hasLength(2));
        expect(children.last.key, const Key('saved_sound_more'));
      });
    });

    group('interactions', () {
      testWidgets('tapping the row previews the sound', (tester) async {
        var previews = 0;
        var menus = 0;
        await tester.pumpWidget(
          _tile(
            _richSound(),
            onPreview: () => previews++,
            onOpenMore: () => menus++,
          ),
        );

        await tester.tap(find.text('Morning inspiration'));

        expect((previews, menus), (1, 0));
      });

      testWidgets('the menu button opens the actions, not a preview', (
        tester,
      ) async {
        var previews = 0;
        var menus = 0;
        await tester.pumpWidget(
          _tile(
            _richSound(),
            onPreview: () => previews++,
            onOpenMore: () => menus++,
          ),
        );

        await tester.tap(find.byKey(const Key('saved_sound_more')));

        expect((previews, menus), (0, 1));
      });

      for (final (name, hint) in [
        ('starts', _l10n.savedSoundPreviewAction),
        ('pauses', _l10n.savedSoundPausePreviewAction),
        ('resumes', _l10n.savedSoundResumePreviewAction),
      ]) {
        testWidgets('tells a screen reader the tap $name the preview', (
          tester,
        ) async {
          final semantics = tester.ensureSemantics();
          await tester.pumpWidget(
            _tile(
              _richSound(),
              isPreviewing: name != 'starts',
              isPlaying: name == 'pauses',
            ),
          );

          expect(
            tester.getSemantics(find.byType(ListTile)),
            isSemantics(onTapHint: hint),
          );
          semantics.dispose();
        });
      }
    });

    group('unavailable', () {
      for (final (name, isMissingFile, cannotBeReused, reason) in [
        ('whose file is gone', true, false, _l10n.videoEditorAudioFileMissing),
        (
          'whose source video is gone',
          false,
          true,
          _l10n.savedSoundReuseUnavailable,
        ),
      ]) {
        testWidgets('a sound $name says so and takes no preview tap', (
          tester,
        ) async {
          var previews = 0;
          var menus = 0;
          await tester.pumpWidget(
            _tile(
              _richSound(),
              isMissingFile: isMissingFile,
              cannotBeReused: cannotBeReused,
              onPreview: () => previews++,
              onOpenMore: () => menus++,
            ),
          );

          expect(find.text(reason), findsOneWidget);
          expect(
            find.textContaining(
              _l10n.soundCreatorBy('Alice'),
              findRichText: true,
            ),
            findsNothing,
          );

          await tester.tap(find.text('Morning inspiration'));
          // Removing it is still the user's call.
          await tester.tap(find.byKey(const Key('saved_sound_more')));

          expect((previews, menus), (0, 1));
        });
      }

      testWidgets('a missing file is the reason it names first', (
        tester,
      ) async {
        await tester.pumpWidget(
          _tile(_richSound(), isMissingFile: true, cannotBeReused: true),
        );

        expect(find.text(_l10n.videoEditorAudioFileMissing), findsOneWidget);
        expect(find.text(_l10n.savedSoundReuseUnavailable), findsNothing);
      });

      testWidgets('shows no waveform even while previewing', (tester) async {
        await tester.pumpWidget(
          _tile(_richSound(), isMissingFile: true, isPreviewing: true),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('saved_sound_waveform')), findsNothing);
      });

      testWidgets('shows no progress line even while previewing', (
        tester,
      ) async {
        await tester.pumpWidget(
          _tile(_plainSound(), isMissingFile: true, isPreviewing: true),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('saved_sound_progress')), findsNothing);
      });
    });

    group('waveform', () {
      testWidgets('shows only under the previewing row', (tester) async {
        await tester.pumpWidget(_tile(_richSound()));
        expect(find.byKey(const Key('saved_sound_waveform')), findsNothing);

        await tester.pumpWidget(
          _tile(_richSound(), isPreviewing: true, isPlaying: true),
        );
        // The playing bars never settle; this outlasts the waveform's reveal.
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(const Key('saved_sound_waveform')), findsOneWidget);
      });

      testWidgets('fills as the preview position advances', (tester) async {
        final position = StreamController<double>();
        addTearDown(position.close);

        await tester.pumpWidget(
          _tile(
            _richSound(),
            isPreviewing: true,
            isPlaying: true,
            progress: position.stream,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(_waveformProgress(tester), 0);

        position.add(0.42);
        // One pump delivers the position, the next draws it; the playing
        // bars' ticker must not be what schedules that frame.
        await tester.pump();
        await tester.pump();

        expect(_waveformProgress(tester), 0.42);
      });

      testWidgets('keeps its fill when remounted while paused', (
        tester,
      ) async {
        final position = StreamController<double>.broadcast();
        addTearDown(position.close);
        Widget paused() => _tile(
          _richSound(),
          isPreviewing: true,
          progress: position.stream,
          progressValue: 0.42,
        );

        await tester.pumpWidget(paused());
        await tester.pumpAndSettle();
        // No new position events while paused, only the seeded value.
        expect(_waveformProgress(tester), 0.42);

        // A list rebuild or scroll recycle mounts the same paused preview.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(paused());
        await tester.pumpAndSettle();

        expect(_waveformProgress(tester), 0.42);
      });

      testWidgets('is a line that fills for a sound saved without one', (
        tester,
      ) async {
        final position = StreamController<double>();
        addTearDown(position.close);

        await tester.pumpWidget(
          _tile(
            _plainSound(),
            isPreviewing: true,
            isPlaying: true,
            progress: position.stream,
          ),
        );
        position.add(0.42);
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(const Key('saved_sound_waveform')), findsNothing);
        expect(
          tester
              .widget<FractionallySizedBox>(
                find.descendant(
                  of: find.byKey(const Key('saved_sound_progress')),
                  matching: find.byType(FractionallySizedBox),
                ),
              )
              .widthFactor,
          0.42,
        );
      });
    });

    for (final (name, theme) in [
      ('dark', VineTheme.theme),
      ('light', VineTheme.lightTheme),
    ]) {
      testWidgets('its text stays legible in the $name theme', (tester) async {
        final colors = theme.extension<VineThemeColors>()!;
        await tester.pumpWidget(
          _tile(_richSound(), theme: theme, isPreviewing: true),
        );

        // The Library's tabs sit on this.
        final background = colors.surfaceContainerHigh;
        for (final label in ['Morning inspiration', '#ideas #funny']) {
          final color = tester.widget<Text>(find.text(label)).style!.color!;
          expect(
            contrastRatio(color, background),
            greaterThanOrEqualTo(4.5),
            reason: '"$label" is unreadable on the Library',
          );
        }
      });
    }
  });

  group(SavedSoundMenuHeader, () {
    testWidgets('shows what the row has no room for', (tester) async {
      await tester.pumpWidget(_app(SavedSoundMenuHeader(sound: _richSound())));

      expect(find.text('Morning inspiration'), findsOneWidget);
      expect(find.text('A tiny bird visits'), findsOneWidget);
      expect(find.text('Filmed outside before breakfast.'), findsOneWidget);
      expect(find.text('Listen to that little bird.'), findsOneWidget);
      expect(find.text('field recording'), findsOneWidget);
      expect(find.text('birds'), findsOneWidget);
    });

    testWidgets('leaves out what the sound does not have', (tester) async {
      await tester.pumpWidget(_app(SavedSoundMenuHeader(sound: _plainSound())));

      expect(find.text('Instrumental loop'), findsOneWidget);
      expect(find.byKey(const Key('saved_sound_transcript')), findsNothing);
    });

    testWidgets('says why the sound is unavailable', (tester) async {
      await tester.pumpWidget(
        _app(SavedSoundMenuHeader(sound: _richSound(), cannotBeReused: true)),
      );

      expect(find.text(_l10n.savedSoundReuseUnavailable), findsOneWidget);
    });
  });
}
