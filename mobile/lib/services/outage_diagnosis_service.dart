// ABOUTME: Decides whether a failed load is our outage or the user's network
// ABOUTME: Consults status.divine.video only when something already failed

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:divine_status_client/divine_status_client.dart';
import 'package:meta/meta.dart';

/// Why something failed to load.
enum OutageVerdict {
  /// The status page corroborates that a component we depend on is impaired.
  divineOutage,

  /// The device has no usable network, or nothing at all is reachable.
  noConnection,

  /// Nothing corroborates a cause; the caller should stay generic.
  ///
  /// This is the default whenever evidence is missing or contradictory. The
  /// app must not claim an outage it cannot substantiate — a wrong "we're
  /// fixing it" teaches users to ignore the message that matters.
  indeterminate,
}

/// The outcome of one diagnosis.
@immutable
class OutageDiagnosis {
  const OutageDiagnosis(this.verdict, {this.operatorMessage});

  final OutageVerdict verdict;

  /// What the on-call operator wrote on the status page, when they wrote
  /// anything. Always preferred over canned copy.
  final String? operatorMessage;

  static const indeterminate = OutageDiagnosis(OutageVerdict.indeterminate);
}

/// Signature of the connectivity probe, injected so tests need no plugin.
typedef ConnectivityProbe = Future<List<ConnectivityResult>> Function();

/// Explains a failed load by cross-checking the Divine status page.
///
/// Only ever called after something has already failed, so a healthy session
/// never issues a request. Results are cached because during a real outage
/// every client fails at once, and each one asking repeatedly would pile onto
/// the status page exactly when it is most needed.
class OutageDiagnosisService {
  OutageDiagnosisService({
    DivineStatusClient? statusClient,
    ConnectivityProbe? connectivityProbe,
    DateTime Function()? now,
  }) : _statusClient = statusClient ?? DivineStatusClient(),
       _connectivityProbe =
           connectivityProbe ?? Connectivity().checkConnectivity,
       _now = now ?? DateTime.now;

  /// How long a verdict is reused. Long enough that repeated retries during
  /// one incident cost a single request, short enough to notice recovery.
  static const cacheDuration = Duration(minutes: 2);

  /// Components the video feed depends on. A viewer is not told about
  /// uploads: it is not what they are doing and not why their feed is empty.
  static const List<String> feedComponents = [
    DivineStatusComponents.api,
    DivineStatusComponents.relay,
  ];

  final DivineStatusClient _statusClient;
  final ConnectivityProbe _connectivityProbe;
  final DateTime Function() _now;

  final Map<String, _CachedDiagnosis> _cached = {};
  final Map<String, Future<OutageDiagnosis>> _inFlight = {};

  /// Diagnoses why a load of [components] failed.
  ///
  /// Concurrent callers asking about the same components share one request, so
  /// several failing surfaces do not multiply into several status fetches.
  Future<OutageDiagnosis> diagnose({List<String> components = feedComponents}) {
    final cacheKey = _cacheKey(components);
    final cached = _cached[cacheKey];
    if (cached != null && _now().difference(cached.cachedAt) < cacheDuration) {
      return Future.value(cached.diagnosis);
    }

    return _inFlight[cacheKey] ??= _diagnoseAndClear(components, cacheKey);
  }

  Future<OutageDiagnosis> _diagnoseAndClear(
    List<String> components,
    String cacheKey,
  ) async {
    try {
      return await _diagnose(components);
    } finally {
      final _ = _inFlight.remove(cacheKey);
    }
  }

  Future<OutageDiagnosis> _diagnose(List<String> components) async {
    final diagnosis = await _resolve(components);
    _cached[_cacheKey(components)] = _CachedDiagnosis(
      diagnosis: diagnosis,
      cachedAt: _now(),
    );
    return diagnosis;
  }

  Future<OutageDiagnosis> _resolve(List<String> components) async {
    if (await _hasNoNetworkInterface()) {
      return const OutageDiagnosis(OutageVerdict.noConnection);
    }

    final status = await _statusClient.fetchStatus();
    if (status == null) {
      // A null status read is no opinion: it can be a transport failure, but it
      // can also be a malformed payload, a wrong endpoint serving the SPA shell,
      // or another status-page problem. Do not blame the user's network unless
      // the connectivity probe gives direct evidence.
      return OutageDiagnosis.indeterminate;
    }

    if (status.anyImpaired(components)) {
      return OutageDiagnosis(
        OutageVerdict.divineOutage,
        operatorMessage: status.incidentMessage,
      );
    }

    // Reachable and reportedly healthy: something failed, but nothing here
    // says what, so say nothing.
    return OutageDiagnosis.indeterminate;
  }

  Future<bool> _hasNoNetworkInterface() async {
    try {
      final results = await _connectivityProbe();
      return results.isEmpty ||
          results.every((r) => r == ConnectivityResult.none);
    } on Object {
      // Plugin unavailable (tests, unsupported platform): fall through to the
      // status check rather than guessing.
      return false;
    }
  }

  void dispose() => _statusClient.close();

  /// Order-independent key for a component set.
  static String _cacheKey(Iterable<String> components) {
    final normalized = components.toSet().toList()..sort();
    return normalized.join(',');
  }
}

final class _CachedDiagnosis {
  const _CachedDiagnosis({required this.diagnosis, required this.cachedAt});

  final OutageDiagnosis diagnosis;
  final DateTime cachedAt;
}
