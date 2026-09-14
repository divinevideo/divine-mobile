// ABOUTME: BlocObserver that forwards Bloc errors to Crashlytics + UnifiedLogger
// ABOUTME: Wired once in main.dart before runApp; covers addError, handler throws, emit failures, and attaches last event/state/transition

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Crashlytics custom-key names for the per-bloc diagnostics attached when a
/// [ReportableError] is forwarded. Public so dashboards and tests share one
/// source of truth.
const String kBlocLastEventKey = 'bloc.lastEvent';
const String kBlocLastStateKey = 'bloc.lastState';
const String kBlocLastTransitionAtKey = 'bloc.lastTransitionAt';
const String kBlocDiagnosticNotObserved = '<not observed>';

/// Forwards Bloc/Cubit errors to the project's crash reporter and the unified
/// log.
///
/// Bloc's [BlocObserver.onError] fires for three things:
/// 1. An explicit `bloc.addError(error, stackTrace)` from a handler.
/// 2. An uncaught exception thrown inside an event handler.
/// 3. A failure inside `emit(...)` (e.g. emitting from a closed bloc).
///
/// All three are written to the unified log (so the in-memory bug-report
/// capture flow stays complete). Forwarding to Crashlytics is **gated** on
/// the error implementing [ReportableError] or being a bare programming
/// invariant error ([StateError], [TypeError], or [RangeError]) — without that
/// gate, expected domain errors (network timeouts, "no public key yet" during
/// cold start, 4xx responses, validation failures) flood the dashboard and
/// drown the real bugs. See the decision matrix in
/// `.claude/rules/error_handling.md`.
///
/// On a forwarded error the observer also attaches the bloc's most recent
/// event, state, and transition time as Crashlytics custom keys
/// ([kBlocLastEventKey] / [kBlocLastStateKey] / [kBlocLastTransitionAtKey]),
/// each sanitized through [sanitizeForCrashReport]. Event and state are
/// tracked per bloc via [onEvent] / [onChange] with no IO until [onError]
/// fires, so the hot path stays allocation-light. The triage gap this closes
/// is the one that made the #3503 auth-timing investigation expensive. See
/// #3758.
///
/// Echoes of an incident the app has already reported — every bloc's Drift
/// failure once the local database has reported corruption, say — are not
/// filtered here. [CrashReportingService.recordError] applies the incident
/// owner's suppression for every sink at once (#7507).
///
/// Wire once at app start, before `runApp`:
///
/// ```dart
/// Bloc.observer = DivineBlocObserver(crashReporting: crashReporting);
/// runApp(...);
/// ```
class DivineBlocObserver extends BlocObserver {
  DivineBlocObserver({required CrashReportingService crashReporting})
    : _crashReporting = crashReporting;

  final CrashReportingService _crashReporting;

  /// Per-bloc diagnostics. An [Expando] holds its keys weakly, so a bloc's
  /// entry becomes collectible the moment the bloc itself is — observing every
  /// bloc in the app does not retain any of them.
  final Expando<_BlocDiagnostics> _diagnostics = Expando<_BlocDiagnostics>(
    'DivineBlocObserver',
  );

  _BlocDiagnostics _diagnosticsFor(BlocBase<dynamic> bloc) =>
      _diagnostics[bloc] ??= _BlocDiagnostics();

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    _diagnosticsFor(bloc).lastEvent = event;
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    _diagnosticsFor(bloc)
      ..lastState = change.nextState
      ..lastTransitionAt = DateTime.now();
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    final runtimeType = bloc.runtimeType;
    Log.error(
      'Bloc error: $runtimeType: $error',
      name: 'BlocObserver',
      error: error,
      stackTrace: stackTrace,
    );
    final reportableError = _asReportable(error);
    if (reportableError == null) return;
    // Dispatch the diagnostic keys before recordError so they attach to the
    // report it emits. Both are fire-and-forget, but invoked synchronously and
    // in order, so the platform-channel messages stay ordered without blocking
    // the bloc error path. recordError and setCustomKey each swallow their own
    // failures, and while Crashlytics is still initializing they are held in
    // that same order for replay (see crash_reporting_service.dart).
    _attachDiagnosticKeys(_diagnostics[bloc]);
    final reason = sanitizeForCrashReport('Bloc.addError $runtimeType');
    unawaited(
      _crashReporting.recordError(reportableError, stackTrace, reason: reason),
    );
  }

  ReportableError? _asReportable(Object error) {
    if (error is ReportableError) return error;
    if (error is StateError || error is TypeError || error is RangeError) {
      return Reportable(error, context: 'DivineBlocObserver.onError');
    }
    return null;
  }

  void _attachDiagnosticKeys(_BlocDiagnostics? diagnostics) {
    unawaited(
      _crashReporting.setCustomKey(
        kBlocLastEventKey,
        _stringValueOrSentinel(diagnostics?.lastEvent),
      ),
    );
    unawaited(
      _crashReporting.setCustomKey(
        kBlocLastStateKey,
        _stringValueOrSentinel(diagnostics?.lastState),
      ),
    );
    unawaited(
      _crashReporting.setCustomKey(
        kBlocLastTransitionAtKey,
        diagnostics?.lastTransitionAt?.toUtc().toIso8601String() ??
            kBlocDiagnosticNotObserved,
      ),
    );
  }

  String _stringValueOrSentinel(Object? value) {
    if (value == null) return kBlocDiagnosticNotObserved;
    return sanitizeForCrashReport(value.toString());
  }
}

/// Latest observed event, state, and transition time for a single bloc,
/// attached as Crashlytics custom keys when that bloc forwards an error.
class _BlocDiagnostics {
  Object? lastEvent;
  Object? lastState;
  DateTime? lastTransitionAt;
}
