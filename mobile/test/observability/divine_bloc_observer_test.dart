// ABOUTME: Tests for DivineBlocObserver — gates Crashlytics forwarding on
// ABOUTME: ReportableError, sanitizes the reason annotation, and preserves
// ABOUTME: Log.error coverage for every Bloc onError trigger.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/observability/divine_bloc_observer.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockCrashReportingService extends Mock
    implements CrashReportingService {}

class _CountCubit extends Cubit<int> {
  _CountCubit() : super(0);

  void boom(Object error, StackTrace stackTrace) => addError(error, stackTrace);
}

class _CounterBloc extends Bloc<String, int> {
  _CounterBloc() : super(0) {
    on<String>((event, emit) => emit(state + 1));
  }
}

class _NoteCubit extends Cubit<String> {
  _NoteCubit() : super('');
}

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.current);
    registerFallbackValue(<String, Object>{});
  });

  group(DivineBlocObserver, () {
    late _MockCrashReportingService mockCrash;
    late DivineBlocObserver observer;

    setUp(() async {
      await LogCaptureService().clearAllLogs();
      mockCrash = _MockCrashReportingService();
      when(
        () => mockCrash.recordErrorWithCustomKeys(
          any<Object>(),
          any<StackTrace?>(),
          reason: any(named: 'reason'),
          customKeys: any(named: 'customKeys'),
        ),
      ).thenAnswer((_) async {});
      observer = DivineBlocObserver(crashReporting: mockCrash);
    });

    test('forwards Reportable errors to CrashReportingService.recordError', () {
      final cubit = _CountCubit();
      addTearDown(cubit.close);

      final stack = StackTrace.current;
      final error = Reportable(StateError('boom'), context: 'test');

      observer.onError(cubit, error, stack);

      verify(
        () => mockCrash.recordErrorWithCustomKeys(
          error,
          stack,
          reason: 'Bloc.addError _CountCubit',
          customKeys: any(named: 'customKeys'),
        ),
      ).called(1);
    });

    test('annotates the report with the bloc runtime type', () {
      final cubit = _CountCubit();
      addTearDown(cubit.close);

      observer.onError(cubit, Reportable(StateError('x')), StackTrace.current);

      verify(
        () => mockCrash.recordErrorWithCustomKeys(
          any<Object>(),
          any<StackTrace?>(),
          reason: any(named: 'reason', that: contains('_CountCubit')),
          customKeys: any(named: 'customKeys'),
        ),
      ).called(1);
    });

    test('does not forward non-Reportable exceptions to Crashlytics', () {
      final cubit = _CountCubit();
      addTearDown(cubit.close);

      observer.onError(cubit, Exception('domain failure'), StackTrace.current);

      verifyNever(
        () => mockCrash.recordErrorWithCustomKeys(
          any<Object>(),
          any<StackTrace?>(),
          reason: any(named: 'reason'),
          customKeys: any(named: 'customKeys'),
        ),
      );
    });

    test(
      'forwards bare invariant errors as Reportable errors to Crashlytics',
      () async {
        final cubit = _CountCubit();
        addTearDown(cubit.close);

        final invariantErrors = <Object>[
          StateError('closed'),
          TypeError(),
          RangeError.index(2, const [1]),
        ];

        for (final error in invariantErrors) {
          final stack = StackTrace.current;
          observer.onError(cubit, error, stack);
          await Future<void>.delayed(Duration.zero);

          final captured = verify(
            () => mockCrash.recordErrorWithCustomKeys(
              captureAny<Object>(),
              stack,
              reason: 'Bloc.addError _CountCubit',
              customKeys: any(named: 'customKeys'),
            ),
          ).captured;
          expect(captured.single, isA<ReportableError>());
          expect((captured.single as Reportable<Object>).unwrap(), same(error));
        }
      },
    );

    test('includes the error string in the visible log message', () async {
      final cubit = _CountCubit();
      addTearDown(cubit.close);

      observer.onError(
        cubit,
        Exception('staging notifications 500'),
        StackTrace.current,
      );

      await Future<void>.delayed(Duration.zero);

      // Matched anywhere in the capture rather than at `.last`.
      // LogCaptureService is a process-global ring buffer and every file in
      // the shard shares it under `very_good test --optimization`, so leftover
      // async work from another suite can append a line during the await above
      // and take the last slot. Requiring one entry to carry both substrings
      // is what this test is actually about, and it does not depend on the
      // randomized order the suite runs in.
      final logs = LogCaptureService().getRecentLogs();
      expect(
        logs.map((entry) => entry.message),
        contains(
          allOf(
            contains('Bloc error: _CountCubit'),
            contains('Exception: staging notifications 500'),
          ),
        ),
      );
    });

    test('records a Reportable whose toString sanitizes npub identifiers', () {
      final cubit = _CountCubit();
      addTearDown(cubit.close);

      const npub =
          'npub1abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvw';
      final error = Reportable(
        StateError('No public key for $npub during cold start'),
        context: '_publishLike',
      );

      observer.onError(cubit, error, StackTrace.current);

      final captured = verify(
        () => mockCrash.recordErrorWithCustomKeys(
          captureAny<Object>(),
          any<StackTrace?>(),
          reason: any(named: 'reason'),
          customKeys: any(named: 'customKeys'),
        ),
      ).captured;
      expect(captured, hasLength(1));
      expect(captured.single.toString(), contains('npub1<redacted>'));
      expect(captured.single.toString(), isNot(contains(npub)));
    });

    test(
      'integration: addError(Reportable) on a Cubit triggers recordError once',
      () async {
        final previousObserver = Bloc.observer;
        Bloc.observer = observer;
        addTearDown(() => Bloc.observer = previousObserver);

        final cubit = _CountCubit();
        addTearDown(cubit.close);

        cubit.boom(
          Reportable(Exception('e2e'), context: 'integration'),
          StackTrace.current,
        );

        // addError dispatches to the bloc error stream via a microtask;
        // drain it before verifying the synchronous expectation.
        await Future<void>.delayed(Duration.zero);

        verify(
          () => mockCrash.recordErrorWithCustomKeys(
            any<Object>(that: isA<ReportableError>()),
            any<StackTrace?>(),
            reason: 'Bloc.addError _CountCubit',
            customKeys: any(named: 'customKeys'),
          ),
        ).called(1);
      },
    );

    test(
      'hands last event and state to the report suppression boundary',
      () {
        final bloc = _CounterBloc();
        addTearDown(bloc.close);

        observer
          ..onEvent(bloc, 'IncrementPressed')
          ..onChange(bloc, const Change<int>(currentState: 0, nextState: 1));

        final error = Reportable(StateError('boom'), context: 'test');
        observer.onError(bloc, error, StackTrace.current);

        final keys =
            verify(
                  () => mockCrash.recordErrorWithCustomKeys(
                    error,
                    any<StackTrace?>(),
                    reason: any(named: 'reason'),
                    customKeys: captureAny(named: 'customKeys'),
                  ),
                ).captured.single
                as Map<String, Object>;
        expect(keys[kBlocLastEventKey], 'IncrementPressed');
        expect(keys[kBlocLastStateKey], '1');
        expect(
          keys[kBlocLastTransitionAtKey],
          isA<String>().having(
            DateTime.tryParse,
            'parsed timestamp',
            isNotNull,
          ),
        );
      },
    );

    test(
      'overwrites missing diagnostics with sentinels before recordError',
      () async {
        final cubit = _CountCubit();
        addTearDown(cubit.close);

        observer.onError(
          cubit,
          Reportable(StateError('x')),
          StackTrace.current,
        );
        final keys =
            verify(
                  () => mockCrash.recordErrorWithCustomKeys(
                    any<Object>(),
                    any<StackTrace?>(),
                    reason: any(named: 'reason'),
                    customKeys: captureAny(named: 'customKeys'),
                  ),
                ).captured.single
                as Map<String, Object>;
        expect(
          keys.values,
          everyElement(kBlocDiagnosticNotObserved),
        );
      },
    );

    test(
      'does not leak a previous bloc event into a later cubit error report',
      () async {
        final bloc = _CounterBloc();
        final cubit = _CountCubit();
        addTearDown(bloc.close);
        addTearDown(cubit.close);

        observer
          ..onEvent(bloc, 'IncrementPressed')
          ..onChange(bloc, const Change<int>(currentState: 0, nextState: 1))
          ..onError(bloc, Reportable(StateError('first')), StackTrace.current)
          ..onError(
            cubit,
            Reportable(StateError('second')),
            StackTrace.current,
          );

        final captured = verify(
          () => mockCrash.recordErrorWithCustomKeys(
            any<Object>(that: isA<ReportableError>()),
            any<StackTrace?>(),
            reason: any(named: 'reason'),
            customKeys: captureAny(named: 'customKeys'),
          ),
        ).captured.cast<Map<String, Object>>();
        expect(captured, hasLength(2));
        expect(captured.first[kBlocLastEventKey], 'IncrementPressed');
        expect(
          captured.last.values,
          everyElement(kBlocDiagnosticNotObserved),
        );
      },
    );

    test(
      'sanitizes the state snapshot before attaching it as a custom key',
      () async {
        final cubit = _NoteCubit();
        addTearDown(cubit.close);

        const npub =
            'npub1abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvw';
        observer
          ..onChange(
            cubit,
            const Change<String>(
              currentState: '',
              nextState: 'pubkey $npub failed',
            ),
          )
          ..onError(cubit, Reportable(StateError('x')), StackTrace.current);
        final keys =
            verify(
                  () => mockCrash.recordErrorWithCustomKeys(
                    any<Object>(),
                    any<StackTrace?>(),
                    reason: any(named: 'reason'),
                    customKeys: captureAny(named: 'customKeys'),
                  ),
                ).captured.single
                as Map<String, Object>;
        expect(keys[kBlocLastStateKey], contains('npub1<redacted>'));
        expect(keys[kBlocLastStateKey], isNot(contains(npub)));
      },
    );
  });
}
