// ABOUTME: Tests for SoundListItem widget - displays sound preview with play button
// ABOUTME: Verifies dark theme, selection state, and playback controls

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/vine_sound.dart';
import 'package:openvine/widgets/sound_picker/sound_list_item.dart';

void main() {
  group('SoundListItem', () {
    late VineSound testSound;

    setUp(() {
      testSound = VineSound(
        id: 'test-sound-1',
        title: 'Cool Beat',
        assetPath: 'sounds/beat.mp3',
        duration: const Duration(seconds: 5),
        artist: 'DJ Test',
      );
    });

    testWidgets('displays sound title and artist', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SoundListItem(
              sound: testSound,
              isSelected: false,
              isPlaying: false,
              onTap: () {},
              onPlayPause: () {},
            ),
          ),
        ),
      );

      expect(find.text('Cool Beat'), findsOneWidget);
      expect(find.text('DJ Test'), findsOneWidget);
    });

    testWidgets('displays duration in seconds', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SoundListItem(
              sound: testSound,
              isSelected: false,
              isPlaying: false,
              onTap: () {},
              onPlayPause: () {},
            ),
          ),
        ),
      );

      expect(find.text('5s'), findsOneWidget);
    });

    testWidgets('shows play icon when not playing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SoundListItem(
              sound: testSound,
              isSelected: false,
              isPlaying: false,
              onTap: () {},
              onPlayPause: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsNothing);
    });

    testWidgets('shows pause icon when playing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SoundListItem(
              sound: testSound,
              isSelected: false,
              isPlaying: true,
              onTap: () {},
              onPlayPause: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('shows checkmark when selected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SoundListItem(
              sound: testSound,
              isSelected: true,
              isPlaying: false,
              onTap: () {},
              onPlayPause: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('does not show checkmark when not selected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SoundListItem(
              sound: testSound,
              isSelected: false,
              isPlaying: false,
              onTap: () {},
              onPlayPause: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SoundListItem(
              sound: testSound,
              isSelected: false,
              isPlaying: false,
              onTap: () => tapped = true,
              onPlayPause: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byType(SoundListItem));
      expect(tapped, isTrue);
    });

    testWidgets('calls onPlayPause when play button tapped', (tester) async {
      var playPauseTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SoundListItem(
              sound: testSound,
              isSelected: false,
              isPlaying: false,
              onTap: () {},
              onPlayPause: () => playPauseTapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.play_arrow));
      expect(playPauseTapped, isTrue);
    });

    testWidgets('uses dark theme colors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SoundListItem(
              sound: testSound,
              isSelected: false,
              isPlaying: false,
              onTap: () {},
              onPlayPause: () {},
            ),
          ),
        ),
      );

      final listTile = tester.widget<ListTile>(find.byType(ListTile));

      // Title should use white text
      final title = listTile.title as Text;
      expect(title.style?.color, equals(Colors.white));

      // Subtitle should use grey text
      final subtitle = listTile.subtitle as Text;
      expect(subtitle.style?.color, equals(Colors.grey));
    });

    testWidgets('displays sound without artist', (tester) async {
      final soundWithoutArtist = VineSound(
        id: 'test-sound-2',
        title: 'No Artist Sound',
        assetPath: 'sounds/noartist.mp3',
        duration: const Duration(seconds: 3),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SoundListItem(
              sound: soundWithoutArtist,
              isSelected: false,
              isPlaying: false,
              onTap: () {},
              onPlayPause: () {},
            ),
          ),
        ),
      );

      expect(find.text('No Artist Sound'), findsOneWidget);
      expect(find.text('Unknown Artist'), findsOneWidget);
    });
  });
}
