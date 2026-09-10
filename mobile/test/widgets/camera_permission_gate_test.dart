// ABOUTME: Tests for CameraPermissionGate's direct-request permission behavior
// ABOUTME: Fires the native dialog directly, no in-app "Continue" priming screen

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/camera_permission/camera_permission_bloc.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/widgets/camera_permission_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  void add(CameraPermissionEvent event) => addedEvents.add(event);

  void emitState(CameraPermissionState newState) {
    _state = newState;
    _controller.add(newState);
  }

  @override
  bool get isClosed => false;

  @override
  Future<void> close() async => _controller.close();
}

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

class _TestClipManagerNotifier extends ClipManagerNotifier {
  @override
  final List<DivineVideoClip> clips = const [];

  @override
  ClipManagerState build() => ClipManagerState(clips: clips);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final l10n = lookupAppLocalizations(const Locale('en'));

  late SharedPreferences prefs;
  late _MockVideoRecorderBloc recorderBloc;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    recorderBloc = _MockVideoRecorderBloc();
    when(() => recorderBloc.state).thenReturn(const VideoRecorderBlocState());
  });

  // The requiresSettings / error states render `_PermissionScreen`, which
  // embeds the recorder bottom bar — hence the VideoRecorderBloc + clip
  // provider scaffolding even though the gate itself only needs the
  // permission bloc.
  Widget buildSubject(_FakeCameraPermissionBloc bloc, MockGoRouter goRouter) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        clipManagerProvider.overrideWith(_TestClipManagerNotifier.new),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MockGoRouterProvider(
          goRouter: goRouter,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<CameraPermissionBloc>.value(value: bloc),
              BlocProvider<VideoRecorderBloc>.value(value: recorderBloc),
            ],
            child: const CameraPermissionGate(child: Text('CAMERA')),
          ),
        ),
      ),
    );
  }

  group(CameraPermissionGate, () {
    testWidgets(
      'auto-fires the native request for a requestable permission with no '
      'in-app priming screen',
      (tester) async {
        final bloc = _FakeCameraPermissionBloc(
          const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        );
        addTearDown(bloc.close);

        await tester.pumpWidget(buildSubject(bloc, MockGoRouter()));
        await tester.pump();

        // The dialog is fired directly; the old priming screen (a DivineButton
        // prompt) is gone and only a spinner covers the brief window.
        expect(bloc.addedEvents, contains(isA<CameraPermissionRequest>()));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(DivineButton), findsNothing);
      },
    );

    testWidgets('pops back when the request is denied but stays requestable', (
      tester,
    ) async {
      final bloc = _FakeCameraPermissionBloc(
        const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
      );
      addTearDown(bloc.close);
      final goRouter = MockGoRouter();
      when(goRouter.canPop).thenReturn(true);

      await tester.pumpWidget(buildSubject(bloc, goRouter));
      await tester.pump();

      // The bloc emits the transient Loading before resolving back to a
      // still-requestable status, mirroring a back-dismissed native dialog.
      bloc.emitState(const CameraPermissionLoading());
      await tester.pump();
      bloc.emitState(
        const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
      );
      await tester.pump();

      verify(goRouter.pop).called(1);
    });

    testWidgets(
      'renders the child when already authorized without requesting',
      (
        tester,
      ) async {
        final bloc = _FakeCameraPermissionBloc(
          const CameraPermissionLoaded(CameraPermissionStatus.authorized),
        );
        addTearDown(bloc.close);

        await tester.pumpWidget(buildSubject(bloc, MockGoRouter()));
        await tester.pump();

        expect(find.text('CAMERA'), findsOneWidget);
        expect(bloc.addedEvents, isEmpty);
      },
    );

    testWidgets(
      'requiresSettings shows the settings prompt and dispatches OpenSettings',
      (tester) async {
        final bloc = _FakeCameraPermissionBloc(
          const CameraPermissionLoaded(CameraPermissionStatus.requiresSettings),
        );
        addTearDown(bloc.close);

        await tester.pumpWidget(buildSubject(bloc, MockGoRouter()));
        await tester.pump();

        // A non-requestable permission never auto-fires a request.
        expect(
          bloc.addedEvents,
          isNot(contains(isA<CameraPermissionRequest>())),
        );
        expect(find.text(l10n.cameraPermissionGoToSettings), findsOneWidget);

        await tester.tap(find.text(l10n.cameraPermissionGoToSettings));
        await tester.pump();

        expect(bloc.addedEvents, contains(isA<CameraPermissionOpenSettings>()));
      },
    );

    testWidgets('error shows the retry prompt that dispatches a refresh', (
      tester,
    ) async {
      final bloc = _FakeCameraPermissionBloc(const CameraPermissionError());
      addTearDown(bloc.close);

      await tester.pumpWidget(buildSubject(bloc, MockGoRouter()));
      await tester.pump();

      expect(find.text(l10n.cameraPermissionErrorTitle), findsOneWidget);

      // initState already refreshes on a non-Loaded mount; assert the button
      // itself dispatches a further refresh rather than relying on that.
      final before = bloc.addedEvents.length;
      await tester.tap(find.text(l10n.cameraPermissionRetry));
      await tester.pump();

      expect(bloc.addedEvents.length, before + 1);
      expect(bloc.addedEvents.last, isA<CameraPermissionRefresh>());
    });

    testWidgets('the permission prompt closes via its labelled X', (
      tester,
    ) async {
      // The prompt renders through the shared TvStaticMessageScreen, so its
      // close wiring and label have to survive that hop.
      final bloc = _FakeCameraPermissionBloc(
        const CameraPermissionLoaded(CameraPermissionStatus.requiresSettings),
      );
      addTearDown(bloc.close);
      final goRouter = MockGoRouter();
      when(goRouter.canPop).thenReturn(true);

      await tester.pumpWidget(buildSubject(bloc, goRouter));
      await tester.pump();

      await tester.tap(
        find.bySemanticsLabel(l10n.videoRecorderCloseLabel),
      );
      await tester.pump();

      verify(goRouter.pop).called(1);
    });

    testWidgets('a stuck loading state offers a close affordance to bail out', (
      tester,
    ) async {
      // Mirrors the back-dismiss hang on the direct-nav path: the bloc is
      // pinned in Loading. The user must be able to escape the spinner.
      final bloc = _FakeCameraPermissionBloc(const CameraPermissionLoading());
      addTearDown(bloc.close);
      final goRouter = MockGoRouter();
      when(goRouter.canPop).thenReturn(true);

      await tester.pumpWidget(buildSubject(bloc, goRouter));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(DivineIconButton), findsOneWidget);

      await tester.tap(find.byType(DivineIconButton));
      await tester.pump();

      verify(goRouter.pop).called(1);
    });
  });
}
