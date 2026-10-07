import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/publishing_ideas/publishing_ideas.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/caption_mention.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_form_fields.dart';
import 'package:publishing_suggestions/publishing_suggestions.dart';

class _Editor extends VideoEditorNotifier {
  @override
  VideoEditorProviderState build() => VideoEditorProviderState(
    title: 'My title',
    description: 'My description',
    tags: {'mine'},
  );
  @override
  void triggerAutosave() {}
}

class _Clips extends ClipManagerNotifier {
  @override
  ClipManagerState build() => ClipManagerState();
}

class _UnavailableClient implements SuggestionsClient {
  int probes = 0;
  int cancellations = 0;
  @override
  Future<ModelCapabilities> capabilities(String language) async {
    probes++;
    return const ModelCapabilities(availability: ModelAvailability.unavailable);
  }

  @override
  Future<void> prepare() async {}
  @override
  Future<void> cancel() async {
    cancellations++;
  }

  @override
  Future<String> generate(SuggestionRequest request) async =>
      throw StateError('Must not generate');
}

Future<void> _pumpForm(
  WidgetTester tester,
  _Editor editor, {
  Brightness brightness = Brightness.dark,
  _UnavailableClient? client,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        videoEditorProvider.overrideWith(() => editor),
        clipManagerProvider.overrideWith(_Clips.new),
        isFeatureEnabledProvider(FeatureFlag.publishingIdeas)
            .overrideWithValue(true),
        publishingSuggestionsRepositoryProvider.overrideWithValue(
          SuggestionsRepository(
            client: client ?? _UnavailableClient(),
            random: Random(3),
          ),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(
              2,
            ),
          ),
          child: child!,
        ),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: VideoMetadataFormFields(
              enableIdeas: true,
              enableTags: false,
              enableExpiration: false,
              enableSchedule: false,
              enableContentWarning: false,
              enableCollaborators: false,
              enableInspiredBy: false,
              enableAudioReuse: false,
              enableVideoReply: false,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openIdeas(WidgetTester tester) async {
  await tester.tap(find.text('Need ideas?'));
  await tester.pumpAndSettle();
}

const _chosen = PublishingIdea(
  title: 'Chosen title',
  description: 'Chosen description',
);

void _apply(WidgetTester tester, IdeaField field) => tester
    .widget<PublishingIdeas>(find.byType(PublishingIdeas))
    .onApply(_chosen, field);

Future<void> _undo(WidgetTester tester) async {
  await tester.tap(find.text('Undo'));
  await tester.pumpAndSettle();
}

void main() {
  group('interactions', () {
    for (final brightness in Brightness.values) {
      testWidgets('ideas preserve text until selected and Undo restores both '
          '($brightness)', (tester) async {
        final editor = _Editor();
        await _pumpForm(tester, editor, brightness: brightness);
        await _openIdeas(tester);
        final fields = tester
            .widgetList<DivineTextField>(find.byType(DivineTextField))
            .toList();
        expect(fields.first.controller!.text, 'My title');
        expect(fields.last.controller!.text, 'My description');
        expect(find.byType(Dialog), findsNothing);
        await tester.ensureVisible(find.text('Use both'));
        await tester.tap(find.text('Use both'));
        await tester.pumpAndSettle();
        expect(fields.first.controller!.text, isNot('My title'));
        await _undo(tester);
        expect(fields.first.controller!.text, 'My title');
        expect(fields.last.controller!.text, 'My description');
      });
    }

    testWidgets('only shown curated ideas consume the deck', (tester) async {
      await _pumpForm(tester, _Editor());
      await _openIdeas(tester);
      const titles = [
        'A small moment',
        'Here goes',
        'One for the loop',
        'Made this',
        'No big explanation',
        'A little bit of today',
      ];
      final seen = <String>{};
      for (var index = 0; index < titles.length; index++) {
        final visible = titles.singleWhere(
          (title) => find.text(title).evaluate().isNotEmpty,
        );
        expect(seen.add(visible), isTrue);
        if (index + 1 < titles.length) {
          await tester.ensureVisible(find.text('Surprise me'));
          await tester.tap(find.text('Surprise me'));
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('applying a title preserves description and selected tags', (
      tester,
    ) async {
      final editor = _Editor();
      await _pumpForm(tester, editor);
      _apply(tester, IdeaField.title);
      await tester.pumpAndSettle();
      final state = ProviderScope.containerOf(
        tester.element(find.byType(PublishingIdeas)),
      ).read(videoEditorProvider);
      expect(state.title, _chosen.title);
      expect(state.description, 'My description');
      expect(state.tags, {'mine'});
    });

    testWidgets('Undo preserves later typing and independently added tags', (
      tester,
    ) async {
      final editor = _Editor();
      await _pumpForm(tester, editor);
      _apply(tester, IdeaField.title);
      await tester.pumpAndSettle();
      editor.updateMetadata(title: 'My later edit', tags: {'mine', 'later'});
      await _undo(tester);
      final state = ProviderScope.containerOf(
        tester.element(find.byType(PublishingIdeas)),
      ).read(videoEditorProvider);
      expect(state.title, 'My later edit');
      expect(state.tags, {'mine', 'later'});
    });

    testWidgets('Undo restores description mentions removed by an idea', (
      tester,
    ) async {
      final editor = _Editor();
      await _pumpForm(tester, editor);
      editor.updateMetadata(description: 'With @Friend');
      const mention = CaptionMention(
        display: 'Friend',
        pubkey:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
      editor.restoreIdeasMentions([mention]);
      _apply(tester, IdeaField.description);
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PublishingIdeas)),
      );
      expect(container.read(videoEditorProvider).title, 'My title');
      expect(
        container.read(videoEditorProvider).description,
        _chosen.description,
      );
      expect(container.read(videoEditorProvider).captionMentions, isEmpty);
      await _undo(tester);
      expect(container.read(videoEditorProvider).description, 'With @Friend');
      expect(container.read(videoEditorProvider).captionMentions, [mention]);
    });

    testWidgets('collapsing ideas cancels the native operation once', (
      tester,
    ) async {
      final client = _UnavailableClient();
      await _pumpForm(tester, _Editor(), client: client);
      await _openIdeas(tester);
      final cancellations = client.cancellations;
      await tester.tap(find.text('Hide ideas'));
      await tester.pumpAndSettle();
      expect(client.cancellations, cancellations + 1);
      expect(find.text('Use both'), findsNothing);
    });

    testWidgets('metadata rebuild keeps ideas without native work', (
      tester,
    ) async {
      final editor = _Editor();
      final client = _UnavailableClient();
      await _pumpForm(tester, editor, client: client);
      await _openIdeas(tester);
      final cancellations = client.cancellations;
      expect(client.probes, 1);
      editor.updateMetadata(title: 'Typed by the creator');
      await tester.pumpAndSettle();
      expect(find.text('Use both'), findsOneWidget);
      expect(client.probes, 1);
      expect(client.cancellations, cancellations);
      expect(tester.takeException(), isNull);
    });
  });
}
