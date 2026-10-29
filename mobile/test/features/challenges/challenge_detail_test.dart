import 'dart:convert';

import 'package:challenge_protocol/challenge_protocol.dart' hide ChallengeView;
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/challenges/challenge_participation_cubit.dart';
import 'package:openvine/features/challenges/challenge_video_tile.dart';
import 'package:openvine/features/challenges/challenge_view.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/user_avatar.dart';

import '../../../packages/challenges_repository/test/harness.dart';

void main() {
  late Harness h;
  late ChallengeParticipationCubit cubit;

  void createHarness() {
    h = Harness();
    final coordinate = '31923:${h.organizer.pubkey}:synthetic:challenge';
    cubit = ChallengeParticipationCubit(
      coordinate: coordinate,
      submissions: h.repository,
      refresh: () => h.reads.refresh(coordinate),
      loadCandidates: () async => [challengeVideoModel(h.video)!],
      exactVideo: (_) async => h.video,
      clientTags: () async => [],
      prepareRecording: (_) async => 'recording',
      handoffs: () async => [],
      reviewPublished: (_) => h.prepare(),
    );
    addTearDown(cubit.close);
  }

  Future<void> open(WidgetTester tester, {bool large = false}) async {
    tester.view.physicalSize = Size(large ? 320 : 390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await cubit.load();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
          child: child!,
        ),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: ChallengeView(
            ownerName: 'Synthetic entrant',
            onRecord: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('ChallengeView interactions', () {
    testWidgets(
      'large text keeps the full entry action and organizer avatar reachable',
      (tester) async {
        createHarness();
        await open(tester, large: true);
        expect(find.byType(UserAvatar), findsOneWidget);
        expect(find.text('Enter challenge'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(h.signatures, 0);
        await tester.pumpWidget(const SizedBox());
      },
    );
    testWidgets(
      'existing source needs selection, Continue and separate consent',
      (tester) async {
        createHarness();
        await open(tester);
        await tester.tap(find.text('Enter challenge'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Choose one of your videos'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Play video'));
        await tester.pumpAndSettle();
        expect(cubit.state.review, isNull);
        expect(h.store.reviews, isEmpty);
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(cubit.state.review?.video.id, h.video.id);
        expect(h.signatures, 0);
        expect(find.text('Review your entry'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
    testWidgets('entry sources require an explicit chooser and never sign', (
      tester,
    ) async {
      createHarness();
      await open(tester);
      expect(find.text('Synthetic challenge'), findsOneWidget);
      expect(find.text('Organizer'), findsOneWidget);
      expect(find.text('Show all rules'), findsNothing);
      expect(find.text('Synthetic entrant'), findsNothing);
      expect(find.text('Record a video'), findsNothing);
      expect(find.text('Choose one of your videos'), findsNothing);
      await tester.tap(find.text('Enter challenge'));
      await tester.pumpAndSettle();
      expect(find.text('Record a video'), findsOneWidget);
      expect(find.text('Choose one of your videos'), findsOneWidget);
      expect(h.signatures, 0);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Record a video'), findsNothing);
      expect(h.signatures, 0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('closed challenge cannot start a new entry', (tester) async {
      createHarness();
      h.now = 250;
      await open(tester);
      expect(find.text('Entries closed'), findsOneWidget);
      expect(find.text('Enter challenge'), findsNothing);
      expect(find.text('Record a video'), findsNothing);
      expect(find.text('Choose one of your videos'), findsNothing);
      expect(h.signatures, 0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('cancelled challenge cannot start an entry', (tester) async {
      createHarness();
      h.definition = NostrEvent.fromJson(
        h.organizer.definition(status: 'cancelled'),
      );
      h.source.records = [jsonEncode(h.definition.toJson())];
      await open(tester);
      expect(find.text('Challenge cancelled'), findsOneWidget);
      expect(find.text('Enter challenge'), findsNothing);
      expect(h.signatures, 0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('long rules expand without preparing entry consent', (
      tester,
    ) async {
      createHarness();
      final original = h.definition.toJson();
      final rules = List.generate(60, (i) => 'Synthetic rule $i.').join('\n');
      h.definition = NostrEvent.fromJson(
        h.organizer.sign(
          tags: h.definition.tags,
          content: rules,
        ),
      );
      h.source.records = [jsonEncode(h.definition.toJson())];
      await open(tester);
      expect(tester.widget<Text>(find.text(rules)).maxLines, 6);
      await tester.ensureVisible(find.text('Show all rules'));
      await tester.tap(find.text('Show all rules'));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.text(rules)).maxLines, isNull);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(DiVineAppBar),
          matching: find.text('Synthetic challenge'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<DivineAppBarIconButton>(find.byType(DivineAppBarIconButton))
            .semanticLabel,
        'Enter challenge',
      );
      expect(h.signatures, 0);
      expect(original['id'], isNot(h.definition.id));
      await tester.pumpWidget(const SizedBox());
    });
  });
}
