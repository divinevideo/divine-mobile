import 'dart:convert';

import 'package:challenge_protocol/challenge_protocol.dart' hide ChallengeView;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/challenges/challenge_participation_cubit.dart';
import 'package:openvine/features/challenges/challenge_view.dart';
import 'package:openvine/l10n/l10n.dart';

import '../../../packages/challenges_repository/test/harness.dart';

void main() {
  group('challenge deadlines', () {
    testWidgets('detail and review label UTC and use the app locale', (
      tester,
    ) async {
      final h = Harness();
      final end =
          DateTime.parse('2030-01-01T18:30:00+13:00').millisecondsSinceEpoch ~/
          1000;
      h.definition = NostrEvent.fromJson(
        h.organizer.definition(start: end - 3600, end: end),
      );
      h.now = end - 1800;
      h.source.records = [jsonEncode(h.definition.toJson())];
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
          locale: const Locale('fr'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: cubit,
            child: ChallengeView(onRecord: (_, _) async {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Deadline (UTC): 1 janv. 2030 05:30'), findsOneWidget);
      await cubit.selectVideo(h.video.id);
      await tester.pumpAndSettle();
      expect(find.text('Deadline (UTC): 1 janv. 2030 05:30'), findsOneWidget);
      expect(h.signatures, 0);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
