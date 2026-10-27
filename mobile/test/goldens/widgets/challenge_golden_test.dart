import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/challenges/challenge_participation_cubit.dart';
import 'package:openvine/features/challenges/challenge_view.dart';
import 'package:openvine/l10n/l10n.dart';

import '../../../packages/challenges_repository/test/harness.dart';

void main() {
  group('challenge_golden', () {
    for (final light in [false, true]) {
      testWidgets('challenge ${light ? 'light' : 'dark'}', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
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
            theme: light ? VineTheme.lightTheme : VineTheme.theme,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider.value(
              value: cubit,
              child: RepaintBoundary(
                key: const ValueKey('challenge-golden'),
                child: ChallengeView(onRecord: (_, _) async {}),
              ),
            ),
          ),
        );
        await tester.runAsync(GoogleFonts.pendingFonts);
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const ValueKey('challenge-golden')),
          matchesGoldenFile(
            'goldens/challenge_${light ? 'light' : 'dark'}.png',
          ),
        );
        await tester.pumpWidget(const SizedBox());
      }, tags: ['golden']);
    }
  });
}
