// ABOUTME: Tests for deferring login-options navigation behind active uploads
// ABOUTME: Pins navigate-once, dispose, and observed listener cancellation

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/utils/deferred_login_options_navigator.dart';
import 'package:unified_logger/unified_logger.dart';

import '../helpers/go_router.dart';

class _MockDraft extends Mock implements DivineVideoDraft {}

class _FakeBackgroundPublishBloc extends Fake implements BackgroundPublishBloc {
  _FakeBackgroundPublishBloc(this._state, {Future<void>? Function()? onCancel})
    : _controller = onCancel == null
          ? StreamController<BackgroundPublishState>.broadcast()
          : StreamController<BackgroundPublishState>(onCancel: onCancel);

  final StreamController<BackgroundPublishState> _controller;
  BackgroundPublishState _state;

  @override
  BackgroundPublishState get state => _state;

  @override
  Stream<BackgroundPublishState> get stream => _controller.stream;

  void emitState(BackgroundPublishState newState) {
    _state = newState;
    _controller.add(newState);
  }
}

BackgroundPublishState _uploadingState() {
  final draft = _MockDraft();
  when(() => draft.id).thenReturn('draft-1');
  return BackgroundPublishState(
    uploads: [BackgroundUpload(draft: draft, result: null, progress: 0.5)],
  );
}

void main() {
  group(DeferredLoginOptionsNavigator, () {
    late MockGoRouter router;
    late DeferredLoginOptionsNavigator navigator;

    setUp(() {
      router = MockGoRouter();
      navigator = DeferredLoginOptionsNavigator();
    });

    Future<BuildContext> pumpContext(WidgetTester tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MockGoRouterProvider(
          goRouter: router,
          child: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox();
            },
          ),
        ),
      );
      return capturedContext;
    }

    group('goAfterUploadsComplete', () {
      testWidgets('navigates at once when no upload is in progress', (
        tester,
      ) async {
        final context = await pumpContext(tester);
        final bloc = _FakeBackgroundPublishBloc(const BackgroundPublishState());

        navigator.goAfterUploadsComplete(context: context, publishBloc: bloc);

        verify(() => router.go(WelcomeScreen.loginOptionsPath)).called(1);
      });

      testWidgets('waits for the in-flight upload to finish', (tester) async {
        final context = await pumpContext(tester);
        final bloc = _FakeBackgroundPublishBloc(_uploadingState());

        navigator.goAfterUploadsComplete(context: context, publishBloc: bloc);
        bloc.emitState(_uploadingState());
        await tester.pump();
        verifyNever(() => router.go(any()));

        bloc.emitState(const BackgroundPublishState());
        await tester.pump();

        verify(() => router.go(WelcomeScreen.loginOptionsPath)).called(1);
      });

      testWidgets('navigates once when called again while waiting', (
        tester,
      ) async {
        final context = await pumpContext(tester);
        final bloc = _FakeBackgroundPublishBloc(_uploadingState());

        navigator
          ..goAfterUploadsComplete(context: context, publishBloc: bloc)
          ..goAfterUploadsComplete(context: context, publishBloc: bloc)
          ..goAfterUploadsComplete(context: context, publishBloc: bloc);
        bloc.emitState(const BackgroundPublishState());
        await tester.pump();

        verify(() => router.go(WelcomeScreen.loginOptionsPath)).called(1);
      });

      testWidgets('logs a failed listener cancellation and still navigates', (
        tester,
      ) async {
        final logCapture = LogCaptureService();
        await logCapture.clearAllLogs();
        addTearDown(logCapture.clearAllLogs);
        final context = await pumpContext(tester);
        final bloc = _FakeBackgroundPublishBloc(
          _uploadingState(),
          onCancel: () => Future<void>.error(StateError('cancel failed')),
        );

        navigator.goAfterUploadsComplete(context: context, publishBloc: bloc);
        bloc.emitState(const BackgroundPublishState());
        await tester.pump();

        verify(() => router.go(WelcomeScreen.loginOptionsPath)).called(1);
        final logs = logCapture.getRecentLogs().where(
          (entry) => entry.name == 'DeferredLoginOptionsNavigator',
        );
        expect(logs, hasLength(1));
        expect(
          logs.single.message,
          'Failed to cancel background-publish listener: '
          'Bad state: cancel failed',
        );
      });
    });

    group('dispose', () {
      testWidgets('drops a navigation that is still waiting', (tester) async {
        final context = await pumpContext(tester);
        final bloc = _FakeBackgroundPublishBloc(_uploadingState());

        navigator
          ..goAfterUploadsComplete(context: context, publishBloc: bloc)
          ..dispose();
        bloc.emitState(const BackgroundPublishState());
        await tester.pump();

        verifyNever(() => router.go(any()));
      });

      testWidgets('ignores requests made after it', (tester) async {
        final context = await pumpContext(tester);
        final bloc = _FakeBackgroundPublishBloc(const BackgroundPublishState());

        navigator
          ..dispose()
          ..goAfterUploadsComplete(context: context, publishBloc: bloc);

        verifyNever(() => router.go(any()));
      });
    });
  });
}
