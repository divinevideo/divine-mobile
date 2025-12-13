// ABOUTME: Tests for SoundPickerModal - full-screen sound selection interface
// ABOUTME: Verifies search bar, sound list, None option, and dark theme

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/vine_sound.dart';
import 'package:openvine/widgets/sound_picker/sound_picker_modal.dart';

void main() {
  group('SoundPickerModal', () {
    late List<VineSound> testSounds;

    setUp(() {
      testSounds = [
        VineSound(
          id: 'sound-1',
          title: 'Cool Beat',
          assetPath: 'sounds/beat.mp3',
          duration: const Duration(seconds: 5),
          artist: 'DJ Test',
        ),
        VineSound(
          id: 'sound-2',
          title: 'Jazz Vibes',
          assetPath: 'sounds/jazz.mp3',
          duration: const Duration(seconds: 8),
          artist: 'Smooth Jazz',
        ),
        VineSound(
          id: 'sound-3',
          title: 'Rock Anthem',
          assetPath: 'sounds/rock.mp3',
          duration: const Duration(seconds: 6),
          artist: 'DJ Test',
        ),
      ];
    });

    testWidgets('displays search bar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SoundPickerModal(
              sounds: testSounds,
              selectedSoundId: null,
              onSoundSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search sounds...'), findsOneWidget);
    });

    testWidgets('displays all sounds in list', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SoundPickerModal(
              sounds: testSounds,
              selectedSoundId: null,
              onSoundSelected: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Cool Beat'), findsOneWidget);
      expect(find.text('Jazz Vibes'), findsOneWidget);
      expect(find.text('Rock Anthem'), findsOneWidget);
    });

    testWidgets('displays "None" option at top', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SoundPickerModal(
              sounds: testSounds,
              selectedSoundId: null,
              onSoundSelected: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('None'), findsOneWidget);
      expect(find.text('No background sound'), findsOneWidget);
    });

    testWidgets('filters sounds when searching', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SoundPickerModal(
              sounds: testSounds,
              selectedSoundId: null,
              onSoundSelected: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(find.byType(TextField), 'jazz');
      await tester.pumpAndSettle();

      // Should show only Jazz Vibes
      expect(find.text('Jazz Vibes'), findsOneWidget);
      expect(find.text('Cool Beat'), findsNothing);
      expect(find.text('Rock Anthem'), findsNothing);
    });

    testWidgets('calls onSoundSelected when sound tapped', (tester) async {
      String? selectedId;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SoundPickerModal(
              sounds: testSounds,
              selectedSoundId: null,
              onSoundSelected: (id) => selectedId = id,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap first sound
      await tester.tap(find.text('Cool Beat'));

      expect(selectedId, equals('sound-1'));
    });

    testWidgets('calls onSoundSelected with null when None tapped',
        (tester) async {
      String? selectedId = 'initial';

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SoundPickerModal(
              sounds: testSounds,
              selectedSoundId: 'sound-1',
              onSoundSelected: (id) => selectedId = id,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap None option
      await tester.tap(find.text('None'));

      expect(selectedId, isNull);
    });

    testWidgets('shows current selection with checkmark', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SoundPickerModal(
              sounds: testSounds,
              selectedSoundId: 'sound-2',
              onSoundSelected: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should have at least one checkmark for selected sound
      expect(find.byIcon(Icons.check_circle), findsWidgets);
    });

    testWidgets('uses dark theme throughout', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SoundPickerModal(
              sounds: testSounds,
              selectedSoundId: null,
              onSoundSelected: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final scaffold =
          tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, equals(Colors.black));
    });

    testWidgets('displays app bar with title', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SoundPickerModal(
              sounds: testSounds,
              selectedSoundId: null,
              onSoundSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Select Sound'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('closes modal when back button pressed', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SoundPickerModal(
                          sounds: testSounds,
                          selectedSoundId: null,
                          onSoundSelected: (_) {},
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open modal
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Select Sound'), findsOneWidget);

      // Press back button
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Select Sound'), findsNothing);
    });

    testWidgets('shows empty state when no sounds available', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SoundPickerModal(
              sounds: const [],
              selectedSoundId: null,
              onSoundSelected: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should still show None option even with empty list
      expect(find.text('None'), findsOneWidget);
    });

    testWidgets('clears search when search field is cleared', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SoundPickerModal(
              sounds: testSounds,
              selectedSoundId: null,
              onSoundSelected: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter search
      await tester.enterText(find.byType(TextField), 'jazz');
      await tester.pumpAndSettle();
      expect(find.text('Cool Beat'), findsNothing);

      // Clear search
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      // All sounds should be visible again
      expect(find.text('Cool Beat'), findsOneWidget);
      expect(find.text('Jazz Vibes'), findsOneWidget);
      expect(find.text('Rock Anthem'), findsOneWidget);
    });
  });
}
