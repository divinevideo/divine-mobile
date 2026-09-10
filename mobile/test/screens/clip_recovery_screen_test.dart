// ABOUTME: Widget tests for the developer clip-recovery screen.

import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/clip_recovery/clip_recovery_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/clip_recovery.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/screens/clip_recovery_screen.dart';
import 'package:openvine/services/clip_recovery_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockService extends Mock implements ClipRecoveryService {}

const _hiddenOwner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

final _rebuiltClip = DivineVideoClip(
  id: 'recovered_VID_20260101_090001',
  video: EditorVideo.file(File('/documents/VID_20260101_090001.mp4')),
  duration: const Duration(milliseconds: 6033),
  recordedAt: DateTime(2026, 8, 17),
  targetAspectRatio: model.AspectRatio.vertical,
  originalAspectRatio: 9 / 16,
);

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  late _MockService service;

  setUp(() => service = _MockService());

  Widget wrap(ClipRecoveryCubit cubit) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider.value(value: cubit, child: const ClipRecoveryView()),
  );

  OrphanClipFile orphan(int index, {Duration? duration}) => OrphanClipFile(
    path: '/documents/VID_2026010${index}_090000.mp4',
    sizeBytes: 1024 * index,
    modifiedAt: DateTime(2026, 8, 17),
    duration: duration,
  );

  group(ClipRecoveryView, () {
    testWidgets('shows a hidden owner with its untruncated pubkey', (
      tester,
    ) async {
      when(service.scanRecoverableClips).thenAnswer(
        (_) async => const ClipRecoveryReport(
          currentOwnerPubkey: 'bb',
          ownedClipCount: 0,
          ownedDraftCount: 0,
          foreignGroups: [
            ClipOwnerGroup(
              ownerPubkey: _hiddenOwner,
              clipCount: 12,
              draftCount: 2,
            ),
          ],
          orphanFiles: [],
        ),
      );
      final cubit = ClipRecoveryCubit(service: service);
      addTearDown(cubit.close);

      await tester.pumpWidget(wrap(cubit));
      await tester.tap(find.text(l10n.devOptionsClipRecoveryScan));
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.devOptionsClipRecoveryOtherAccounts),
        findsOneWidget,
      );
      // The operator hands another account's rows over based on this value, so
      // it has to be readable in full.
      expect(find.text(_hiddenOwner), findsOneWidget);
      expect(
        find.text(l10n.devOptionsClipRecoveryCounts(12, 2)),
        findsOneWidget,
      );
      expect(find.text(l10n.devOptionsClipRecoveryClaim), findsOneWidget);
    });

    testWidgets('restores only the file whose button was tapped', (
      tester,
    ) async {
      final wanted = OrphanClipFile(
        path: '/documents/VID_20260101_090001.mp4',
        sizeBytes: 2 * 1024 * 1024,
        modifiedAt: DateTime(2026, 8, 17),
        duration: const Duration(milliseconds: 6033),
      );
      final other = orphan(2);
      when(service.scanRecoverableClips).thenAnswer(
        (_) async => ClipRecoveryReport(
          currentOwnerPubkey: 'bb',
          ownedClipCount: 0,
          ownedDraftCount: 0,
          foreignGroups: const [],
          orphanFiles: [wanted, other],
        ),
      );
      when(
        () => service.importOrphanFiles(any()),
      ).thenAnswer((_) async => [_rebuiltClip]);
      final cubit = ClipRecoveryCubit(service: service);
      addTearDown(cubit.close);

      await tester.pumpWidget(wrap(cubit));
      await tester.tap(find.text(l10n.devOptionsClipRecoveryScan));
      await tester.pumpAndSettle();

      expect(find.text(wanted.name), findsOneWidget);
      // Size and length let the operator tell two recordings apart before
      // restoring one; a file that would not decode shows the size alone.
      expect(find.text('2.0 MB · 6.0s'), findsOneWidget);
      expect(find.text('2.0 KB'), findsOneWidget);

      await tester.tap(find.text(l10n.devOptionsClipRecoveryImport).first);
      await tester.pumpAndSettle();

      verify(() => service.importOrphanFiles([wanted])).called(1);
    });

    testWidgets('builds orphan rows lazily so a long list stays cheap', (
      tester,
    ) async {
      // The whole reason this is a screen rather than a section: a database
      // reset can strand hundreds of recordings, each row decoding its own
      // preview frame.
      when(service.scanRecoverableClips).thenAnswer(
        (_) async => ClipRecoveryReport(
          currentOwnerPubkey: 'bb',
          ownedClipCount: 0,
          ownedDraftCount: 0,
          foreignGroups: const [],
          orphanFiles: [for (var i = 1; i <= 200; i++) orphan(i)],
        ),
      );
      final cubit = ClipRecoveryCubit(service: service);
      addTearDown(cubit.close);

      await tester.pumpWidget(wrap(cubit));
      await tester.tap(find.text(l10n.devOptionsClipRecoveryScan));
      await tester.pumpAndSettle();

      final built = find
          .text(l10n.devOptionsClipRecoveryImport)
          .evaluate()
          .length;
      expect(built, greaterThan(0), reason: 'the first rows render');
      expect(
        built,
        lessThan(200),
        reason: 'offscreen rows are not built at all',
      );
    });

    testWidgets('keeps the findings on screen when an action fails', (
      tester,
    ) async {
      // The report is what the operator copies into the support thread, and the
      // unreferenced-file rows stay listed regardless — hiding only the summary
      // would leave the two halves of the screen contradicting each other.
      final stranded = orphan(1, duration: const Duration(seconds: 4));
      when(service.scanRecoverableClips).thenAnswer(
        (_) async => ClipRecoveryReport(
          currentOwnerPubkey: 'bb',
          ownedClipCount: 4,
          ownedDraftCount: 1,
          foreignGroups: const [],
          orphanFiles: [stranded],
        ),
      );
      when(
        () => service.importOrphanFiles(any()),
      ).thenThrow(StateError('write failed'));
      final cubit = ClipRecoveryCubit(service: service);
      addTearDown(cubit.close);

      await tester.pumpWidget(wrap(cubit));
      await tester.tap(find.text(l10n.devOptionsClipRecoveryScan));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.devOptionsClipRecoveryImport));
      await tester.pumpAndSettle();

      expect(find.text(l10n.devOptionsClipRecoveryFailure), findsOneWidget);
      expect(
        find.text(l10n.devOptionsClipRecoveryVisible(4, 1)),
        findsOneWidget,
      );
      expect(find.text(stranded.name), findsOneWidget);
      // "Recovered 0 clips" next to a failure would contradict it.
      expect(find.text(l10n.devOptionsClipRecoveryRecovered(0)), findsNothing);
      // The copy action is how the report leaves the device; a failed action is
      // exactly when it is wanted.
      expect(find.text(l10n.shareSheetCopy), findsOneWidget);
    });

    testWidgets('says so when there is nothing to recover', (tester) async {
      when(service.scanRecoverableClips).thenAnswer(
        (_) async => const ClipRecoveryReport(
          currentOwnerPubkey: 'bb',
          ownedClipCount: 4,
          ownedDraftCount: 1,
          foreignGroups: [],
          orphanFiles: [],
        ),
      );
      final cubit = ClipRecoveryCubit(service: service);
      addTearDown(cubit.close);

      await tester.pumpWidget(wrap(cubit));
      await tester.tap(find.text(l10n.devOptionsClipRecoveryScan));
      await tester.pumpAndSettle();

      expect(find.text(l10n.devOptionsClipRecoveryEmpty), findsOneWidget);
      expect(
        find.text(l10n.devOptionsClipRecoveryVisible(4, 1)),
        findsOneWidget,
      );
    });
  });
}
