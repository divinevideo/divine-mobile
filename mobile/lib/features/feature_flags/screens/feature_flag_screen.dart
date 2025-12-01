// ABOUTME: Settings screen for managing feature flag states and overrides
// ABOUTME: Provides UI for toggling flags, viewing descriptions, and resetting to defaults

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/services/cache_recovery_service.dart';

class FeatureFlagScreen extends ConsumerWidget {
  const FeatureFlagScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(featureFlagServiceProvider);
    final state = ref.watch(featureFlagStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feature Flags'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Reset all flags to defaults',
            onPressed: () async {
              await service.resetAllFlags();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Cache Recovery Section
          _buildCacheRecoverySection(context),
          const Divider(),
          // Feature Flags List
          Expanded(
            child: ListView.builder(
              itemCount: FeatureFlag.values.length,
              itemBuilder: (context, index) {
                final flag = FeatureFlag.values[index];
                final isEnabled = state[flag] ?? false;
                final hasUserOverride = service.hasUserOverride(flag);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 4.0,
                  ),
                  child: ListTile(
                    title: Text(
                      flag.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: hasUserOverride
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    subtitle: Text(
                      flag.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasUserOverride)
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Icon(
                              Icons.edit,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        Switch(
                          value: isEnabled,
                          onChanged: (value) async {
                            await service.setFlag(flag, value);
                          },
                          activeThumbColor: hasUserOverride
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        if (hasUserOverride)
                          IconButton(
                            icon: const Icon(Icons.undo, size: 20),
                            tooltip: 'Reset to default',
                            onPressed: () async {
                              await service.resetFlag(flag);
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCacheRecoverySection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'App Recovery',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'If the app is crashing or behaving strangely, try clearing the cache.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _clearCache(context),
                icon: const Icon(Icons.cleaning_services),
                label: const Text('Clear All Cache'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () => _showCacheInfo(context),
                icon: const Icon(Icons.info_outline),
                label: const Text('Cache Info'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache(BuildContext context) async {
    // Show confirmation dialog
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Clear All Cache?'),
            content: const Text(
              'This will clear all cached data including:\n'
              '• Notifications\n'
              '• User profiles\n'
              '• Bookmarks\n'
              '• Temporary files\n\n'
              'You will need to log in again. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Clear Cache'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    // Show loading dialog
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Clearing cache...'),
          ],
        ),
      ),
    );

    // Perform cache clearing
    final success = await CacheRecoveryService.clearAllCaches();

    // Close loading dialog
    if (!context.mounted) return;
    Navigator.pop(context);

    // Show result
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(success ? 'Success' : 'Error'),
        content: Text(
          success
              ? 'Cache cleared successfully. Please restart the app.'
              : 'Failed to clear some cache items. Check logs for details.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCacheInfo(BuildContext context) async {
    final cacheSize = await CacheRecoveryService.getCacheSizeInfo();

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cache Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total cache size: $cacheSize'),
            const SizedBox(height: 12),
            const Text(
              'Cache includes:\n'
              '• Notification history\n'
              '• User profile data\n'
              '• Video thumbnails\n'
              '• Temporary files\n'
              '• Database indexes',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
