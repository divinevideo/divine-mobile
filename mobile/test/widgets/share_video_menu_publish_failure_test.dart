// ABOUTME: Widget tests for publish failure branches in the edit-video flow.
// ABOUTME: Verifies that VideoMetadataEditBottomBar shows a generic failure
// ABOUTME: snackbar and does NOT expose raw branch-detail strings
// ABOUTME: ('no relays connected', 'send error').

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/video_metadata_update_error_l10n.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_metadata_update_error.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/video_metadata_update_service.dart';
import 'package:openvine/widgets/video_metadata/modes/edit/video_metadata_edit_bottom_bar.dart';

class _MockVideoMetadataUpdateService extends Mock
    implements VideoMetadataUpdateService {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state);

  final VideoEditorProviderState _state;

  @override
  VideoEditorProviderState build() => _state;
}

VideoEvent _testVideo({required String ownerPubkey}) {
  return VideoEvent(
    id: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    pubkey: ownerPubkey,
    createdAt: 1757385263,
    content: 'Test video content',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
    videoUrl: 'https://cdn.example.com/video.mp4',
    title: 'Test Video Title',
    vineId: 'video-d-tag',
    nostrEventTags: const [
      ['imeta', 'url https://cdn.example.com/video.mp4', 'm video/mp4'],
    ],
  );
}

void main() {
  const ownerPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  final l10n = lookupAppLocalizations(const Locale('en'));

  late _MockVideoMetadataUpdateService mockService;

  setUpAll(() {
    registerFallbackValue(VideoEditorProviderState());
    registerFallbackValue(_FakeVideoEvent());
  });

  setUp(() {
    mockService = _MockVideoMetadataUpdateService();
  });

  Widget buildSubject() {
    return ProviderScope(
      overrides: [
        videoEditorProvider.overrideWith(
          () => _MockVideoEditorNotifier(VideoEditorProviderState()),
        ),
        videoMetadataUpdateServiceProvider.overrideWithValue(mockService),
      ],
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VideoMetadataEditBottomBar(
            video: _testVideo(ownerPubkey: ownerPubkey),
            initialCollaboratorPubkeys: const {},
          ),
        ),
      ),
    );
  }

  group('VideoMetadataEditBottomBar publish failure branches', () {
    testWidgets(
      'PublishNoRelays: shows failure snackbar without branch-detail string',
      (tester) async {
        when(
          () => mockService.updateVideo(
            originalVideo: any(named: 'originalVideo'),
            editorState: any(named: 'editorState'),
            initialCollaboratorPubkeys: any(
              named: 'initialCollaboratorPubkeys',
            ),
            newThumbnailFile: any(named: 'newThumbnailFile'),
          ),
        ).thenAnswer(
          (_) async => const VideoUpdateFailure(
            VideoMetadataUpdateError.publishRejected,
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.shareMenuUpdate));
        await tester.pumpAndSettle();

        // Generic failure snackbar should appear.
        expect(find.byType(SnackBar), findsOneWidget);

        // #3589: the reason code is localized; the exception that produced it
        // never reaches the user.
        expect(
          find.text(
            l10n.videoMetadataUpdateErrorMessage(
              VideoMetadataUpdateError.publishRejected,
            ),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Exception'), findsNothing);
        expect(
          find.textContaining('Failed to publish updated event'),
          findsNothing,
        );

        // Raw branch detail must NOT leak into user-visible text.
        expect(find.textContaining('no relays connected'), findsNothing);
        expect(find.textContaining('send error'), findsNothing);
      },
    );

    testWidgets(
      'PublishFailed: shows failure snackbar without branch-detail string',
      (tester) async {
        when(
          () => mockService.updateVideo(
            originalVideo: any(named: 'originalVideo'),
            editorState: any(named: 'editorState'),
            initialCollaboratorPubkeys: any(
              named: 'initialCollaboratorPubkeys',
            ),
            newThumbnailFile: any(named: 'newThumbnailFile'),
          ),
        ).thenAnswer(
          (_) async => const VideoUpdateFailure(
            VideoMetadataUpdateError.publishRejected,
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.shareMenuUpdate));
        await tester.pumpAndSettle();

        // Generic failure snackbar should appear.
        expect(find.byType(SnackBar), findsOneWidget);

        // #3589: the reason code is localized; the exception that produced it
        // never reaches the user.
        expect(
          find.text(
            l10n.videoMetadataUpdateErrorMessage(
              VideoMetadataUpdateError.publishRejected,
            ),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Exception'), findsNothing);
        expect(
          find.textContaining('Failed to publish updated event'),
          findsNothing,
        );

        // Raw branch detail must NOT leak into user-visible text.
        expect(find.textContaining('no relays connected'), findsNothing);
        expect(find.textContaining('send error'), findsNothing);
      },
    );
  });
}
