// ABOUTME: Tests the pending tile shown while a recorded video reply uploads
// ABOUTME: and publishes (#5862): localized copy and progress binding.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/screens/comments/widgets/pending_video_reply_tile.dart';

class _MockPublishBloc
    extends MockBloc<BackgroundPublishEvent, BackgroundPublishState>
    implements BackgroundPublishBloc {}

DivineVideoDraft _draft(String id) => DivineVideoDraft.create(
  id: id,
  clips: const [],
  title: 'reply',
  description: '',
  hashtags: const {},
  selectedApproach: 'native',
);

void main() {
  group(PendingVideoReplyTile, () {
    late _MockPublishBloc publish;

    setUp(() => publish = _MockPublishBloc());

    Future<void> pumpTile(
      WidgetTester tester, {
      required double progress,
      bool disableAnimations = false,
    }) {
      when(() => publish.state).thenReturn(
        BackgroundPublishState(
          uploads: [
            BackgroundUpload(
              draft: _draft('draft-1'),
              result: null,
              progress: progress,
            ),
          ],
        ),
      );
      return tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableAnimations),
            child: child!,
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<BackgroundPublishBloc>.value(
              value: publish,
              child: const PendingVideoReplyTile(draftId: 'draft-1'),
            ),
          ),
        ),
      );
    }

    testWidgets('renders the localized pending copy', (tester) async {
      await pumpTile(tester, progress: 0.5);

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.commentsVideoReplyPending), findsOneWidget);
      // Proves the widget reads from l10n rather than a hardcoded string.
      expect(
        find.text(
          lookupAppLocalizations(const Locale('de')).commentsVideoReplyPending,
        ),
        findsNothing,
      );
    });

    testWidgets('binds the progress indicator to the upload progress', (
      tester,
    ) async {
      await pumpTile(tester, progress: 0.5);

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.value, closeTo(0.5, 0.001));
    });

    testWidgets('stays indeterminate before the upload reports progress', (
      tester,
    ) async {
      // A 0% determinate bar reads as stalled; the spinner reads as working.
      await pumpTile(tester, progress: 0);

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.value, isNull);
    });

    testWidgets('stays indeterminate and idle with reduced motion', (
      tester,
    ) async {
      await pumpTile(tester, progress: 0, disableAnimations: true);

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.value, 0.75);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('exposes a screen-reader label for the pending row', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpTile(tester, progress: 0.5);

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.bySemanticsLabel(l10n.commentsVideoReplyPendingSemanticLabel),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
