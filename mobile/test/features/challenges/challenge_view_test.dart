import 'dart:convert';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/challenges/challenge_participation_cubit.dart';
import 'package:openvine/features/challenges/challenge_playback.dart';
import 'package:openvine/features/challenges/challenge_view.dart';
import 'package:openvine/l10n/l10n.dart';

import '../../../packages/challenges_repository/test/harness.dart';

void main() {
  group('challenge_view', () {
    testWidgets(
      'entry playback is visible and Back restores the scrolled grid',
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
        await cubit.selectVideo(h.video.id);
        await cubit.confirm();
        final body = cubit.state.actions.single.signedBody;
        h.source.records.add(body);
        final entryId =
            (jsonDecode(body) as Map<String, dynamic>)['id'] as String;
        await cubit.load();
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider.value(
              value: cubit,
              child: ChallengeView(onRecord: (_, _) async {}),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
        await tester.pumpAndSettle();
        final scroll = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        final offset = scroll.position.pixels;
        await cubit.playEntry(entryId);
        await tester.pumpAndSettle();
        expect(find.byType(ChallengePlayback).hitTestable(), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(cubit.state.playing, isNull);
        expect(find.byType(ChallengePlayback), findsNothing);
        expect(scroll.position.pixels, offset);
        await tester.pumpWidget(const SizedBox());
      },
    );
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
        expect(find.text('Enter challenge'), findsOneWidget);
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
        await tester.scrollUntilVisible(find.text('Enter this video'), 150);
        await tester.pump();
        final agree = find.ancestor(
          of: find.text('Enter this video'),
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
