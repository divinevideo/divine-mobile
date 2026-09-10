// ABOUTME: Canonical Divine OAuth callback URL and its strict parser.
// ABOUTME: One App Link serves every in-app OAuth flow, so the URL parts and
// ABOUTME: the validator live here rather than once per feature.

import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

/// Scheme of the Divine OAuth callback URL.
const appOAuthCallbackScheme = 'https';

/// Host of the Divine OAuth callback URL.
///
/// Registered as an App Link in `AndroidManifest.xml` and as a Universal Link
/// in `Runner.entitlements` / the site's `apple-app-site-association`. Change
/// it in one place and the OS hands the redirect to a browser instead of the
/// app.
const appOAuthCallbackHost = 'divine.video';

/// Path of the Divine OAuth callback URL.
const appOAuthCallbackPath = '/app/callback';

/// The callback URL providers redirect back to, as a string.
const appOAuthCallbackUrl =
    '$appOAuthCallbackScheme://$appOAuthCallbackHost$appOAuthCallbackPath';

const _invalidCallbackMessage =
    'Invalid OAuth callback. Expected $appOAuthCallbackUrl with no user info '
    'or explicit port.';
const _callbackPrefix = '$appOAuthCallbackScheme://';
final _authorityTerminator = RegExp('[/#?]');
final _malformedPercentTriplet = RegExp('%(?![0-9A-Fa-f]{2})');

/// Authentication seam matching the arguments used by [FlutterWebAuth2].
typedef AppOAuthAuthenticate = Future<String> Function({
  required String url,
  required String callbackUrlScheme,
  required FlutterWebAuth2Options options,
});

/// Opens [authorizationUri] in the native OAuth session and returns the
/// callback URL, or null when the user dismissed the session.
///
/// The HTTPS universal-link callback relies on
/// `ASWebAuthenticationSession.Callback.https(host:path:)`, available on
/// iOS 17.4+; older iOS can silently report a completed connection as a
/// cancel, so callers gate the entry point on [appOAuthSupported].
///
/// Throws [FormatException] when the session returns something that is not
/// exactly the Divine callback URL.
Future<Uri?> launchAppOAuth(
  Uri authorizationUri, {
  AppOAuthAuthenticate authenticate = _authenticate,
}) async {
  try {
    final callback = await authenticate(
      url: authorizationUri.toString(),
      callbackUrlScheme: appOAuthCallbackScheme,
      options: const FlutterWebAuth2Options(
        httpsHost: appOAuthCallbackHost,
        httpsPath: appOAuthCallbackPath,
      ),
    );
    return parseAppOAuthCallback(callback);
  } on PlatformException catch (error) {
    if (error.code == 'CANCELED') return null;
    rethrow;
  }
}

/// Parses [callback] as the Divine OAuth callback URL.
///
/// Rejects anything that is not exactly this host and path — a redirect the
/// session did not originate is not something to read parameters out of.
///
/// Throws [FormatException] when [callback] does not match.
Uri parseAppOAuthCallback(String callback) {
  if (_malformedPercentTriplet.hasMatch(callback) ||
      !_hasExactRawAuthority(callback)) {
    throw const FormatException(_invalidCallbackMessage);
  }

  late final Uri uri;
  try {
    uri = Uri.parse(callback);
  } on FormatException {
    throw const FormatException(_invalidCallbackMessage);
  }

  if (uri.scheme != appOAuthCallbackScheme ||
      uri.host != appOAuthCallbackHost ||
      uri.path != appOAuthCallbackPath ||
      uri.hasPort ||
      uri.authority.contains('@')) {
    throw const FormatException(_invalidCallbackMessage);
  }
  return uri;
}

bool _hasExactRawAuthority(String callback) {
  if (!callback.startsWith(_callbackPrefix)) return false;

  const authorityStart = _callbackPrefix.length;
  final terminator = callback.indexOf(_authorityTerminator, authorityStart);
  final authorityEnd = terminator == -1 ? callback.length : terminator;
  return callback.substring(authorityStart, authorityEnd) ==
      appOAuthCallbackHost;
}

Future<String> _authenticate({
  required String url,
  required String callbackUrlScheme,
  required FlutterWebAuth2Options options,
}) => FlutterWebAuth2.authenticate(
  url: url,
  callbackUrlScheme: callbackUrlScheme,
  options: options,
);
