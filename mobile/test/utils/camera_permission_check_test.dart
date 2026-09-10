// ABOUTME: Tests for pushToCameraWithPermission extension on BuildContext
// ABOUTME: Verifies the native permission request fires on the current page

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/camera_permission/camera_permission_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/utils/camera_permission_check.dart';

import '../helpers/go_router.dart';

class _FakeCameraPermissionBloc extends Fake implements CameraPermissionBloc {
  _FakeCameraPermissionBloc(CameraPermissionState initialState)
    : _state = initialState;

  final _controller = StreamController<CameraPermissionState>.broadcast();
  final addedEvents = <CameraPermissionEvent>[];
  CameraPermissionState _state;

  @override
  CameraPermissionState get state => _state;

  @override
  Stream<CameraPermissionState> get stream => _controller.stream;

  @override
  void add(CameraPermissionEvent event) {
    addedEvents.add(event);
  }

  void emitState(CameraPermissionState newState) {
    _state = newState;
    _controller.add(newState);
  }

  @override
  bool get isClosed => false;

  @override
  Future<void> close() async {
    await _controller.close();
  }
}

void main() {
  late MockGoRouter mockGoRouter;

  setUp(() {
    mockGoRouter = MockGoRouter();
    when(
      () => mockGoRouter.push<Object?>(any(), extra: any(named: 'extra')),
    ).thenAnswer((_) async => null);
  });

  Widget buildSubject(
    _FakeCameraPermissionBloc bloc, {
    ValueChanged<bool>? onResult,
  }) {
    return ProviderScope(
      child: MockGoRouterProvider(
        goRouter: mockGoRouter,
        child: BlocProvider<CameraPermissionBloc>.value(
          value: bloc,
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    final result = await context.pushToCameraWithPermission();
                    onResult?.call(result);
                  },
                  child: const Text('Trigger'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void verifyNavigated() {
    verify(
      () => mockGoRouter.push<Object?>(
        VideoRecorderScreen.pathForEntryPoint(CreationEntryPoint.cameraFab),
        extra: any(named: 'extra'),
      ),
    ).called(1);
  }

  void verifyNotNavigated() {
    verifyNever(
      () => mockGoRouter.push<Object?>(
        VideoRecorderScreen.pathForEntryPoint(CreationEntryPoint.cameraFab),
        extra: any(named: 'extra'),
      ),
    );
  }

  group('pushToCameraWithPermission', () {
    group('terminal statuses navigate without requesting', () {
      testWidgets('authorized navigates and dispatches nothing', (
        tester,
      ) async {
        final bloc = _FakeCameraPermissionBloc(
          const CameraPermissionLoaded(CameraPermissionStatus.authorized),
        );
        bool? result;
        await tester.pumpWidget(
          buildSubject(bloc, onResult: (r) => result = r),
        );

        await tester.tap(find.text('Trigger'));
        await tester.pumpAndSettle();

        verifyNavigated();
        expect(result, isTrue);
        expect(bloc.addedEvents, isEmpty);
      });

      testWidgets('requiresSettings navigates and dispatches nothing', (
        tester,
      ) async {
        final bloc = _FakeCameraPermissionBloc(
          const CameraPermissionLoaded(CameraPermissionStatus.requiresSettings),
        );
        bool? result;
        await tester.pumpWidget(
          buildSubject(bloc, onResult: (r) => result = r),
        );

        await tester.tap(find.text('Trigger'));
        await tester.pumpAndSettle();

        verifyNavigated();
        expect(result, isTrue);
        expect(bloc.addedEvents, isEmpty);
      });
    });

    group('requestable permission fires the native request first', () {
      testWidgets('dispatches request on the current page before navigating', (
        tester,
      ) async {
        final bloc = _FakeCameraPermissionBloc(
          const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        );
        await tester.pumpWidget(buildSubject(bloc));

        await tester.tap(find.text('Trigger'));
        await tester.pump();

        // The request fires while still on the current page — no navigation
        // has happened yet.
        expect(bloc.addedEvents, contains(isA<CameraPermissionRequest>()));
        verifyNotNavigated();

        bloc.emitState(
          const CameraPermissionLoaded(CameraPermissionStatus.authorized),
        );
        await tester.pumpAndSettle();

        verifyNavigated();
      });

      testWidgets(
        'stays put when the request is denied but still requestable',
        (
          tester,
        ) async {
          final bloc = _FakeCameraPermissionBloc(
            const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
          );
          bool? result;
          await tester.pumpWidget(
            buildSubject(bloc, onResult: (r) => result = r),
          );

          await tester.tap(find.text('Trigger'));
          await tester.pump();

          bloc.emitState(
            const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
          );
          await tester.pumpAndSettle();

          verifyNotNavigated();
          expect(result, isFalse);
        },
      );

      testWidgets('navigates when the request resolves to requiresSettings', (
        tester,
      ) async {
        final bloc = _FakeCameraPermissionBloc(
          const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        );
        bool? result;
        await tester.pumpWidget(
          buildSubject(bloc, onResult: (r) => result = r),
        );

        await tester.tap(find.text('Trigger'));
        await tester.pump();

        bloc.emitState(
          const CameraPermissionLoaded(CameraPermissionStatus.requiresSettings),
        );
        await tester.pumpAndSettle();

        verifyNavigated();
        expect(result, isTrue);
      });
    });

    group('resolves status first when not settled', () {
      testWidgets('refreshes when initial, then navigates when authorized', (
        tester,
      ) async {
        final bloc = _FakeCameraPermissionBloc(const CameraPermissionInitial());
        await tester.pumpWidget(buildSubject(bloc));

        await tester.tap(find.text('Trigger'));
        await tester.pump();

        expect(bloc.addedEvents, contains(isA<CameraPermissionRefresh>()));

        bloc.emitState(
          const CameraPermissionLoaded(CameraPermissionStatus.authorized),
        );
        await tester.pumpAndSettle();

        verifyNavigated();
      });

      testWidgets('refreshes when stuck in loading instead of hanging', (
        tester,
      ) async {
        final bloc = _FakeCameraPermissionBloc(const CameraPermissionLoading());
        await tester.pumpWidget(buildSubject(bloc));

        await tester.tap(find.text('Trigger'));
        await tester.pump();

        // A stuck Loading state must not block: a fresh refresh is dispatched.
        expect(bloc.addedEvents, contains(isA<CameraPermissionRefresh>()));

        bloc.emitState(
          const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        );
        await tester.pump();

        // Once resolved to canRequest, the native request fires.
        expect(bloc.addedEvents, contains(isA<CameraPermissionRequest>()));

        bloc.emitState(
          const CameraPermissionLoaded(CameraPermissionStatus.authorized),
        );
        await tester.pumpAndSettle();

        verifyNavigated();
      });

      testWidgets(
        'navigates to the gate when the entry check errors so Retry shows',
        (tester) async {
          final bloc = _FakeCameraPermissionBloc(
            const CameraPermissionInitial(),
          );
          bool? result;
          await tester.pumpWidget(
            buildSubject(bloc, onResult: (r) => result = r),
          );

          await tester.tap(find.text('Trigger'));
          await tester.pump();

          // The entry check refreshes, then errors.
          expect(bloc.addedEvents, contains(isA<CameraPermissionRefresh>()));
          bloc.emitState(const CameraPermissionError());
          await tester.pumpAndSettle();

          // Navigate so the gate renders Error + Retry — no request is fired
          // on the errored state (which would dead-wait the 30s timeout).
          verifyNavigated();
          expect(
            bloc.addedEvents,
            isNot(contains(isA<CameraPermissionRequest>())),
          );
          expect(result, isTrue);
        },
      );
    });

    group('supersedes stale concurrent flows', () {
      testWidgets('only the latest of two concurrent taps navigates', (
        tester,
      ) async {
        final bloc = _FakeCameraPermissionBloc(
          const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        );
        await tester.pumpWidget(buildSubject(bloc));

        // Two overlapping camera taps each start a request flow; the
        // generation guard must let only the latest act on the shared result,
        // otherwise both would push the recorder.
        await tester.tap(find.text('Trigger'));
        await tester.pump();
        await tester.tap(find.text('Trigger'));
        await tester.pump();

        bloc.emitState(
          const CameraPermissionLoaded(CameraPermissionStatus.authorized),
        );
        await tester.pumpAndSettle();

        // verifyNavigated asserts exactly one push, not two.
        verifyNavigated();
      });
    });
  });
}
