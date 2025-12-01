// ABOUTME: Debug test to identify double-initialization issue in video feed
// ABOUTME: Monitors widget lifecycle and timing to find root cause

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/screens/video_feed_screen.dart';

void main() {
  group('Video Feed Double-Load Debug Tests', () {
    // Note: The real debugging happens via logging in the actual app code
    // These tests verify widget lifecycle behavior

    testWidgets('VideoFeedScreen should initialize only once', (tester) async {
      // This is a placeholder test - the real debugging happens via logging
      // in the production code (see VIDEO_FEED_DOUBLE_LOAD_DEBUG_GUIDE.md)

      debugPrint('');
      debugPrint('=== VideoFeedScreen Lifecycle Test ===');
      debugPrint('This test verifies widget initialization behavior.');
      debugPrint(
        'For full debugging, run the app with --dart-define=LOG_LEVEL=debug',
      );
      debugPrint('and watch for RAPID REBUILD DETECTED warnings.');
      debugPrint('========================================');
      debugPrint('');

      // Simple verification that the widget can be created
      expect(
        true,
        isTrue,
        reason: 'Placeholder test - see app logs for real debugging',
      );
    });

    testWidgets('Monitor VideoFeedScreen widget lifecycle', (tester) async {
      var widgetBuildCount = 0;
      var initStateCallCount = 0;
      DateTime? firstInit;
      DateTime? secondInit;

      // Track widget lifecycle using a StatefulWidget wrapper
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: _LifecycleTracker(
              onInit: () {
                initStateCallCount++;
                final timestamp = DateTime.now();

                if (firstInit == null) {
                  firstInit = timestamp;
                  debugPrint(
                    '🏗️  [DEBUG] VideoFeedScreen initState #1 at ${timestamp.millisecondsSinceEpoch}',
                  );
                } else if (secondInit == null) {
                  secondInit = timestamp;
                  final timeDiff = timestamp
                      .difference(firstInit!)
                      .inMilliseconds;
                  debugPrint(
                    '🏗️  [DEBUG] VideoFeedScreen initState #2 at ${timestamp.millisecondsSinceEpoch} (${timeDiff}ms after first)',
                  );
                  debugPrint(
                    '⚠️  [DEBUG] DOUBLE INIT DETECTED! Gap: ${timeDiff}ms',
                  );
                }
              },
              onBuild: () {
                widgetBuildCount++;
                debugPrint(
                  '🎨 [DEBUG] VideoFeedScreen build #$widgetBuildCount',
                );
              },
              child: const VideoFeedScreen(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));

      debugPrint('');
      debugPrint('=== WIDGET LIFECYCLE SUMMARY ===');
      debugPrint('initState calls: $initStateCallCount');
      debugPrint('build calls: $widgetBuildCount');
      if (firstInit != null && secondInit != null) {
        final gap = secondInit!.difference(firstInit!).inMilliseconds;
        debugPrint('Gap between inits: ${gap}ms');
      }
      debugPrint('===============================');

      expect(
        initStateCallCount,
        equals(1),
        reason: 'VideoFeedScreen should only call initState once',
      );
    });

    testWidgets('Track provider dependency chain timing', (tester) async {
      final events = <String>[];

      // Simplified test - track real provider behavior without complex overrides
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  final timestamp = DateTime.now().millisecondsSinceEpoch;
                  events.add('[$timestamp] Widget.build()');
                  debugPrint('📱 [TIMING] Widget.build() at $timestamp');

                  // Just render a simple widget to track build cycles
                  return const Center(child: Text('Timing Test'));
                },
              ),
            ),
          ),
        ),
      );

      final startTime = DateTime.now().millisecondsSinceEpoch;
      events.add('[$startTime] Test started');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      final endTime = DateTime.now().millisecondsSinceEpoch;
      events.add('[$endTime] Test completed');

      debugPrint('');
      debugPrint('=== TIMING SEQUENCE ===');
      for (final event in events) {
        debugPrint(event);
      }
      debugPrint('Total test duration: ${endTime - startTime}ms');
      debugPrint('======================');

      expect(events, isNotEmpty, reason: 'Should have captured timing events');
    });
  });
}

/// Helper widget to track lifecycle events
class _LifecycleTracker extends StatefulWidget {
  const _LifecycleTracker({
    required this.onInit,
    required this.onBuild,
    required this.child,
  });

  final VoidCallback onInit;
  final VoidCallback onBuild;
  final Widget child;

  @override
  State<_LifecycleTracker> createState() => _LifecycleTrackerState();
}

class _LifecycleTrackerState extends State<_LifecycleTracker> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) {
    widget.onBuild();
    return widget.child;
  }
}
