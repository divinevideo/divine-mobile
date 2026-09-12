import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/shorebird_patch/shorebird_patch_cubit.dart';
import 'package:openvine/blocs/shorebird_patch/shorebird_patch_state.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/developer_options/shorebird_patch_section.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockShorebirdPatchCubit extends MockCubit<ShorebirdPatchState>
    implements ShorebirdPatchCubit {}

void main() {
  group(ShorebirdPatchView, () {
    late _MockShorebirdPatchCubit cubit;
    late AppLocalizations l10n;

    setUp(() {
      cubit = _MockShorebirdPatchCubit();
      when(() => cubit.checkStagingTrack()).thenAnswer((_) async {});
      when(() => cubit.applyStagedPatch()).thenAnswer((_) async {});
      when(() => cubit.useStableTrack()).thenAnswer((_) async {});
      l10n = lookupAppLocalizations(const Locale('en'));
    });

    Future<void> pumpWith(
      WidgetTester tester,
      ShorebirdPatchState state,
    ) async {
      whenListen(
        cubit,
        const Stream<ShorebirdPatchState>.empty(),
        initialState: state,
      );
      await tester.pumpWidget(
        testMaterialApp(
          home: BlocProvider<ShorebirdPatchCubit>.value(
            value: cubit,
            child: const Scaffold(body: ShorebirdPatchView()),
          ),
        ),
      );
    }

    final subtitles =
        <ShorebirdPatchValidationStatus, String Function(AppLocalizations)>{
          ShorebirdPatchValidationStatus.loading: (l) =>
              l.devOptionsShorebirdLoading,
          ShorebirdPatchValidationStatus.notChecked: (l) =>
              l.devOptionsShorebirdNotChecked,
          ShorebirdPatchValidationStatus.unavailable: (l) =>
              l.devOptionsShorebirdUnavailableSubtitle,
          ShorebirdPatchValidationStatus.checking: (l) =>
              l.devOptionsShorebirdChecking,
          ShorebirdPatchValidationStatus.updateAvailable: (l) =>
              l.devOptionsShorebirdUpdateAvailable,
          ShorebirdPatchValidationStatus.upToDate: (l) =>
              l.devOptionsShorebirdUpToDate,
          ShorebirdPatchValidationStatus.restartRequired: (l) =>
              l.devOptionsShorebirdRestartRequired,
          ShorebirdPatchValidationStatus.rollbackRequired: (l) =>
              l.devOptionsShorebirdRollbackRequired,
          ShorebirdPatchValidationStatus.applying: (l) =>
              l.devOptionsShorebirdApplying,
          ShorebirdPatchValidationStatus.applied: (l) =>
              l.devOptionsShorebirdApplied,
          ShorebirdPatchValidationStatus.unchanged: (l) =>
              l.devOptionsShorebirdUnchanged,
          ShorebirdPatchValidationStatus.selectingStableTrack: (l) =>
              l.devOptionsShorebirdSelectingStableTrack,
          ShorebirdPatchValidationStatus.stableRestored: (l) =>
              l.devOptionsShorebirdStableRestored,
          ShorebirdPatchValidationStatus.failure: (l) =>
              l.devOptionsShorebirdFailure,
        };

    for (final entry in subtitles.entries) {
      testWidgets('renders the ${entry.key.name} result', (tester) async {
        await pumpWith(tester, ShorebirdPatchState(status: entry.key));
        expect(find.text(entry.value(l10n)), findsOneWidget);
      });
    }

    testWidgets('shows the running patch number', (tester) async {
      await pumpWith(
        tester,
        const ShorebirdPatchState(
          status: ShorebirdPatchValidationStatus.notChecked,
          currentPatchNumber: 4,
        ),
      );
      expect(find.text(l10n.devOptionsShorebirdPatchLabel), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('Apply is disabled until a staged patch is available', (
      tester,
    ) async {
      await pumpWith(
        tester,
        const ShorebirdPatchState(
          status: ShorebirdPatchValidationStatus.notChecked,
        ),
      );
      await tester.tap(find.text(l10n.devOptionsShorebirdApply));
      await tester.pump();
      verifyNever(() => cubit.applyStagedPatch());
    });

    testWidgets('both actions are disabled when the updater is unavailable', (
      tester,
    ) async {
      await pumpWith(
        tester,
        const ShorebirdPatchState(
          status: ShorebirdPatchValidationStatus.unavailable,
        ),
      );
      await tester.tap(find.text(l10n.devOptionsShorebirdCheck));
      await tester.tap(find.text(l10n.devOptionsShorebirdApply));
      await tester.pump();
      verifyNever(() => cubit.checkStagingTrack());
      verifyNever(() => cubit.applyStagedPatch());
    });

    testWidgets('Check invokes the cubit when idle', (tester) async {
      await pumpWith(
        tester,
        const ShorebirdPatchState(
          status: ShorebirdPatchValidationStatus.notChecked,
        ),
      );
      await tester.tap(find.text(l10n.devOptionsShorebirdCheck));
      await tester.pump();
      verify(() => cubit.checkStagingTrack()).called(1);
    });

    testWidgets('Apply invokes the cubit after a successful check', (
      tester,
    ) async {
      await pumpWith(
        tester,
        const ShorebirdPatchState(
          status: ShorebirdPatchValidationStatus.updateAvailable,
        ),
      );
      await tester.tap(find.text(l10n.devOptionsShorebirdApply));
      await tester.pump();
      verify(() => cubit.applyStagedPatch()).called(1);
    });

    testWidgets('staging subscription exposes the return-to-stable action', (
      tester,
    ) async {
      await pumpWith(
        tester,
        const ShorebirdPatchState(
          status: ShorebirdPatchValidationStatus.applied,
          usesStagingTrack: true,
        ),
      );
      await tester.tap(find.text(l10n.devOptionsShorebirdUseStable));
      await tester.pump();
      verify(() => cubit.useStableTrack()).called(1);
    });
  });
}
