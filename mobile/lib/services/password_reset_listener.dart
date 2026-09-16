import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service to listen for Password Reset redirects (deeplinks)
class PasswordResetListener {
  PasswordResetListener(this.ref);
  final Ref ref;

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  /// Initialize listeners for both cold starts and background resumes
  void initialize() {
    Log.info(
      '🔑 Initializing password reset listener...',
      name: '$PasswordResetListener',
    );

    // Handle link that launches the app from a closed state
    runDetached(
      _handleInitialLink(),
      'handle the initial password-reset link',
      logName: '$PasswordResetListener',
      category: LogCategory.auth,
    );

    // Handle links while app is running in background
    _subscription = _appLinks.uriLinkStream.listen((uri) {
      runDetached(
        handleUri(uri),
        'handle a password-reset link',
        logName: '$PasswordResetListener',
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
      '🔑 callback from host ${uri.host} path: ${uri.path}',
      name: '$PasswordResetListener',
    );

    if (uri.host != 'login.divine.video' ||
        !uri.path.startsWith(RoutePaths.resetPassword)) {
      return;
    }

    // Log path only — query params can contain the account email (PII).
    Log.info(
      '🔑 Password reset callback detected for path: ${uri.path}',
      name: '$PasswordResetListener',
    );

    final params = uri.queryParameters;

    if (params.containsKey('token')) {
      final token = params['token']!;
      final email = params['email'];
      final router = ref.read(goRouterProvider);
      final buffer = StringBuffer(RoutePaths.welcomeResetPassword)
        ..write('?token=')
        ..write(Uri.encodeQueryComponent(token));
      if (email != null && email.isNotEmpty) {
        buffer
          ..write('&email=')
          ..write(Uri.encodeQueryComponent(email));
      }
      router.go(buffer.toString());
    }
  }

  void dispose() {
    if (_subscription != null) {
      runDetached(
        _subscription!.cancel(),
        'cancel the password-reset link subscription',
        logName: '$PasswordResetListener',
        category: LogCategory.auth,
      );
      _subscription = null;
    }
    Log.info(
      '🔑 $PasswordResetListener disposed',
      name: '$PasswordResetListener',
    );
  }
}
