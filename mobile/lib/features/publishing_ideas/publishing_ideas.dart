import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/publishing_ideas/publishing_ideas_cubit.dart';
import 'package:openvine/features/publishing_ideas/publishing_ideas_providers.dart';
import 'package:openvine/features/publishing_ideas/publishing_ideas_view.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:publishing_suggestions/publishing_suggestions.dart';

export 'publishing_ideas_view.dart' show IdeaField;

/// Injectable local-model dependency; constructed only when ideas are offered.
final publishingSuggestionsRepositoryProvider = Provider<SuggestionsRepository>(
  (ref) => SuggestionsRepository(client: NativeSuggestionsClient()),
);

/// Dependency bridge for optional suggestions inside the publishing form.
class PublishingIdeas extends ConsumerWidget {
  const PublishingIdeas({required this.onApply, super.key});
  final void Function(PublishingIdea idea, IdeaField field) onApply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(publishingSuggestionsRepositoryProvider);
    final editor = ref.watch(videoEditorProvider);
    final clips = ref.watch(clipManagerProvider.select((state) => state.clips));
    return BlocProvider(
      key: ValueKey(repository),
      create: (_) => PublishingIdeasCubit(repository: repository),
      child: PublishingIdeasView(
        editor: editor,
        clips: clips,
        language: Localizations.localeOf(context).toLanguageTag(),
        media: () => ref.read(publishingIdeasMediaProvider),
        onApply: onApply,
        onSaveTranscript: (transcript) => ref
            .read(videoEditorProvider.notifier)
            .updateIdeasTranscript(transcript),
        onAddTag: (tag) => ref
            .read(videoEditorProvider.notifier)
            .updateMetadata(
              tags: {...ref.read(videoEditorProvider).tags, tag},
            ),
      ),
    );
  }
}
