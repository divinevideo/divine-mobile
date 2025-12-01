// ABOUTME: Widget that displays a transition message between following and discovery feeds
// ABOUTME: Shows users they've seen all videos from people they follow

import 'package:flutter/material.dart';

/// Widget that displays a transition message when moving from following to discovery feed
class FeedTransitionIndicator extends StatelessWidget {
  const FeedTransitionIndicator({
    required this.followingCount,
    required this.discoveryCount,
    super.key,
  });
  final int followingCount;
  final int discoveryCount;

  @override
  Widget build(BuildContext context) => Container(
    height: 200,
    color: Colors.black,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Colors.green.shade400,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              "You've seen all videos from people you follow!",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "From here on we're showing you random vines until you follow somebody new or there are new posts by people you're following.",
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade400),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStat(context, 'Following videos', followingCount),
                const SizedBox(width: 32),
                _buildStat(context, 'Discovery videos', discoveryCount),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildStat(BuildContext context, String label, int count) => Column(
    children: [
      Text(
        count.toString(),
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
      ),
    ],
  );
}
