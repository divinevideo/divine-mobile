// ABOUTME: Screen displayed when user's location is in a geo-blocked region
// ABOUTME: Shows information about regional restrictions and legal compliance

import 'package:flutter/material.dart';
import 'package:openvine/services/geo_blocking_service.dart';
import 'package:openvine/theme/vine_theme.dart';

class GeoBlockedScreen extends StatelessWidget {
  final GeoBlockResponse geoInfo;

  const GeoBlockedScreen({super.key, required this.geoInfo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Icon(Icons.block, size: 80, color: VineTheme.vineGreen),
                const SizedBox(height: 32),

                // Title
                Text(
                  'Service Unavailable',
                  style: TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Region info
                Text(
                  geoInfo.region,
                  style: TextStyle(
                    color: VineTheme.vineGreen,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Explanation
                Text(
                  geoInfo.reason ??
                      'This service is not available in your region due to local regulations.',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Additional info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: VineTheme.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow('Country', geoInfo.country),
                      const SizedBox(height: 8),
                      _buildInfoRow('Region', geoInfo.region),
                      const SizedBox(height: 8),
                      _buildInfoRow('City', geoInfo.city),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Legal notice
                Text(
                  'We respect your local laws and regulations. '
                  'This restriction is based on your IP address location.',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        Text(
          value,
          style: TextStyle(
            color: VineTheme.whiteText,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
