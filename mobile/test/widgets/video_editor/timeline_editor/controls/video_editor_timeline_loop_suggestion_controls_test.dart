import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_alignment_repository/loop_alignment_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/loop_suggestion/loop_suggestion_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_loop_repair_listener.dart';

class _Repository extends Mock implements LoopAlignmentRepository {}

/// A cubit whose repairs stay in flight until [gate] completes.
({
  LoopSuggestionCubit cubit,
  LoopRepairInput input,
  Completer<LoopRepairResult> gate,
})
_cubitWithPendingRepair() {
  final repository = _Repository();
  final input = LoopRepairInput(clips: const [], revision: 'one');
  registerFallbackValue(input);
  final gate = Completer<LoopRepairResult>();
  when(
    () => repository.repair(
      any(),
      taskId: any(named: 'taskId'),
      onProgress: any(named: 'onProgress'),
    ),
  ).thenAnswer((_) => gate.future);
  when(() => repository.cancel(any())).thenAnswer((_) async {});
  final cubit = LoopSuggestionCubit(repository: repository);
  addTearDown(cubit.close);
  return (cubit: cubit, input: input, gate: gate);
}

void main() {
  group('LoopRepairProgressOverlay interactions', () {
    testWidgets(
      'busy repair exposes accessible progress and cancels immediately',
      (tester) async {
        final (:cubit, :input, :gate) = _cubitWithPendingRepair();
        final operation = cubit.fix(input);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: BlocProvider.value(
                value: cubit,
                child: const LoopRepairProgressOverlay(),
              ),
            ),
          ),
        );
        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.commonCancel), findsOneWidget);
        expect(
          find.text(l10n.videoEditorLoopRepairProgress),
          findsOneWidget,
        );
        await tester.tap(find.text(l10n.commonCancel));
        await tester.pump();
        expect(cubit.state.status, LoopSuggestionStatus.idle);
        expect(
          find.text(l10n.videoEditorLoopRepairProgress),
          findsNothing,
        );
        gate.complete(const LoopRepairResult(status: .noMatch));
        await operation;
      },
    );

    testWidgets(
      'hides the editor from screen readers but keeps Cancel usable',
      (tester) async {
        final (:cubit, :input, :gate) = _cubitWithPendingRepair();
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: BlocProvider.value(
                value: cubit,
                child: Stack(
                  children: [
                    Center(
                      child: TextButton(
                        onPressed: () {},
                        child: const Text('open'),
                      ),
                    ),
                    const LoopRepairProgressOverlay(),
                  ],
                ),
              ),
            ),
          ),
        );
        expect(find.semantics.byLabel('open'), findsOne);

        final operation = cubit.fix(input);
        await tester.pump();
        expect(find.semantics.byLabel('open'), findsNothing);

        final l10n = lookupAppLocalizations(const Locale('en'));
        tester.semantics.tap(find.semantics.byLabel(l10n.commonCancel));
        await tester.pump();

        expect(cubit.state.status, LoopSuggestionStatus.idle);
        gate.complete(const LoopRepairResult(status: .noMatch));
        await operation;
      },
    );
  });
}
