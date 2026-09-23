// ABOUTME: Routes a creator into crossposting setup, native or web fallback.
// ABOUTME: Uses a ProviderContainer so it is safe after the invoking sheet
// ABOUTME: has been dismissed.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/config/app_config.dart';
import 'package:openvine/providers/crossposting_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/router.dart';

/// Opens crossposting settings natively, or the web setup page when in-app
/// OAuth is unsupported.
Future<void> openCrosspostingSetup(ProviderContainer container) async {
  final availability = await resolveCrosspostingAvailability(container);
  if (availability == CrosspostingAvailability.webOnly) {
    await container.read(crosspostingWebOpenerProvider)(
      Uri.parse(AppConfig.crossposterBaseUrl),
    );
    return;
  }
  await container
      .read(goRouterProvider)
      .push<void>(RoutePaths.crosspostingSettings);
}
