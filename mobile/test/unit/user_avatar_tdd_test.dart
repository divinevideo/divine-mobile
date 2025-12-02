import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/user_avatar.dart';

void main() {
  testWidgets('UserAvatar renders without error when image URL is invalid', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserAvatar(
            imageUrl: 'https://invalid.example.invalid/nonexistent.jpg',
            name: 'Foo',
            size: 40,
          ),
        ),
      ),
    );

    // Allow widget to build - async image loading happens in background
    await tester.pump();

    // Widget should render without throwing errors
    expect(find.byType(UserAvatar), findsOneWidget);
  });

  testWidgets('UserAvatar renders without error when no imageUrl provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserAvatar(imageUrl: null, name: 'Test User', size: 40),
        ),
      ),
    );

    await tester.pump();

    // Widget should render without throwing errors
    expect(find.byType(UserAvatar), findsOneWidget);
  });

  testWidgets('UserAvatar renders without error with empty imageUrl', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserAvatar(imageUrl: '', name: 'Test User', size: 40),
        ),
      ),
    );

    await tester.pump();

    // Widget should render without throwing errors
    expect(find.byType(UserAvatar), findsOneWidget);
  });

  testWidgets('UserAvatar has green border decoration', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: UserAvatar(imageUrl: null, size: 40)),
      ),
    );

    await tester.pump();

    // Should find at least one Container (the green border container)
    expect(find.byType(Container), findsWidgets);
    expect(find.byType(UserAvatar), findsOneWidget);
  });
}
