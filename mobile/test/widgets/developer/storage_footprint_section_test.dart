import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/storage/storage_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/storage_footprint.dart';
import 'package:openvine/services/storage_management_service.dart';
import 'package:openvine/widgets/developer/storage_footprint_section.dart';

class _MockService extends Mock implements StorageManagementService {}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  const footprint = StorageFootprint(
    roots: [
      StorageFootprintRoot(
        label: 'Documents',
        path: '/documents',
        totalBytes: 3 * 1024 * 1024,
        largestChildren: [
          StorageFootprintEntry(
            name: 'divine_1712.mp4',
            bytes: 2 * 1024 * 1024,
            isDirectory: false,
          ),
          StorageFootprintEntry(
            name: 'transition_seams',
            bytes: 1024 * 1024,
            isDirectory: true,
          ),
        ],
        childCount: 2,
      ),
    ],
  );

  late _MockService service;

  setUp(() => service = _MockService());

  Widget wrap(StorageCubit cubit) => MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: BlocProvider.value(
        value: cubit,
        child: const SingleChildScrollView(child: StorageFootprintView()),
      ),
    ),
  );

  group(StorageFootprintView, () {
    testWidgets('measuring lists every root with its biggest entries', (
      tester,
    ) async {
      when(service.measureFootprint).thenAnswer((_) async => footprint);
      final cubit = StorageCubit(service: service);
      addTearDown(cubit.close);

      await tester.pumpWidget(wrap(cubit));
      await tester.tap(
        find.widgetWithText(
          DivineButton,
          l10n.devOptionsStorageFootprintMeasure,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.devOptionsStorageFootprintTotal('3.0 MB')),
        findsOneWidget,
      );
      expect(find.text('Documents — 3.0 MB'), findsOneWidget);
      expect(find.text('divine_1712.mp4'), findsOneWidget);
      expect(find.text('transition_seams/'), findsOneWidget);
    });

    testWidgets('a failed walk says so instead of showing a stale total', (
      tester,
    ) async {
      when(service.measureFootprint).thenThrow(Exception('boom'));
      final cubit = StorageCubit(service: service);
      addTearDown(cubit.close);

      await tester.pumpWidget(wrap(cubit));
      await tester.tap(
        find.widgetWithText(
          DivineButton,
          l10n.devOptionsStorageFootprintMeasure,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.devOptionsStorageFootprintFailure), findsOneWidget);
      expect(find.text(l10n.shareSheetCopy), findsNothing);
    });

    testWidgets('copy does not claim success when the clipboard refuses it', (
      tester,
    ) async {
      when(service.measureFootprint).thenAnswer((_) async => footprint);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            switch (call.method) {
              case 'Clipboard.setData':
                return null;
              case 'Clipboard.getData':
                return null;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final cubit = StorageCubit(service: service);
      addTearDown(cubit.close);

      await tester.pumpWidget(wrap(cubit));
      await tester.tap(
        find.widgetWithText(
          DivineButton,
          l10n.devOptionsStorageFootprintMeasure,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DivineButton, l10n.shareSheetCopy));
      await tester.pumpAndSettle();

      expect(find.text(l10n.devOptionsStorageFootprintCopied), findsNothing);
    });
  });
}
