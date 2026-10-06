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

class Editor extends VideoEditorNotifier {
  @override
  VideoEditorProviderState build() => VideoEditorProviderState(
    title: 'My title',
    description: 'My description',
    tags: {'mine'},
  );
  @override
  void triggerAutosave() {}
}

class Clips extends ClipManagerNotifier {
  @override
  ClipManagerState build() => ClipManagerState();
}

class UnavailableClient implements SuggestionsClient {
  @override
  Future<ModelCapabilities> capabilities(String language) async =>
      const ModelCapabilities(availability: ModelAvailability.unavailable);
  @override
  Future<void> prepare() async {}
  @override
  Future<void> cancel() async {}
  @override
  Future<String> generate(SuggestionRequest request) async =>
      throw StateError('Must not generate');
}

void main() {
  group('interactions', () {
    for (final brightness in Brightness.values) {
      testWidgets(
        'inline ideas preserve text until selected and Undo restores it ($brightness)',
        (tester) async {
          final editor = Editor();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                videoEditorProvider.overrideWith(() => editor),
                clipManagerProvider.overrideWith(Clips.new),
                isFeatureEnabledProvider(FeatureFlag.publishingIdeas)
                    .overrideWithValue(true),
                publishingSuggestionsRepositoryProvider.overrideWithValue(
                  SuggestionsRepository(
                    client: UnavailableClient(),
                    random: Random(3),
                  ),
                ),
              ],
              child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(
                      brightness == Brightness.light ? 2 : 1,
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
          await tester.tap(find.text('Need ideas?'));
          await tester.pumpAndSettle();
          expect(find.text('Use both'), findsOneWidget);
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
          await tester.tap(find.text('Undo'));
          await tester.pumpAndSettle();
          expect(fields.first.controller!.text, 'My title');
          expect(fields.last.controller!.text, 'My description');
          final container = ProviderScope.containerOf(
            tester.element(find.byType(PublishingIdeas)),
          );
          const selected = PublishingIdea(
            title: 'Chosen title',
            description: 'Chosen description',
          );
          final panel = tester.widget<PublishingIdeas>(
            find.byType(PublishingIdeas),
          );
          panel.onApply(selected, IdeaField.title);
          await tester.pumpAndSettle();
          expect(fields.first.controller!.text, selected.title);
          expect(fields.last.controller!.text, 'My description');
          expect(container.read(videoEditorProvider).tags, {'mine'});
          // Undo must preserve typing and tag choices made after insertion.
          editor.updateMetadata(
            title: 'My later edit',
            tags: {'mine', 'later'},
          );
          await tester.tap(find.text('Undo'));
          await tester.pumpAndSettle();
          expect(container.read(videoEditorProvider).title, 'My later edit');
          expect(container.read(videoEditorProvider).tags, {'mine', 'later'});
          editor.updateMetadata(description: 'With @Friend');
          const mention = CaptionMention(
            display: 'Friend',
            pubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          );
          editor.restoreIdeasMentions([mention]);
          panel.onApply(selected, IdeaField.description);
          await tester.pumpAndSettle();
          expect(container.read(videoEditorProvider).title, 'My later edit');
          expect(
            container.read(videoEditorProvider).description,
            selected.description,
          );
          expect(container.read(videoEditorProvider).captionMentions, isEmpty);
          await tester.tap(find.text('Undo'));
          await tester.pumpAndSettle();
          expect(
            container.read(videoEditorProvider).description,
            'With @Friend',
          );
          expect(container.read(videoEditorProvider).captionMentions, [
            mention,
          ]);
        },
      );
    }
  });
}
