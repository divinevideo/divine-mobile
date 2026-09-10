// ABOUTME: Widget tests for the home feed's failure state.
// ABOUTME: Pins that it distinguishes our outage from the user's network.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/outage_notice/outage_notice_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/outage_diagnosis_provider.dart';
import 'package:openvine/screens/feed/video_feed_page/feed_error_widget.dart';
import 'package:openvine/services/outage_diagnosis_service.dart';

class _MockOutageNoticeCubit extends MockCubit<OutageNoticeState>
    implements OutageNoticeCubit {}

class _MockOutageDiagnosisService extends Mock
    implements OutageDiagnosisService {}

void main() {
  group(FeedErrorWidget, () {
    testWidgets('starts diagnosis when mounted', (tester) async {
      final diagnosisService = _MockOutageDiagnosisService();
      when(
        () => diagnosisService.diagnose(
          components: any(named: 'components'),
        ),
      ).thenAnswer((_) async => OutageDiagnosis.indeterminate);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            outageDiagnosisServiceProvider.overrideWithValue(diagnosisService),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: FeedErrorWidget(onRetry: () async {})),
          ),
        ),
      );
      await tester.pump();

      verify(
        () => diagnosisService.diagnose(
          components: any(named: 'components'),
        ),
      ).called(1);
    });

    testWidgets('starts a fresh diagnosis when the service changes', (
      tester,
    ) async {
      final firstService = _MockOutageDiagnosisService();
      final secondService = _MockOutageDiagnosisService();
      for (final service in [firstService, secondService]) {
        when(
          () => service.diagnose(components: any(named: 'components')),
        ).thenAnswer((_) async => OutageDiagnosis.indeterminate);
      }

      Future<void> pumpWithService(OutageDiagnosisService service) {
        return tester.pumpWidget(
          ProviderScope(
            overrides: [
              outageDiagnosisServiceProvider.overrideWithValue(service),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: FeedErrorWidget(onRetry: () async {})),
            ),
          ),
        );
      }

      await pumpWithService(firstService);
      await tester.pump();
      await pumpWithService(secondService);
      await tester.pump();

      verify(
        () => firstService.diagnose(components: any(named: 'components')),
      ).called(1);
      verify(
        () => secondService.diagnose(components: any(named: 'components')),
      ).called(1);
    });
  });

  group(FeedErrorView, () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    late _MockOutageNoticeCubit cubit;

    setUp(() {
      cubit = _MockOutageNoticeCubit();
    });

    Future<void> pumpWith(WidgetTester tester, OutageNoticeState state) {
      when(() => cubit.state).thenReturn(state);
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<OutageNoticeCubit>.value(
              value: cubit,
              child: FeedErrorView(onRetry: () async {}),
            ),
          ),
        ),
      );
    }

    testWidgets('stays generic while the diagnosis is still running', (
      tester,
    ) async {
      // Blaming ourselves before we know, then flipping to "you're offline",
      // is worse than one honest generic line.
      await pumpWith(tester, const OutageNoticeState());

      expect(find.text(l10n.feedFailedToLoadVideos), findsOneWidget);
      expect(find.text(l10n.feedOutageMessage), findsNothing);
    });

    testWidgets('says the fault is ours on a corroborated outage', (
      tester,
    ) async {
      await pumpWith(
        tester,
        const OutageNoticeState(status: OutageNoticeStatus.divineOutage),
      );

      expect(find.text(l10n.feedOutageMessage), findsOneWidget);
    });

    testWidgets('prefers the operator message over canned copy', (
      tester,
    ) async {
      await pumpWith(
        tester,
        const OutageNoticeState(
          status: OutageNoticeStatus.divineOutage,
          operatorMessage: 'Feed degraded, fix rolling out.',
        ),
      );

      expect(find.text('Feed degraded, fix rolling out.'), findsOneWidget);
      expect(find.text(l10n.feedOutageMessage), findsNothing);
    });

    testWidgets('points at the connection when nothing is reachable', (
      tester,
    ) async {
      await pumpWith(
        tester,
        const OutageNoticeState(status: OutageNoticeStatus.noConnection),
      );

      expect(find.text(l10n.feedOfflineMessage), findsOneWidget);
    });

    testWidgets('claims nothing when the status page reports health', (
      tester,
    ) async {
      await pumpWith(
        tester,
        const OutageNoticeState(status: OutageNoticeStatus.indeterminate),
      );

      expect(find.text(l10n.feedFailedToLoadVideos), findsOneWidget);
      expect(find.text(l10n.feedOutageMessage), findsNothing);
      expect(find.text(l10n.feedOfflineMessage), findsNothing);
    });

    testWidgets('never renders a raw enum name', (tester) async {
      // The previous implementation printed error.toString(), putting
      // "VideoFeedError.loadFailed" on screen for users.
      await pumpWith(
        tester,
        const OutageNoticeState(status: OutageNoticeStatus.indeterminate),
      );

      expect(find.textContaining('VideoFeedError'), findsNothing);
    });

    testWidgets('retries when the button is tapped', (tester) async {
      var retried = false;
      when(() => cubit.state).thenReturn(const OutageNoticeState());
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<OutageNoticeCubit>.value(
              value: cubit,
              child: FeedErrorView(
                onRetry: () async {
                  retried = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text(l10n.feedRetry));
      await tester.pump();

      expect(retried, isTrue);
    });
  });
}
