// ABOUTME: Service to listen for email verification deep links
// ABOUTME: Handles verify-email redirects from login.divine.video

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service to listen for email verification redirects (deeplinks)
class EmailVerificationListener {
  EmailVerificationListener(this.ref);
  final Ref ref;

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  /// Initialize listeners for both cold starts and background resumes
  void initialize() {
    Log.info(
      'Initializing email verification listener...',
      name: '$EmailVerificationListener',
      category: LogCategory.auth,
    );

    // Handle link that launches the app from a closed state
    runDetached(
      _handleInitialLink(),
      'handle the initial email-verification link',
      logName: '$EmailVerificationListener',
      category: LogCategory.auth,
    );

    // Handle links while app is running in background
    _subscription = _appLinks.uriLinkStream.listen((uri) {
      runDetached(
        handleUri(uri),
        'handle an email-verification link',
        logName: '$EmailVerificationListener',
        category: LogCategory.auth,
      );
    });
  }

  Future<void> _handleInitialLink() async {
    final uri = await _appLinks.getInitialLink();
    if (uri != null) await handleUri(uri);
  }

  @visibleForTesting
  Future<void> handleUri(Uri uri) async {
    Log.info(
      'Callback from host ${uri.host} path: ${uri.path}',
      name: '$EmailVerificationListener',
      category: LogCategory.auth,
    );

    if (uri.host != 'login.divine.video' ||
        !uri.path.startsWith(RoutePaths.emailVerification)) {
      return;
    }

    Log.info(
      'Email verification callback detected: $uri',
      name: '$EmailVerificationListener',
      category: LogCategory.auth,
    );

    final params = uri.queryParameters;

    if (params.containsKey('token')) {
      final token = params['token']!;

      // Navigate to the verification screen which handles verifyEmail()
      // and shows appropriate feedback (success, error, expired).
      // If the screen is already showing (polling mode after registration),
      // didUpdateWidget() fires and calls verifyEmail() for the token.
      // If the screen is freshly opened (standalone deep link), initState()
      // starts either auto-login or standard token verification.
      final router = ref.read(goRouterProvider);
      router.go('${RoutePaths.emailVerification}?token=$token');
    }
  }

  void dispose() {
    if (_subscription != null) {
      runDetached(
        _subscription!.cancel(),
        'cancel the email-verification link subscription',
        logName: '$EmailVerificationListener',
        category: LogCategory.auth,
      );
      _subscription = null;
    }
    Log.info(
      '$EmailVerificationListener disposed',
      name: '$EmailVerificationListener',
      category: LogCategory.auth,
    );
  }
}
