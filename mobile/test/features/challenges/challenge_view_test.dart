import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/challenges/challenge_participation_cubit.dart';
import 'package:openvine/features/challenges/challenge_view.dart';
import 'package:openvine/l10n/l10n.dart';

import '../../../packages/challenges_repository/test/harness.dart';

void main() {
  group('challenge_view', () {
    testWidgets(
      'shows the selected video review and blocks unavailable playback',
      (tester) async {
        final h = Harness();
        final coordinate = '31923:${h.organizer.pubkey}:synthetic:challenge';
        final cubit = ChallengeParticipationCubit(
          coordinate: coordinate,
          submissions: h.repository,
          refresh: () => h.reads.refresh(coordinate),
          loadCandidates: () async => [],
          exactVideo: (_) async => h.video,
          clientTags: () async => [],
          prepareRecording: (_) async => 'recording',
          handoffs: () async => [],
          reviewPublished: (_) => h.prepare(),
        );
        addTearDown(cubit.close);
        await cubit.load();
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider.value(
              value: cubit,
              child: ChallengeView(
                ownerName: 'Synthetic creator',
                onRecord: (_, _) async {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Synthetic challenge'), findsOneWidget);
        expect(find.text('Record a video'), findsOneWidget);
        await cubit.selectVideo(h.video.id);
        await tester.pumpAndSettle();
        expect(find.text('Human-made synthetic rules.'), findsOneWidget);
        expect(h.signatures, 0);
        expect(find.text('Signing account: Synthetic creator'), findsOneWidget);
        expect(
          find.text(
            'This video cannot be previewed right now. Try again before submitting.',
          ),
          findsOneWidget,
        );
        expect(find.text(h.video.id), findsNothing);
        await tester.scrollUntilVisible(find.text('Agree and submit'), 150);
        await tester.pump();
        final agree = find.ancestor(
          of: find.text('Agree and submit'),
          matching: find.byType(DivineButton),
        );
        expect(tester.widget<DivineButton>(agree).onPressed, isNull);
        expect(h.signatures, 0);
        await tester.ensureVisible(find.text('Technical details'));
        await tester.tap(find.text('Technical details'));
        await tester.pumpAndSettle();
        expect(find.text(h.video.id), findsOneWidget);
        expect(find.text(h.definition.id), findsOneWidget);
        expect(find.text(h.owner!), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
  });
}
