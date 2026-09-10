// ABOUTME: Tests terminal cleanup feedback after an owner deletes a video.
// ABOUTME: Verifies completion messages remain safe after the source UI closes.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/owner_video_actions/owner_video_actions_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/owner_video_cleanup_feedback.dart';

class _MockOwnerVideoActionsCubit extends Mock
    implements OwnerVideoActionsCubit {}

void main() {
  group('showOwnerVideoCleanupCompletion', () {
    testWidgets('shows delayed feedback when confirmation is delayed', (
      tester,
    ) async {
      const videoId =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final cubit = _MockOwnerVideoActionsCubit();
      when(() => cubit.cleanupCompletionFor(videoId)).thenAnswer(
        (_) async => const OwnerVideoOperationState(
          deleteStatus: OwnerVideoDeleteStatus.success,
          cleanupStatus: OwnerVideoCleanupStatus.delayed,
        ),
      );
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (builderContext) {
                context = builderContext;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      showOwnerVideoCleanupCompletion(context, cubit, videoId);
      await tester.pump();

      expect(
        find.text(
          'Video deleted. It may take a little while to disappear everywhere.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('does not show feedback after the messenger is disposed', (
      tester,
    ) async {
      const videoId =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final completion = Completer<OwnerVideoOperationState>();
      final cubit = _MockOwnerVideoActionsCubit();
      when(
        () => cubit.cleanupCompletionFor(videoId),
      ).thenAnswer((_) => completion.future);
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (builderContext) {
                context = builderContext;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      showOwnerVideoCleanupCompletion(context, cubit, videoId);
      await tester.pumpWidget(const SizedBox.shrink());
      completion.complete(
        const OwnerVideoOperationState(
          deleteStatus: OwnerVideoDeleteStatus.success,
          cleanupStatus: OwnerVideoCleanupStatus.confirmed,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
