import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_crosspost/video_crosspost_cubit.dart';
import 'package:openvine/blocs/video_crosspost/video_crosspost_state.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/crossposting_providers.dart';
import 'package:openvine/repositories/crossposting_repository.dart';
import 'package:openvine/services/crossposting_api_client.dart';
import 'package:openvine/widgets/crosspost_sheet.dart';

class _MockVideoCrosspostCubit extends MockCubit<VideoCrosspostState>
    implements VideoCrosspostCubit {}

class _MockCrosspostingApiClient extends Mock
    implements CrosspostingApiClient {}

/// Copies [jobs] into new instances, like each decoded poll response.
List<CrosspostJob> _decoded(List<CrosspostJob> jobs) => [
  for (final job in jobs)
    CrosspostJob(
      id: job.id,
      platform: job.platform,
      status: job.status,
      externalPostUrl: job.externalPostUrl,
      errorCode: job.errorCode,
      errorMessage: job.errorMessage,
    ),
];

void main() {
  group('showCrosspostSheetForEvent', () {
    const eventId =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const connection = CrosspostingConnection(
      id: 'connection-1',
      platform: CrosspostingPlatform.instagram,
      status: CrosspostingConnectionStatus.connected,
    );
    final l10n = lookupAppLocalizations(const Locale('en'));
    late _MockCrosspostingApiClient client;
    late ProviderContainer container;
    late Completer<List<CrosspostJob>> response;
    late bool sheetClosed;
    late int interactions;

    setUp(() {
      client = _MockCrosspostingApiClient();
      sheetClosed = false;
      interactions = 0;
      when(
        () => client.createCrossposts(
          eventId: eventId,
          platforms: ['instagram'],
        ),
      ).thenAnswer((_) => response.future);
      container = ProviderContainer(
        overrides: [
          crosspostingRepositoryProvider.overrideWithValue(
            CrosspostingRepository(client),
          ),
        ],
      );
    });

    tearDown(() => container.dispose());

    Future<void> openSheet(WidgetTester tester) async {
      response = Completer<List<CrosspostJob>>();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    TextButton(
                      onPressed: () async {
                        await showCrosspostSheetForEvent(
                          context: context,
                          container: container,
                          eventId: eventId,
                          connections: [connection],
                        );
                        sheetClosed = true;
                      },
                      child: const Text('Open crosspost'),
                    ),
                    TextButton(
                      onPressed: () => interactions++,
                      child: const Text('Keep browsing'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open crosspost'));
      await tester.pumpAndSettle();
    }

    testWidgets('dismisses and acknowledges before the request completes', (
      tester,
    ) async {
      await openSheet(tester);
      await tester.tap(find.text(l10n.crosspostSubmit));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(response.isCompleted, isFalse);
      expect(sheetClosed, isTrue);
      expect(find.byType(CrosspostSheetView), findsNothing);
      expect(find.text(l10n.crosspostStarted), findsOneWidget);
      await tester.tap(find.text('Keep browsing'));
      await tester.pump();
      expect(interactions, 1);

      response.complete(const [
        CrosspostJob(
          id: 'job-1',
          platform: 'instagram',
          status: CrosspostJobStatus.queued,
        ),
      ]);
      when(() => client.getCrossposts(eventId: eventId)).thenAnswer(
        (_) async => const [
          CrosspostJob(
            id: 'job-1',
            platform: 'instagram',
            status: CrosspostJobStatus.posted,
          ),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
      verify(() => client.getCrossposts(eventId: eventId)).called(1);
    });

    testWidgets('reports a platform failure while another job is pending', (
      tester,
    ) async {
      await openSheet(tester);
      await tester.tap(find.text(l10n.crosspostSubmit));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(sheetClosed, isTrue);
      const jobs = [
        CrosspostJob(
          id: 'job-1',
          platform: 'instagram',
          status: CrosspostJobStatus.failed,
          errorCode: 'not_eligible',
        ),
        CrosspostJob(
          id: 'job-2',
          platform: 'tiktok',
          status: CrosspostJobStatus.processing,
        ),
      ];
      // Each poll decodes new job objects, as the API client does, so every
      // poll emits a state and only the notified-job set prevents a repeat.
      when(() => client.getCrossposts(eventId: eventId)).thenAnswer(
        (_) async => _decoded(jobs),
      );
      response.complete(jobs);
      await tester.pumpAndSettle();
      expect(
        find.text('Instagram: ${l10n.crosspostErrorNotEligible}'),
        findsOneWidget,
      );
      await tester.tap(find.text('Keep browsing'));
      expect(interactions, 1);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(SnackBar), findsNothing);
      // The same failed job must not produce another notification each poll.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.byType(SnackBar), findsNothing);
      when(() => client.getCrossposts(eventId: eventId)).thenAnswer(
        (_) async => _decoded([
          jobs.first,
          const CrosspostJob(
            id: 'job-2',
            platform: 'tiktok',
            status: CrosspostJobStatus.failed,
            errorCode: 'not_owner',
          ),
        ]),
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(
        find.text('TikTok: ${l10n.crosspostErrorNotOwner}'),
        findsOneWidget,
      );
    });

    testWidgets('prompts to reconnect a needs-reauth job once', (
      tester,
    ) async {
      await openSheet(tester);
      await tester.tap(find.text(l10n.crosspostSubmit));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      const jobs = [
        CrosspostJob(
          id: 'job-1',
          platform: 'instagram',
          status: CrosspostJobStatus.needsReauth,
        ),
        CrosspostJob(
          id: 'job-2',
          platform: 'tiktok',
          status: CrosspostJobStatus.processing,
        ),
      ];
      when(() => client.getCrossposts(eventId: eventId)).thenAnswer(
        (_) async => _decoded(jobs),
      );
      response.complete(jobs);
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.crosspostReconnectPrompt('Instagram')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(SnackBar), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      verify(
        () => client.getCrossposts(eventId: eventId),
      ).called(greaterThan(1));
      expect(find.byType(SnackBar), findsNothing);
      when(() => client.getCrossposts(eventId: eventId)).thenAnswer(
        (_) async => _decoded([
          jobs.first,
          const CrosspostJob(
            id: 'job-2',
            platform: 'tiktok',
            status: CrosspostJobStatus.posted,
          ),
        ]),
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
    });

    testWidgets('reports a background submission failure after dismissal', (
      tester,
    ) async {
      await openSheet(tester);
      await tester.tap(find.text(l10n.crosspostSubmit));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(sheetClosed, isTrue);

      response.completeError(
        const CrosspostingApiException(
          'Not eligible',
          statusCode: 422,
          code: 'not_eligible',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.crosspostErrorNotEligible), findsOneWidget);
      expect(find.byType(CrosspostSheetView), findsNothing);
    });
  });

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
          localizationsDelegates: appLocalizationsDelegates,
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

    testWidgets('reconnect runs the supplied callback', (tester) async {
      var reconnected = false;
      when(() => cubit.state).thenReturn(
        const VideoCrosspostState(
          status: VideoCrosspostStatus.finished,
          jobs: [
            CrosspostJob(
              id: 'job-1',
              platform: 'instagram',
              status: CrosspostJobStatus.needsReauth,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<VideoCrosspostCubit>.value(
              value: cubit,
              child: CrosspostSheetView(onReconnect: () => reconnected = true),
            ),
          ),
        ),
      );

      await tester.tap(find.text(l10n.crosspostReconnect));
      await tester.pump();

      expect(reconnected, isTrue);
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
