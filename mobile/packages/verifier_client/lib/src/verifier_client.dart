// ABOUTME: VerifierClient — HTTP client over verifier.divine.video.
// ABOUTME: Stateless: every call hits the network; caching lives above.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:verifier_client/src/exceptions.dart';
import 'package:verifier_client/src/models/identity_claim.dart';
import 'package:verifier_client/src/models/verification_result.dart';
import 'package:verifier_client/src/models/verifier_platform.dart';
import 'package:verifier_client/src/signin_confirmation.dart';

/// HTTP client for `https://verifier.divine.video`.
///
/// Stateless: every call hits the network — intentionally no cache, retry,
/// or rechecking at this layer. The verifier owns server-side freshness via
/// Cloudflare KV; the client-side verdict cache lives one layer up, in
/// `IdentityClaimsRepository` (#3936).
class VerifierClient {
  /// Creates a [VerifierClient] pointed at [baseUrl].
  ///
  /// Pass an [httpClient] to inject a [http.Client] for testing. Pass
  /// [timeout] to override the per-request timeout (default 10 seconds).
  VerifierClient({
    required String baseUrl,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 10),
  }) : _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _httpClient = httpClient ?? http.Client(),
       _timeout = timeout;

  /// Server-side cap from
  /// `divine-identify-verification-service/src/routes/verify.ts:12`.
  /// Keep this in sync if the service raises it.
  static const int maxBatchSize = 10;

  /// Path of the OAuth revoke endpoint, shared by [revokeOAuth] and
  /// [oauthRevokeUrl] so the request and the string it is signed against
  /// cannot drift apart.
  static const String _oauthRevokePath = '/auth/oauth/revoke';

  final String _baseUrl;
  final http.Client _httpClient;
  final Duration _timeout;

  /// Re-verifies a batch of claims. Returns one result per input claim in the
  /// order the verifier responds (typically input order).
  ///
  /// Returns an empty list when [claims] is empty without hitting the network.
  ///
  /// Throws:
  /// * [ArgumentError] if [claims] has more than [maxBatchSize] items.
  /// * [VerifierApiException] for any non-2xx response.
  /// * [VerifierTimeoutException] if the request does not complete within the
  ///   configured timeout.
  /// * [VerifierNetworkException] for transport-level failures.
  Future<List<VerificationResult>> verifyBatch(
    List<IdentityClaim> claims,
  ) async {
    if (claims.isEmpty) return const [];
    if (claims.length > maxBatchSize) {
      throw ArgumentError.value(
        claims.length,
        'claims',
        'must contain at most $maxBatchSize items',
      );
    }
    final body = jsonEncode(<String, dynamic>{
      'claims': claims.map((c) => c.toJson()).toList(),
    });
    final json = await _post('/verify', body);
    final results = (json['results'] as List).cast<Map<String, dynamic>>();
    return results.map(VerificationResult.fromJson).toList();
  }

  /// Re-verifies a single claim via `/verify/single`.
  ///
  /// Throws the same exceptions as [verifyBatch].
  Future<VerificationResult> verifySingle(IdentityClaim claim) async {
    final body = jsonEncode(claim.toJson());
    final json = await _post('/verify/single', body);
    return VerificationResult.fromJson(json);
  }

  /// Lists the platforms the verifier currently accepts claims for.
  ///
  /// Entries the service reports as unsupported are returned as-is; callers
  /// decide whether to hide or disable them.
  ///
  /// Throws the same exceptions as [verifyBatch].
  Future<List<VerifierPlatform>> fetchPlatforms() async {
    final json = await _get('/platforms');
    final platforms = json['platforms'] as Map<String, dynamic>? ?? const {};
    return [
      for (final entry in platforms.entries)
        VerifierPlatform.fromJson(
          entry.key,
          entry.value as Map<String, dynamic>,
        ),
    ];
  }

  /// Starts [platform]'s sign-in so the account owner can confirm it, and
  /// returns the provider page to open.
  ///
  /// [startCheck] is [SignInSecrets.startCheckFor] of a secret the caller
  /// keeps for [confirmSignIn]; it travels only in this request's body. The
  /// verifier returns to [returnUrl] with `platform` and `identity`, and the
  /// one-time code as `#oauth_confirm=<code>` (or in the query, if it is set
  /// to).
  ///
  /// Returns null when this deployment has no sign-in for [platform] (503).
  ///
  /// Throws [ArgumentError] for a platform without sign-in, or Bluesky
  /// without a handle; [VerifierApiException] for other refusals or a
  /// provider page that isn't https; [VerifierTimeoutException] and
  /// [VerifierNetworkException] as [verifyBatch] does.
  Future<Uri?> startSignIn({
    required String platform,
    required String pubkey,
    required String returnUrl,
    required String startCheck,
    String? handle,
  }) async {
    if (!VerifierPlatform.oauthPlatforms.contains(platform)) {
      throw ArgumentError.value(
        platform,
        'platform',
        'has no OAuth flow; supported: '
            '${VerifierPlatform.oauthPlatforms.join(', ')}',
      );
    }
    final bareHandle = handle?.trim() ?? '';
    if (platform == 'bluesky' && bareHandle.isEmpty) {
      throw ArgumentError.value(
        handle,
        'handle',
        'is required to start the bluesky OAuth flow',
      );
    }
    final body = jsonEncode(<String, String>{
      'pubkey': pubkey,
      'return_url': returnUrl,
      'start_check': startCheck,
      if (bareHandle.isNotEmpty) 'handle': bareHandle,
    });
    final Map<String, dynamic> json;
    try {
      json = await _post('/auth/$platform/start', body);
    } on VerifierApiException catch (e) {
      if (e.statusCode == 503) return null;
      rethrow;
    }
    final url = json['url'];
    final target = url is String ? Uri.tryParse(url) : null;
    // The session has to land on a provider's https page, not on whatever a
    // malformed answer happens to name.
    if (target == null || target.scheme != 'https' || target.host.isEmpty) {
      throw const VerifierApiException(
        200,
        'verifier answered a sign-in start without an https url',
      );
    }
    return target;
  }

  /// Asks the verifier to count a sign-in: [event] is the signed kind 10011
  /// whose new claim carries [SignInSecrets.confirmBindingFor]. Send the same
  /// [event] again after a lost answer; a re-signed one is refused as used.
  ///
  /// Throws [SignInConfirmException] for a refusal, [VerifierApiException]
  /// for a server error or a success that doesn't name the linked account,
  /// and the timeout and network exceptions as [verifyBatch].
  Future<SignInConfirmation> confirmSignIn({
    required String code,
    required String startSecret,
    required Map<String, dynamic> event,
  }) async {
    final body = jsonEncode(<String, dynamic>{
      'code': code,
      'start_secret': startSecret,
      'event': event,
    });
    final res = await _fetch(_postRequest('/auth/confirm', body));
    Map<String, dynamic>? json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } on Object {
      json = null;
    }
    // Neither the code nor the secret goes into an exception message: they
    // are what the verifier redeems.
    if (res.statusCode >= 500) {
      throw VerifierApiException(
        res.statusCode,
        'verifier returned ${res.statusCode}',
      );
    }
    if (res.statusCode == 200 && json?['linked'] == true) {
      final platform = json!['platform'];
      final identity = json['identity'];
      if (platform is! String || identity is! String) {
        throw const VerifierApiException(
          200,
          'verifier confirmed a sign-in without naming the account',
        );
      }
      return SignInConfirmation(platform: platform, identity: identity);
    }
    throw SignInConfirmException(
      res.statusCode,
      SignInRefusal.fromCode(json?['code']),
    );
  }

  /// Drops the verifier's cached OAuth verification for a claim.
  ///
  /// [nip98Event] must be a signed NIP-98 (kind 27235) event whose `u` tag is
  /// this endpoint's URL — available as [oauthRevokeUrl] — and whose `method`
  /// tag is `POST`. The verifier validates it through `login.divine.video`
  /// before honouring the revoke.
  ///
  /// Removing the claim's `i` tag is a separate step: the tag lives in the
  /// user's own identity event, which only they can rewrite.
  ///
  /// Throws the same exceptions as [verifyBatch].
  Future<void> revokeOAuth({
    required String platform,
    required String identity,
    required String pubkey,
    required Map<String, dynamic> nip98Event,
  }) async {
    final body = jsonEncode(<String, dynamic>{
      'platform': platform,
      'identity': identity,
      'pubkey': pubkey,
      'event': nip98Event,
    });
    await _post(_oauthRevokePath, body);
  }

  /// Absolute URL of the OAuth revoke endpoint.
  ///
  /// The NIP-98 event passed to [revokeOAuth] must carry this exact string in
  /// its `u` tag, so it is exposed rather than rebuilt at the call site.
  ///
  /// Built through [_uriFor], the same builder the request goes through, so
  /// what is signed is what reaches the wire. Composing it from [_baseUrl]
  /// directly would skip the normalization `Uri.parse` applies, and the
  /// verifier compares the `u` tag to the request URL exactly.
  String get oauthRevokeUrl => _uriFor(_oauthRevokePath).toString();

  /// The one place a request URL is built.
  ///
  /// Every caller — including [oauthRevokeUrl] — goes through here, which is
  /// what keeps a signed URL and the URL it is sent to identical by
  /// construction rather than by convention.
  Uri _uriFor(String path) => Uri.parse('$_baseUrl$path');

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? query,
  }) async {
    var uri = _uriFor(path);
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }
    return _send(() => _httpClient.get(uri));
  }

  Future<Map<String, dynamic>> _post(String path, String body) =>
      _send(_postRequest(path, body));

  Future<http.Response> Function() _postRequest(String path, String body) {
    final uri = _uriFor(path);
    return () => _httpClient.post(
      uri,
      headers: const {'content-type': 'application/json'},
      body: body,
    );
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    final res = await _fetch(request);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw VerifierApiException(
        res.statusCode,
        'verifier returned ${res.statusCode}: ${res.body}',
      );
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Sends [request] with the timeout, mapping transport failures to the
  /// client's exceptions. Callers read the status themselves.
  Future<http.Response> _fetch(
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request().timeout(_timeout);
    } on TimeoutException catch (e) {
      throw VerifierTimeoutException(e.toString());
    } on SocketException catch (e) {
      throw VerifierNetworkException(e.toString());
    } on http.ClientException catch (e) {
      throw VerifierNetworkException(e.toString());
    }
  }

  /// Test hook returning the underlying [http.Client]. Do not use in
  /// production code.
  @visibleForTesting
  http.Client get debugHttpClient => _httpClient;
}
