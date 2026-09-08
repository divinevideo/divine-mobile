import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/widgets/video_metadata/modes/edit/video_metadata_edit_stack.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_form_fields.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(VideoMetadataEditStack, () {
    testWidgets('body scroll dismisses the keyboard', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();

      await tester.pumpWidget(_buildSubject(preferences));
      await tester.pump();

      final scrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(
        scrollView.keyboardDismissBehavior,
        ScrollViewKeyboardDismissBehavior.onDrag,
      );
    });

    testWidgets('disables caption mention autocomplete', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();

      await tester.pumpWidget(_buildSubject(preferences));
      await tester.pump();

      final form = tester.widget<VideoMetadataFormFields>(
        find.byType(VideoMetadataFormFields),
      );
      expect(form.enableCaptionMentionAutocomplete, isFalse);
    });
  });
}

Widget _buildSubject(SharedPreferences preferences) {
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: VideoMetadataEditStack(
        video: VideoEvent(
          id: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          pubkey:
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          createdAt: 1757385263,
          content: 'Description',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
          title: 'Title',
        ),
      ),
    ),
  );
}
