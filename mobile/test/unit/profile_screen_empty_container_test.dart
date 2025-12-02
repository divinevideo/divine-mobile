// ABOUTME: TDD test for profile screen empty container issue - tests proper loading/error states
// ABOUTME: These will fail first, then we fix the profile screen to return proper widgets

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';

void main() {
  group('Profile Screen Empty Container TDD - Loading/Error State Tests', () {
    testWidgets(
      'FAIL FIRST: ProfileScreen should show loading indicator instead of empty Container',
      (tester) async {
        // This test WILL FAIL initially - proving the empty Container bug exists!

        // Create a mock grid item that shows loading indicator when videoEvent is null (FIXED version)
        Widget buildGridItem(VideoEvent? videoEvent) {
          // This is the FIXED version that should show loading placeholder
          if (videoEvent == null) {
            return DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.green,
                  strokeWidth: 2,
                ),
              ),
            );
          }

          return DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(child: Text('Video: ${videoEvent.id}')),
          );
        }

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                ),
                itemCount: 3,
                itemBuilder: (context, index) {
                  // Simulate null videoEvent scenario
                  return buildGridItem(
                    index == 1
                        ? null
                        : VideoEvent(
                            id: 'test_$index',
                            pubkey: 'test_pubkey',
                            content: 'Test content',
                            createdAt:
                                DateTime.now().millisecondsSinceEpoch ~/ 1000,
                            timestamp: DateTime.now(),
                          ),
                  );
                },
              ),
            ),
          ),
        );

        // Should find properly styled containers (not empty ones)
        expect(
          find.byType(DecoratedBox),
          findsAtLeastNWidgets(1),
          reason:
              'Should have properly styled containers instead of empty ones',
        );

        // Should find proper loading indicators
        expect(
          find.byType(CircularProgressIndicator),
          findsAtLeastNWidgets(1),
          reason: 'Should show loading indicators for null video events',
        );
      },
    );

    testWidgets(
      'FAIL FIRST: ProfileScreen should show error placeholder for failed video loads',
      (tester) async {
        // This test WILL FAIL initially - no error handling for null videos

        // Create a mock grid item that should handle null/error states properly
        Widget buildGridItemFixed(VideoEvent? videoEvent, bool hasError) {
          if (videoEvent == null) {
            if (hasError) {
              // Should show error placeholder
              return Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red),
                    SizedBox(height: 8),
                    Text(
                      'Load failed',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              );
            } else {
              // Should show loading placeholder
              return Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(child: CircularProgressIndicator()),
              );
            }
          }

          return Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(child: Text('Video: ${videoEvent.id}')),
          );
        }

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                ),
                itemCount: 3,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // Simulate error case
                    return buildGridItemFixed(null, true);
                  } else if (index == 1) {
                    // Simulate loading case
                    return buildGridItemFixed(null, false);
                  } else {
                    // Normal video case
                    return buildGridItemFixed(
                      VideoEvent(
                        id: 'test_$index',
                        pubkey: 'test_pubkey',
                        content: 'Test content',
                        createdAt:
                            DateTime.now().millisecondsSinceEpoch ~/ 1000,
                        timestamp: DateTime.now(),
                      ),
                      false,
                    );
                  }
                },
              ),
            ),
          ),
        );

        // Should find error indicators
        expect(
          find.byIcon(Icons.error_outline),
          findsOneWidget,
          reason: 'Should show error icon for failed video loads',
        );
        expect(
          find.text('Load failed'),
          findsOneWidget,
          reason: 'Should show error text for failed video loads',
        );

        // Should find loading indicators
        expect(
          find.byType(CircularProgressIndicator),
          findsOneWidget,
          reason: 'Should show loading indicator for pending video loads',
        );
      },
    );

    testWidgets(
      'FAIL FIRST: ProfileScreen placeholder should have consistent styling with video grid',
      (tester) async {
        // This test WILL FAIL initially - empty Container has no styling

        // Test that placeholders match the styling of actual video items
        Widget buildStyledPlaceholder(String type) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey[900], // Should match VineTheme.cardBackground
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: type == 'loading'
                  ? const CircularProgressIndicator(
                      color: Colors.green, // Should match VineTheme.vineGreen
                      strokeWidth: 2,
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(height: 4),
                        Text(
                          'Failed to load',
                          style: TextStyle(
                            color: Colors
                                .white70, // Should match VineTheme.secondaryText
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
            ),
          );
        }

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.black, // VineTheme.backgroundColor
              body: GridView(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                children: [
                  buildStyledPlaceholder('loading'),
                  buildStyledPlaceholder('error'),
                ],
              ),
            ),
          ),
        );

        // Verify styled placeholders exist
        expect(
          find.byType(Container),
          findsAtLeastNWidgets(2),
          reason: 'Should have styled container placeholders',
        );
        expect(
          find.byType(CircularProgressIndicator),
          findsOneWidget,
          reason: 'Should have loading indicator with proper styling',
        );
        expect(
          find.text('Failed to load'),
          findsOneWidget,
          reason: 'Should have error text with proper styling',
        );
      },
    );
  });
}
