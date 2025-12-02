// ABOUTME: Widget that checks geo-blocking status before showing main app
// ABOUTME: Displays GeoBlockedScreen if user is in a restricted region

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/geo_blocked_screen.dart';
import 'package:openvine/services/geo_blocking_service.dart';
import 'package:openvine/utils/unified_logger.dart';

class GeoBlockingGate extends ConsumerStatefulWidget {
  final Widget child;

  const GeoBlockingGate({super.key, required this.child});

  @override
  ConsumerState<GeoBlockingGate> createState() => _GeoBlockingGateState();
}

class _GeoBlockingGateState extends ConsumerState<GeoBlockingGate> {
  GeoBlockResponse? _geoStatus;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkGeoBlocking();
  }

  Future<void> _checkGeoBlocking() async {
    try {
      final geoService = ref.read(geoBlockingServiceProvider);
      final status = await geoService.checkGeoBlock();

      if (mounted) {
        setState(() {
          _geoStatus = status;
          _isChecking = false;
        });
      }
    } catch (e) {
      Log.error(
        'Geo-blocking check failed: $e',
        name: 'GeoBlockingGate',
        category: LogCategory.system,
      );

      // Fail-open: if check fails, allow access
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while checking
    if (_isChecking) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    // Show blocked screen if user is geo-blocked
    if (_geoStatus?.blocked == true) {
      return GeoBlockedScreen(geoInfo: _geoStatus!);
    }

    // Otherwise, show main app
    return widget.child;
  }
}
