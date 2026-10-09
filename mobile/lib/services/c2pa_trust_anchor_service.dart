// ABOUTME: Fetches and caches the ProofSign C2PA trust anchors.
// ABOUTME: The anchors decide which signers a C2PA check on this device trusts.

import 'dart:async';
import 'dart:convert';

import 'package:cache_sync/cache_sync.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:unified_logger/unified_logger.dart';

/// A PEM bundle of trust anchors and whether it came off the network in the
/// call that returned it.
@immutable
class C2paTrustAnchors {
  /// Creates [C2paTrustAnchors].
  const C2paTrustAnchors({required this.pem, required this.isFresh});

  /// Concatenated `CERTIFICATE` PEM blocks, and nothing else.
  final String pem;

  /// True when fetched from the server during this load. A cached bundle can
  /// predate a key rotation, so a check that fails on one is worth repeating
  /// with fresh anchors.
  final bool isFresh;
}

/// Loads the C2PA trust anchors Divine publishes for the signers of Divine
/// camera recordings.
///
/// The bundle is Divine's canonical one at [defaultAnchorsUrl], the same one
/// the server-side verifier reads. It is deliberately not derived from the
/// build's signing endpoint: a build may sign through a ProofSign deployment
/// that publishes no bundle of its own, and a clip must verify the same way
/// whichever build recorded it. The anchors rotate, and a verifier must pick
/// up a new one within about an hour, so they are fetched rather than built
/// into the app. The last good bundle is kept in [CacheSync] so a check still
/// works offline, but only for [maxStaleAge]: a device that stays offline must
/// not go on trusting an anchor the server has since retired.
class C2paTrustAnchorService {
  /// Creates a [C2paTrustAnchorService] reading from [anchorsUrl].
  C2paTrustAnchorService({
    Uri? anchorsUrl,
    http.Client? httpClient,
    DateTime Function()? now,
  }) : _anchorsUrl = anchorsUrl ?? defaultAnchorsUrl,
       _httpClient = httpClient ?? http.Client(),
       _now = now ?? DateTime.now;

  /// Age after which a cached bundle is refetched before use.
  static const Duration refreshInterval = Duration(hours: 1);

  /// Age after which a cached bundle is no longer used, even offline.
  static const Duration maxStaleAge = Duration(days: 7);

  /// Upper bound on the anchor request.
  static const Duration requestTimeout = Duration(seconds: 10);

  /// Largest bundle accepted. The live one is under 2 KB.
  static const int maxBundleBytes = 64 * 1024;

  /// Divine's canonical trust bundle.
  static final Uri defaultAnchorsUrl = Uri.parse(
    'https://proofsign.divine.video/.well-known/c2pa-trust-anchors.pem',
  );

  static const String _cacheKeyPrefix = 'c2pa_trust_anchors:';
  static const String _logName = 'C2paTrustAnchorService';

  static final RegExp _certificateBlock = RegExp(
    r'-----BEGIN CERTIFICATE-----[A-Za-z0-9+/=\s]+?-----END CERTIFICATE-----',
  );

  final Uri _anchorsUrl;
  final http.Client _httpClient;
  final DateTime Function() _now;

  /// Keeps only the `CERTIFICATE` blocks of [bundle], dropping the comment
  /// lines the server writes between them. Returns null when there are none.
  @visibleForTesting
  static String? certificatesOnly(String bundle) {
    final blocks = _certificateBlock
        .allMatches(bundle)
        .map((match) => match.group(0)!)
        .toList();
    return blocks.isEmpty ? null : '${blocks.join('\n')}\n';
  }

  /// Returns the trust anchors, or null when none can be had.
  ///
  /// Uses a cached bundle younger than [refreshInterval] without a request,
  /// unless [forceRefresh] is set. Otherwise fetches, and falls back to a
  /// cached bundle younger than [maxStaleAge] when the fetch fails. Never
  /// throws.
  Future<C2paTrustAnchors?> load({bool forceRefresh = false}) async {
    final url = _anchorsUrl;
    final cacheKey = '$_cacheKeyPrefix${url.host}';
    final stored = await _readCache(cacheKey);
    final age = stored == null ? null : _now().difference(stored.fetchedAt);
    // A bundle dated in the future was cached while the clock ran ahead. Its
    // real age is unknown, so it is neither fresh nor an offline fallback.
    final cached = age == null || age.isNegative ? null : stored;
    if (!forceRefresh && cached != null && age! < refreshInterval) {
      return C2paTrustAnchors(pem: cached.pem, isFresh: false);
    }

    final fetched = await _fetch(url);
    if (fetched != null) {
      await _writeCache(cacheKey, _CachedBundle(fetched, _now()));
      return C2paTrustAnchors(pem: fetched, isFresh: true);
    }

    if (cached != null && age! < maxStaleAge) {
      return C2paTrustAnchors(pem: cached.pem, isFresh: false);
    }
    return null;
  }

  Future<String?> _fetch(Uri url) async {
    try {
      final response = await _httpClient.get(url).timeout(requestTimeout);
      if (response.statusCode != 200) {
        Log.warning(
          'Trust anchor request returned ${response.statusCode}',
          name: _logName,
          category: LogCategory.video,
        );
        return null;
      }
      if (response.bodyBytes.length > maxBundleBytes) {
        Log.warning(
          'Trust anchor bundle exceeds $maxBundleBytes bytes',
          name: _logName,
          category: LogCategory.video,
        );
        return null;
      }
      final pem = certificatesOnly(utf8.decode(response.bodyBytes));
      if (pem == null) {
        Log.warning(
          'Trust anchor response carried no certificate',
          name: _logName,
          category: LogCategory.video,
        );
      }
      return pem;
    } catch (error, stackTrace) {
      Log.warning(
        'Could not fetch C2PA trust anchors',
        name: _logName,
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<_CachedBundle?> _readCache(String key) async {
    try {
      return await CacheSync.read<_CachedBundle>(
        key: key,
        fromJson: _CachedBundle.fromJson,
      );
    } catch (error, stackTrace) {
      Log.warning(
        'Could not read cached C2PA trust anchors',
        name: _logName,
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> _writeCache(String key, _CachedBundle bundle) async {
    try {
      // No TTL: freshness is judged against [refreshInterval] and
      // [maxStaleAge] here, so an expired row would only hide the offline
      // fallback.
      await CacheSync.write<_CachedBundle>(
        key: key,
        value: bundle,
        toJson: (value) => value.toJson(),
      );
    } catch (error, stackTrace) {
      Log.warning(
        'Could not cache C2PA trust anchors',
        name: _logName,
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

class _CachedBundle {
  const _CachedBundle(this.pem, this.fetchedAt);

  factory _CachedBundle.fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    final pem = C2paTrustAnchorService.certificatesOnly(map['pem'] as String);
    if (pem == null) throw const FormatException('no certificate');
    return _CachedBundle(
      pem,
      DateTime.fromMillisecondsSinceEpoch(map['fetchedAtMs'] as int),
    );
  }

  final String pem;
  final DateTime fetchedAt;

  String toJson() => jsonEncode({
    'pem': pem,
    'fetchedAtMs': fetchedAt.millisecondsSinceEpoch,
  });
}
