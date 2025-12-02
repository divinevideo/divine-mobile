// ABOUTME: Golden tests for UserAvatar widget to verify visual consistency
// ABOUTME: Tests various states: with image, without image, different sizes, and with initials

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:openvine/widgets/user_avatar.dart';
import '../../helpers/golden_test_devices.dart';

void main() {
  group('UserAvatar Golden Tests', () {
    setUpAll(() async {
      await loadAppFonts();
    });

    testGoldens('UserAvatar renders correctly with different states', (
      tester,
    ) async {
      final builder = GoldenBuilder.grid(columns: 3, widthToHeightRatio: 1)
        ..addScenario(
          'With Name Only',
          const UserAvatar(name: 'John Doe', size: 60),
        )
        ..addScenario('With Empty Name', const UserAvatar(name: '', size: 60))
        ..addScenario('No Name or Image', const UserAvatar(size: 60))
        ..addScenario('Small Size', const UserAvatar(name: 'Alice', size: 30))
        ..addScenario('Medium Size', const UserAvatar(name: 'Bob', size: 50))
        ..addScenario('Large Size', const UserAvatar(name: 'Charlie', size: 80))
        ..addScenario(
          'Different Initial A',
          const UserAvatar(name: 'Alice Anderson', size: 60),
        )
        ..addScenario(
          'Different Initial Z',
          const UserAvatar(name: 'Zack Zimmerman', size: 60),
        )
        ..addScenario(
          'Single Letter Name',
          const UserAvatar(name: 'X', size: 60),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: materialAppWrapper(theme: ThemeData.light()),
      );

      await screenMatchesGolden(tester, 'user_avatar_states');
    });

    testGoldens('UserAvatar renders on multiple devices', (tester) async {
      const widget = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            UserAvatar(name: 'Sample User', size: 40),
            SizedBox(height: 20),
            UserAvatar(name: 'Another User', size: 60),
            SizedBox(height: 20),
            UserAvatar(name: 'Test User', size: 80),
          ],
        ),
      );

      await tester.pumpWidgetBuilder(
        widget,
        wrapper: materialAppWrapper(theme: ThemeData.light()),
      );

      await multiScreenGolden(
        tester,
        'user_avatar_multi_device',
        devices: GoldenTestDevices.minimalDevices,
      );
    });

    testGoldens('UserAvatar with tap interaction visual feedback', (
      tester,
    ) async {
      bool tapped = false;

      final widget = StatefulBuilder(
        builder: (context, setState) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: tapped ? Colors.blue.shade50 : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: UserAvatar(
                name: 'Tappable User',
                size: 60,
                onTap: () {
                  setState(() {
                    tapped = !tapped;
                  });
                },
              ),
            ),
          );
        },
      );

      await tester.pumpWidgetBuilder(
        widget,
        wrapper: materialAppWrapper(theme: ThemeData.light()),
      );

      // Capture before tap
      await screenMatchesGolden(tester, 'user_avatar_before_tap');

      // Simulate tap
      await tester.tap(find.byType(UserAvatar));
      await tester.pumpAndSettle();

      // Capture after tap
      await screenMatchesGolden(tester, 'user_avatar_after_tap');
    });

    testGoldens('UserAvatar sizes comparison', (tester) async {
      final sizes = [20.0, 30.0, 40.0, 50.0, 60.0, 80.0, 100.0, 120.0];

      final widget = Center(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: sizes.map((size) {
            return UserAvatar(name: 'User', size: size);
          }).toList(),
        ),
      );

      await tester.pumpWidgetBuilder(
        widget,
        wrapper: materialAppWrapper(theme: ThemeData.light()),
        surfaceSize: const Size(400, 400),
      );

      await screenMatchesGolden(tester, 'user_avatar_sizes');
    });

    testGoldens('UserAvatar dark mode comparison', (tester) async {
      final builder = GoldenBuilder.column()
        ..addScenario(
          'Light Theme',
          Theme(
            data: ThemeData.light(),
            child: Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: const UserAvatar(name: 'Theme User', size: 60),
            ),
          ),
        )
        ..addScenario(
          'Dark Theme',
          Theme(
            data: ThemeData.dark(),
            child: Container(
              padding: const EdgeInsets.all(20),
              color: Colors.black,
              child: const UserAvatar(name: 'Theme User', size: 60),
            ),
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: materialAppWrapper(),
      );

      await screenMatchesGolden(tester, 'user_avatar_themes');
    });
  });
}
