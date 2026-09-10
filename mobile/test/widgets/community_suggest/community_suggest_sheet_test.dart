import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/community_suggest/community_suggest_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/l10n/localized_content_label_name.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/repositories/community_content_label_repository.dart';
import 'package:openvine/widgets/community_suggest/community_suggest_sheet.dart';

class _MockRepository extends Mock implements CommunityContentLabelRepository {}

class _MockVideoEvent extends Mock implements VideoEvent {}

void main() {
  group(CommunitySuggestView, () {
    late _MockRepository repository;
    late _MockVideoEvent video;
    late AppLocalizations l10n;
    const myPubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

    setUpAll(() {
      registerFallbackValue(_MockVideoEvent());
      registerFallbackValue(<ContentLabel>{});
      l10n = lookupAppLocalizations(const Locale('en'));
    });

    setUp(() {
      repository = _MockRepository();
      video = _MockVideoEvent();
      when(
        () => repository.mySuggestedLabels(any(), any()),
      ).thenAnswer((_) async => <String>{});
    });

    CommunitySuggestCubit buildCubit() => CommunitySuggestCubit(
      repository: repository,
      video: video,
      myPubkey: myPubkey,
    );

    Future<void> pump(WidgetTester tester, CommunitySuggestCubit cubit) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<CommunitySuggestCubit>.value(
              value: cubit,
              child: CommunitySuggestView(
                scrollController: ScrollController(),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders the title and a content label', (tester) async {
      await pump(tester, buildCubit());
      await tester.pumpAndSettle();

      expect(find.text(l10n.communitySuggestTitle), findsOneWidget);
      expect(find.text(l10n.communitySuggestSubtitle), findsOneWidget);
      expect(
        find.text(localizedContentLabelName(l10n, ContentLabel.nudity)),
        findsOneWidget,
      );
    });

    testWidgets('submit is disabled until a label is selected', (
      tester,
    ) async {
      final cubit = buildCubit();
      await pump(tester, cubit);
      await tester.pumpAndSettle();

      final button = tester.widget<DivineButton>(
        find.byType(DivineButton),
      );
      expect(button.onPressed, isNull);

      await tester.tap(
        find.text(localizedContentLabelName(l10n, ContentLabel.nudity)),
      );
      await tester.pumpAndSettle();

      final enabledButton = tester.widget<DivineButton>(
        find.byType(DivineButton),
      );
      expect(enabledButton.onPressed, isNotNull);
    });

    testWidgets('submitting publishes the selected label', (tester) async {
      when(
        () => repository.suggestLabels(
          video: any(named: 'video'),
          labels: any(named: 'labels'),
        ),
      ).thenAnswer((_) async {});
      final cubit = buildCubit();
      await pump(tester, cubit);
      await tester.pumpAndSettle();

      await tester.tap(
        find.text(localizedContentLabelName(l10n, ContentLabel.nudity)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.communitySuggestSubmit));
      await tester.pumpAndSettle();

      verify(
        () => repository.suggestLabels(
          video: any(named: 'video'),
          labels: {ContentLabel.nudity},
        ),
      ).called(1);
    });

    testWidgets('shows the already-suggested badge for prior suggestions', (
      tester,
    ) async {
      when(
        () => repository.mySuggestedLabels(any(), any()),
      ).thenAnswer((_) async => {'nudity'});
      final cubit = buildCubit()..loadExisting();
      await pump(tester, cubit);
      await tester.pumpAndSettle();

      expect(find.text(l10n.communitySuggestAlready), findsOneWidget);
    });
  });
}
