import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_crosspost/video_crosspost_cubit.dart';
import 'package:openvine/blocs/video_crosspost/video_crosspost_state.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/services/crossposting_api_client.dart';
import 'package:openvine/widgets/crosspost_sheet.dart';

class _MockVideoCrosspostCubit extends MockCubit<VideoCrosspostState>
    implements VideoCrosspostCubit {}

void main() {
  group(CrosspostSheetView, () {
    late _MockVideoCrosspostCubit cubit;

    final l10n = lookupAppLocalizations(const Locale('en'));

    const instagramConnection = CrosspostingConnection(
      id: 'conn-1',
      platform: CrosspostingPlatform.instagram,
      status: CrosspostingConnectionStatus.connected,
      externalAccountName: 'divine.creator',
    );

    setUp(() {
      cubit = _MockVideoCrosspostCubit();
    });

    Future<void> pumpSheet(WidgetTester tester) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<VideoCrosspostCubit>.value(
              value: cubit,
              child: const CrosspostSheetView(),
            ),
          ),
        ),
      );
    }

    testWidgets('renders connected platform with account name and submits '
        'on tap', (tester) async {
      when(() => cubit.state).thenReturn(
        const VideoCrosspostState(
          status: VideoCrosspostStatus.ready,
          connections: [instagramConnection],
          selectedPlatforms: {'instagram'},
        ),
      );
      when(() => cubit.submit()).thenAnswer((_) async {});

      await pumpSheet(tester);

      expect(find.text('Instagram'), findsOneWidget);
      expect(find.text('divine.creator'), findsOneWidget);

      await tester.tap(find.text(l10n.crosspostSubmit));
      await tester.pump();

      verify(() => cubit.submit()).called(1);
    });

    testWidgets('toggles a platform when its row is tapped', (tester) async {
      when(() => cubit.state).thenReturn(
        const VideoCrosspostState(
          status: VideoCrosspostStatus.ready,
          connections: [instagramConnection],
          selectedPlatforms: {'instagram'},
        ),
      );

      await pumpSheet(tester);
      await tester.tap(find.text('Instagram'));
      await tester.pump();

      verify(() => cubit.togglePlatform('instagram')).called(1);
    });

    testWidgets('shows progress and queued label while polling', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        const VideoCrosspostState(
          status: VideoCrosspostStatus.polling,
          jobs: [
            CrosspostJob(
              id: 'job-1',
              platform: 'instagram',
              status: CrosspostJobStatus.queued,
            ),
          ],
        ),
      );

      await pumpSheet(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(l10n.crosspostStatusQueued), findsOneWidget);
    });

    testWidgets('shows tappable permalink for a posted job', (tester) async {
      when(() => cubit.state).thenReturn(
        const VideoCrosspostState(
          status: VideoCrosspostStatus.finished,
          jobs: [
            CrosspostJob(
              id: 'job-1',
              platform: 'instagram',
              status: CrosspostJobStatus.posted,
              externalPostUrl: 'https://www.instagram.com/reel/abc/',
            ),
          ],
        ),
      );

      await pumpSheet(tester);

      expect(find.text(l10n.crosspostStatusPosted), findsOneWidget);
      expect(find.text(l10n.crosspostViewPost), findsOneWidget);
    });

    testWidgets('shows localized generic text for an unmapped failed job', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        const VideoCrosspostState(
          status: VideoCrosspostStatus.finished,
          jobs: [
            CrosspostJob(
              id: 'job-1',
              platform: 'instagram',
              status: CrosspostJobStatus.failed,
              errorCode: 'media_rejected',
              errorMessage: 'Instagram rejected the media',
            ),
          ],
        ),
      );

      await pumpSheet(tester);

      expect(find.text(l10n.crosspostStatusFailed), findsOneWidget);
      expect(find.text(l10n.crosspostFailedGeneric), findsOneWidget);
      expect(find.text('Instagram rejected the media'), findsNothing);
    });

    testWidgets('shows localized text for a mapped failed job', (tester) async {
      when(() => cubit.state).thenReturn(
        const VideoCrosspostState(
          status: VideoCrosspostStatus.finished,
          jobs: [
            CrosspostJob(
              id: 'job-1',
              platform: 'instagram',
              status: CrosspostJobStatus.failed,
              errorCode: 'not_eligible',
              errorMessage: 'Server copy must not render',
            ),
          ],
        ),
      );

      await pumpSheet(tester);

      expect(find.text(l10n.crosspostErrorNotEligible), findsOneWidget);
      expect(find.text('Server copy must not render'), findsNothing);
    });

    testWidgets('prompts to reconnect on a needs_reauth job', (tester) async {
      when(() => cubit.state).thenReturn(
        const VideoCrosspostState(
          status: VideoCrosspostStatus.finished,
          jobs: [
            CrosspostJob(
              id: 'job-1',
              platform: 'instagram',
              status: CrosspostJobStatus.needsReauth,
              errorCode: 'needs_reauth',
            ),
          ],
        ),
      );

      await pumpSheet(tester);

      expect(
        find.text(l10n.crosspostReconnectPrompt('Instagram')),
        findsOneWidget,
      );
      expect(find.text(l10n.crosspostReconnect), findsOneWidget);
    });

    testWidgets('shows still-working note when polling timed out', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        const VideoCrosspostState(
          status: VideoCrosspostStatus.finished,
          pollTimedOut: true,
          jobs: [
            CrosspostJob(
              id: 'job-1',
              platform: 'instagram',
              status: CrosspostJobStatus.processing,
            ),
          ],
        ),
      );

      await pumpSheet(tester);

      expect(find.text(l10n.crosspostStillWorking), findsOneWidget);
    });

    testWidgets('shows mapped error copy after a failed submit', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        const VideoCrosspostState(
          status: VideoCrosspostStatus.submitFailed,
          connections: [instagramConnection],
          selectedPlatforms: {'instagram'},
          submitError: VideoCrosspostSubmitError.notEligible,
        ),
      );

      await pumpSheet(tester);

      expect(find.text(l10n.crosspostErrorNotEligible), findsOneWidget);
    });

    testWidgets('shows reconnect copy after unauthorized submit', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        const VideoCrosspostState(
          status: VideoCrosspostStatus.submitFailed,
          connections: [instagramConnection],
          selectedPlatforms: {'instagram'},
          submitError: VideoCrosspostSubmitError.unauthorized,
        ),
      );

      await pumpSheet(tester);

      expect(find.text(l10n.crosspostErrorUnauthorized), findsOneWidget);
    });
  });
}
