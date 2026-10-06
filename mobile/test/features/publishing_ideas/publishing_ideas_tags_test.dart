import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/publishing_ideas/publishing_ideas.dart';
import 'package:openvine/features/publishing_ideas/publishing_ideas_revision.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/video_editor/ideas_transcript.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:publishing_suggestions/publishing_suggestions.dart';

class Editor extends VideoEditorNotifier {
  @override
  VideoEditorProviderState build() => VideoEditorProviderState(
    tags: {'mine'},
    ideasTranscript: IdeasTranscript(
      revision: publishingIdeasRevision({}, []),
      language: 'en',
      text: 'I folded a paper crane.',
    ),
  );
  @override
  void triggerAutosave() {}
}

class Clips extends ClipManagerNotifier {
  @override
  ClipManagerState build() => ClipManagerState();
}

class Client implements SuggestionsClient {
  SuggestionRequest? request;
  @override
  Future<ModelCapabilities> capabilities(String language) async =>
      const ModelCapabilities(availability: ModelAvailability.ready);
  @override
  Future<void> prepare() async {}
  @override
  Future<void> cancel() async {}
  @override
  Future<String> generate(SuggestionRequest value) async {
    request = value;
    return jsonEncode({
      'ideas': [
        {'title': 'Paper crane', 'description': 'A little fold.'},
      ],
      'hashtags': ['mine', 'paper', 'PAPER'],
    });
  }
}

void main() {
  group('interactions', () {
    testWidgets(
      'tags require an independent tap and private transcript stays private',
      (tester) async {
        final client = Client();
        final applied = <IdeaField>[];
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              videoEditorProvider.overrideWith(Editor.new),
              clipManagerProvider.overrideWith(Clips.new),
              publishingSuggestionsRepositoryProvider.overrideWithValue(
                SuggestionsRepository(client: client),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: PublishingIdeas(
                    onApply: (_, field) => applied.add(field),
                  ),
                ),
              ),
            ),
          ),
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(PublishingIdeas)),
        );
        await tester.tap(find.text('Need ideas?'));
        await tester.pumpAndSettle();
        expect(client.request!.transcript, 'I folded a paper crane.');
        expect(client.request!.frames, isEmpty);
        expect(find.text('#paper'), findsOneWidget);
        expect(find.text('#mine'), findsNothing);
        expect(container.read(videoEditorProvider).tags, {'mine'});
        await tester.tap(find.text('Paper crane'));
        await tester.pumpAndSettle();
        expect(applied, [IdeaField.title]);
        expect(container.read(videoEditorProvider).tags, {'mine'});
        await tester.ensureVisible(find.text('#paper'));
        await tester.tap(find.text('#paper'));
        await tester.pumpAndSettle();
        expect(container.read(videoEditorProvider).tags, {'mine', 'paper'});
        expect(find.text('#paper'), findsNothing);
        expect(
          container.read(videoEditorProvider).editorEditingParameters,
          isNull,
        );
      },
    );
  });
}
