// ABOUTME: Router config that survives saved route state go_router cannot decode
// ABOUTME: Guards the launch-loop crash in RouteMatchListCodec (#7869)

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/providers/crash_reporting_provider.dart';
import 'package:openvine/router/app_router.dart';
import 'package:unified_logger/unified_logger.dart';

/// The [RouterConfig] `MaterialApp.router` is given.
///
/// Held by a provider rather than built in `build` so the parser keeps its
/// identity across a locale or appearance change. `Router.didUpdateWidget`
/// invalidates its in-flight route transaction whenever the parser instance
/// changes, which would drop a navigation that is still resolving.
final routerConfigProvider = Provider<RouterConfig<RouteMatchList>>(
  (ref) => restorationSafeRouterConfig(
    ref.watch(goRouterProvider),
    crashReporter: ref.watch(crashReportingServiceProvider),
  ),
);

/// Wraps [router] so a saved route state it cannot decode is dropped rather
/// than thrown out of the launch path.
///
/// The saved state is an optimization — it restores the imperative push stack
/// on top of the location. The location itself travels in the URI and is
/// enough to land the user on the right screen, so falling back to it costs a
/// pushed route and keeps the app usable.
RouterConfig<RouteMatchList> restorationSafeRouterConfig(
  GoRouter router, {
  CrashReporter crashReporter = const SilentCrashReporter(),
}) {
  return RouterConfig<RouteMatchList>(
    routeInformationProvider: router.routeInformationProvider,
    routeInformationParser: RestorationSafeRouteInformationParser(
      router.routeInformationParser,
      crashReporter: crashReporter,
    ),
    routerDelegate: router.routerDelegate,
    backButtonDispatcher: router.backButtonDispatcher,
  );
}

/// A [RouteInformationParser] that degrades a failed saved-state decode to a
/// plain navigation to the same URI.
///
/// go_router builds the match list for an unresolvable location as
/// `const <RouteMatch>[]` (`configuration.dart`, `parser.dart`). Restoring a
/// state whose root location no longer resolves therefore copies that
/// `List<RouteMatch>` in `RouteMatchList._createNewMatchUntilIncompatible` and
/// appends the shell branch its imperative match resolved to, which throws
/// `type 'ShellRouteMatch' is not a subtype of type 'RouteMatch' of 'value'`.
///
/// The throw lands in `Router.restoreState`, before the app is interactive,
/// and the same state is replayed on every cold start — so an affected install
/// loops rather than recovering. Still present in go_router 18.0.1, the latest
/// release at the time of writing, so a version bump does not remove it.
@visibleForTesting
class RestorationSafeRouteInformationParser
    extends RouteInformationParser<RouteMatchList> {
  /// Creates a parser that guards [_delegate]'s saved-state decode.
  RestorationSafeRouteInformationParser(
    this._delegate, {
    CrashReporter crashReporter = const SilentCrashReporter(),
  }) : _crashReporter = crashReporter;

  final RouteInformationParser<RouteMatchList> _delegate;
  final CrashReporter _crashReporter;

  @override
  Future<RouteMatchList> parseRouteInformationWithDependencies(
    RouteInformation routeInformation,
    BuildContext context,
  ) {
    if (!_carriesEncodedMatchList(routeInformation)) {
      return _delegate.parseRouteInformationWithDependencies(
        routeInformation,
        context,
      );
    }
    try {
      return _delegate.parseRouteInformationWithDependencies(
        routeInformation,
        context,
      );
    } catch (error, stackTrace) {
      Log.error(
        'Dropping undecodable saved route state for ${routeInformation.uri}',
        name: 'RestorationSafeRouter',
        category: LogCategory.ui,
        error: error,
        stackTrace: stackTrace,
      );
      unawaited(
        _crashReporter.recordError(
          error,
          stackTrace,
          reason: 'RestorationSafeRouter.parseRouteInformation',
        ),
      );
      return _delegate.parseRouteInformationWithDependencies(
        RouteInformation(uri: routeInformation.uri),
        context,
      );
    }
  }

  @override
  Future<RouteMatchList> parseRouteInformation(
    RouteInformation routeInformation,
  ) => _delegate.parseRouteInformation(routeInformation);

  @override
  RouteInformation? restoreRouteInformation(RouteMatchList configuration) =>
      _delegate.restoreRouteInformation(configuration);

  /// Whether go_router will decode [routeInformation]'s state as a stored
  /// match list, which is the only branch that can throw here.
  ///
  /// A null state is a synthesized navigation and a [RouteInformationState] is
  /// one of our own `go` / `push` calls; neither reaches the codec.
  static bool _carriesEncodedMatchList(RouteInformation routeInformation) {
    final state = routeInformation.state;
    return state != null && state is! RouteInformationState;
  }
}
