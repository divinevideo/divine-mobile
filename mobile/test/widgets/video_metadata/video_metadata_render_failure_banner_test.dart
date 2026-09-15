// ABOUTME: Widget tests for VideoMetadataRenderFailureBanner. Pins that a
// ABOUTME: failed render is explained below the preview, not inside (#7125).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_editor/video_render_failure_reason.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_render_failure_banner.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(VideoMetadataRenderFailureBanner, () {
    Widget buildWidget({
      bool renderFailed = false,
      VideoRenderFailureReason? reason,
    }) {
      return ProviderScope(
        overrides: [
          videoEditorProvider.overrideWith(
            () => _MockVideoEditorNotifier(
              VideoEditorProviderState(
                renderFailed: renderFailed,
                renderFailureReason: reason,
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: VideoMetadataRenderFailureBanner()),
        ),
      );
    }

    group('renders', () {
      testWidgets('the storage copy when the render failed out of storage', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            renderFailed: true,
            reason: VideoRenderFailureReason.insufficientStorage,
          ),
        );

        expect(find.text(l10n.publishErrorLowStorage), findsOneWidget);
        final card = tester.widget<DivineInfoCard>(find.byType(DivineInfoCard));
        expect(card.tone, DivineInfoCardTone.error);
      });

      testWidgets('the generic copy for every other failure', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            renderFailed: true,
            reason: VideoRenderFailureReason.nativeRender,
          ),
        );

        expect(find.text(l10n.videoMetadataGenerationFailed), findsOneWidget);
        expect(find.text(l10n.publishErrorLowStorage), findsNothing);
      });

      testWidgets('the generic copy when the failure was not classified', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(renderFailed: true));

        expect(find.text(l10n.videoMetadataGenerationFailed), findsOneWidget);
      });

      testWidgets('nothing while no render has failed', (tester) async {
        await tester.pumpWidget(
          buildWidget(reason: VideoRenderFailureReason.insufficientStorage),
        );

        expect(find.byType(DivineInfoCard), findsNothing);
        expect(
          tester.getSize(find.byType(VideoMetadataRenderFailureBanner)),
          Size.zero,
          reason: 'a hidden banner must not push the form down',
        );
      });
    });

    group('accessibility', () {
      testWidgets('announces its copy when it appears', (tester) async {
        final announcements = <String>[];
        tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              (Object? message) async {
                if (message is Map && message['type'] == 'announce') {
                  final data = message['data'] as Map?;
                  announcements.add(data?['message'] as String);
                }
                return null;
              },
            );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger
              .setMockDecodedMessageHandler<Object?>(
                SystemChannels.accessibility,
                null,
              ),
        );

        await tester.pumpWidget(
          buildWidget(
            renderFailed: true,
            reason: VideoRenderFailureReason.insufficientStorage,
          ),
        );
        await tester.pump();

        expect(announcements, [l10n.publishErrorLowStorage]);
      });
    });
  });
}

class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state);

  final VideoEditorProviderState _state;

  @override
  VideoEditorProviderState build() => _state;
}
