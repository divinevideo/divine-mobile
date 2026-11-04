import 'dart:convert';
import 'dart:io';

import 'package:challenge_protocol/challenge_protocol.dart' as cp;
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/challenges/challenge_participation_cubit.dart';
import 'package:openvine/features/challenges/challenge_video_tile.dart';
import 'package:openvine/features/challenges/challenge_view.dart';
import 'package:openvine/l10n/l10n.dart';

import '../../../packages/challenges_repository/test/harness.dart';

void main() {
  final corpus = jsonDecode(
    File('packages/challenge_protocol/test/fixtures/v1/scenarios.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>;
  final scenarios = (corpus['scenarios'] as List).cast<Map<String, dynamic>>();
  final open = scenarios.singleWhere((s) => s['name'] == 'open');
  final result = scenarios.singleWhere((s) => s['name'] == 'withdrawn-winner');
  group('challenge_golden renders', () {
    for (final light in [false, true]) {
      for (final screen in ['detail', 'scrolled', 'picker', 'results']) {
        testWidgets('challenge $screen ${light ? 'light' : 'dark'}', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final h = Harness();
          // The existing synthetic signed definition keeps the organizer avatar
          // deterministic without persisting a signing key in a golden fixture.
          h.definition = cp.NostrEvent.fromJson(
            (open['events'] as List).first as Map<String, dynamic>,
          );
          h.now = open['now'] as int;
          h.source.records = [jsonEncode(h.definition.toJson())];
          final definition =
              cp.parseChallengeEvent(h.definition).value!
                  as cp.ChallengeDefinition;
          final videos = [
            for (var i = 0; i < 8; i++)
              cp.NostrEvent.fromJson(
                h.creator.sign(
                  kind: 34236,
                  tags: [
                    ['d', 'synthetic:video:$i'],
                    ['dim', if (i.isEven) '360x640' else '640x360'],
                  ],
                  content: 'Synthetic creative video ${i + 1}',
                ),
              ),
          ];
          final entries = [
            for (var i = 0; i < 8; i++)
              cp.NostrEvent.fromJson(
                h.creator.template(
                  cp.buildEntry(definition, videos[i], h.now - 10 + i),
                ),
              ),
          ];
          h.source.records.addAll(entries.map((e) => jsonEncode(e.toJson())));
          if (screen == 'results') {
            h.now = result['now'] as int;
            h.source.records = (result['events'] as List)
                .map(jsonEncode)
                .toList();
          }
          final cubit = ChallengeParticipationCubit(
            coordinate: definition.coordinate,
            submissions: h.repository,
            refresh: () => h.reads.refresh(definition.coordinate),
            loadCandidates: () async =>
                videos.map((v) => challengeVideoModel(v)!).toList(),
            exactVideo: (id) async =>
                videos.where((v) => v.id == id).firstOrNull,
            clientTags: () async => [],
            prepareRecording: (_) async => 'recording',
            handoffs: () async => [],
            reviewPublished: (_) => h.prepare(),
          );
          addTearDown(cubit.close);
          await cubit.load();
          if (screen == 'picker') await cubit.chooseVideo();
          await tester.pumpWidget(
            MaterialApp(
              theme: light ? VineTheme.lightTheme : VineTheme.theme,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              initialRoute: '/challenge',
              home: const SizedBox(),
              routes: {
                '/challenge': (_) => BlocProvider.value(
                  value: cubit,
                  child: RepaintBoundary(
                    key: const ValueKey('challenge-golden'),
                    child: ChallengeView(
                      organizerName: 'Synthetic organizer',
                      loadCandidatePreview: (id) async =>
                          videos.where((v) => v.id == id).firstOrNull,
                      onRecord: (_, _) async {},
                    ),
                  ),
                ),
              },
            ),
          );
          await tester.runAsync(GoogleFonts.pendingFonts);
          await tester.pumpAndSettle();
          if (screen == 'scrolled') {
            await tester.drag(
              find.byType(CustomScrollView),
              const Offset(0, -650),
            );
            await tester.pumpAndSettle();
            await tester.runAsync(GoogleFonts.pendingFonts);
            await tester.pumpAndSettle();
          }
          await expectLater(
            find.byKey(const ValueKey('challenge-golden')),
            matchesGoldenFile(
              'goldens/challenge_${screen}_${light ? 'light' : 'dark'}.png',
            ),
          );
          await tester.pumpWidget(const SizedBox());
        }, tags: ['golden']);
      }
    }
  });
}
