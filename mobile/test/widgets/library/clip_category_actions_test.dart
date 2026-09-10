// ABOUTME: Tests for the clip-category bottom sheets
// ABOUTME: Covers the name prompt's blank-input guard and returned value

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/models/clip_category.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/library/clip_category_actions.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockClipsLibraryBloc
    extends MockBloc<ClipsLibraryEvent, ClipsLibraryState>
    implements ClipsLibraryBloc {}

void main() {
  final en = AppLocalizationsEn();

  group(ClipCategoryActions, () {
    late String? result;
    late bool completed;

    setUp(() {
      result = null;
      completed = false;
    });

    Widget buildHost({String? initialName}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  result = await ClipCategoryActions.showNamePrompt(
                    context: context,
                    title: en.libraryCategoryCreateTitle,
                    confirmLabel: en.libraryCategoryCreateAction,
                    initialName: initialName,
                  );
                  completed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    DivineButton confirmButton(WidgetTester tester) =>
        tester.widget<DivineButton>(
          find.ancestor(
            of: find.text(en.libraryCategoryCreateAction),
            matching: find.byType(DivineButton),
          ),
        );

    testWidgets('disables confirm until the name has usable text', (
      tester,
    ) async {
      await tester.pumpWidget(buildHost());
      await openSheet(tester);

      expect(confirmButton(tester).onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('clip_category_name_field')),
        '   ',
      );
      await tester.pump();
      expect(
        confirmButton(tester).onPressed,
        isNull,
        reason: 'whitespace is not a category name',
      );

      await tester.enterText(
        find.byKey(const Key('clip_category_name_field')),
        'Travel',
      );
      await tester.pump();
      expect(confirmButton(tester).onPressed, isNotNull);
    });

    testWidgets('returns the entered name', (tester) async {
      await tester.pumpWidget(buildHost());
      await openSheet(tester);

      await tester.enterText(
        find.byKey(const Key('clip_category_name_field')),
        'Travel',
      );
      await tester.pump();
      await tester.tap(find.text(en.libraryCategoryCreateAction));
      await tester.pumpAndSettle();

      expect(result, 'Travel');
    });

    testWidgets('seeds the field when renaming and returns null on dismiss', (
      tester,
    ) async {
      await tester.pumpWidget(buildHost(initialName: 'Travel'));
      await openSheet(tester);

      expect(find.text('Travel'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(result, isNull);
    });
  });

  group('$ClipCategoryActions.showMoveSheet', () {
    late ClipCategoryMoveChoice? choice;

    setUp(() => choice = null);

    Widget buildHost({required ClipCategoryArchiveOption archiveOption}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  choice = await ClipCategoryActions.showMoveSheet(
                    context: context,
                    categories: const [],
                    archiveOption: archiveOption,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('offers Archive for a selection in the working set', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildHost(archiveOption: ClipCategoryArchiveOption.archive),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text(en.libraryArchiveAction), findsOneWidget);
      expect(find.text(en.libraryUnarchiveAction), findsNothing);

      await tester.tap(find.text(en.libraryArchiveAction));
      await tester.pumpAndSettle();

      expect(choice, isA<ClipCategoryMoveToArchive>());
    });

    testWidgets('offers Unarchive for an already archived selection', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildHost(archiveOption: ClipCategoryArchiveOption.unarchive),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text(en.libraryUnarchiveAction), findsOneWidget);
      expect(find.text(en.libraryArchiveAction), findsNothing);

      await tester.tap(find.text(en.libraryUnarchiveAction));
      await tester.pumpAndSettle();

      expect(choice, isA<ClipCategoryMoveToUnarchive>());
    });
  });

  group('$ClipCategoryActions.showArchiveCategoryPrompt', () {
    late ClipArchiveCategoryChoice? choice;
    late bool completed;

    setUp(() {
      choice = null;
      completed = false;
    });

    Widget buildHost({String? categoryName, int categoryCount = 1}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  choice = await ClipCategoryActions.showArchiveCategoryPrompt(
                    context: context,
                    categoryCount: categoryCount,
                    categoryName: categoryName,
                  );
                  completed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('keeping the clip filed names the category it stays in', (
      tester,
    ) async {
      await tester.pumpWidget(buildHost(categoryName: 'Travel'));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        find.text(en.libraryArchiveKeepCategoryTitle(1)),
        findsOneWidget,
      );

      await tester.tap(
        find.text(en.libraryArchiveKeepCategoryAction('Travel')),
      );
      await tester.pumpAndSettle();

      expect(choice, ClipArchiveCategoryChoice.keep);
    });

    testWidgets('unfiling the clip is the other answer', (tester) async {
      await tester.pumpWidget(buildHost(categoryName: 'Travel'));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.text(en.libraryArchiveRemoveCategoryAction('Travel')),
      );
      await tester.pumpAndSettle();

      expect(choice, ClipArchiveCategoryChoice.remove);
    });

    testWidgets('a selection spanning categories drops the name', (
      tester,
    ) async {
      await tester.pumpWidget(buildHost(categoryCount: 3));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        find.text(en.libraryArchiveKeepCategoryActionMixed),
        findsOneWidget,
      );
      expect(
        find.text(en.libraryArchiveRemoveCategoryActionMixed),
        findsOneWidget,
      );
    });

    testWidgets('dismissing answers nothing, so the caller can cancel', (
      tester,
    ) async {
      await tester.pumpWidget(buildHost(categoryName: 'Travel'));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(choice, isNull);
    });
  });

  group('$ClipCategoryActions.runMoveFlow archiving', () {
    late _MockClipsLibraryBloc bloc;

    final travel = ClipCategory(
      id: 'cat-travel',
      name: 'Travel',
      createdAt: DateTime(2026),
    );

    final work = ClipCategory(
      id: 'cat-work',
      name: 'Work',
      createdAt: DateTime(2026),
    );

    DivineVideoClip clip(String id, {String? categoryId}) => DivineVideoClip(
      id: id,
      video: EditorVideo.file('/path/to/$id.mp4'),
      duration: const Duration(seconds: 5),
      recordedAt: DateTime(2026),
      targetAspectRatio: .vertical,
      originalAspectRatio: 9 / 16,
      categoryId: categoryId,
    );

    setUp(() {
      bloc = _MockClipsLibraryBloc();
      registerFallbackValue(
        const ClipsLibraryClipsArchiveChanged(clipIds: {}, archived: true),
      );
    });

    Widget buildHost(List<DivineVideoClip> clips) {
      when(() => bloc.state).thenReturn(
        ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: clips,
          categories: [travel, work],
        ),
      );
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => ClipCategoryActions.runMoveFlow(
                  context: context,
                  bloc: bloc,
                  clipIds: {for (final c in clips) c.id},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> openAndArchive(WidgetTester tester) async {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.libraryArchiveAction));
      await tester.pumpAndSettle();
    }

    ClipsLibraryClipsArchiveChanged capturedArchiveEvent() =>
        verify(() => bloc.add(captureAny())).captured.single
            as ClipsLibraryClipsArchiveChanged;

    testWidgets('an unfiled clip is archived without asking anything', (
      tester,
    ) async {
      await tester.pumpWidget(buildHost([clip('unfiled')]));
      await openAndArchive(tester);

      expect(find.text(en.libraryArchiveKeepCategoryTitle(1)), findsNothing);
      final event = capturedArchiveEvent();
      expect(event.archived, isTrue);
      expect(event.clearCategory, isFalse);
    });

    testWidgets('keeping the category archives without unfiling', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildHost([clip('filed', categoryId: travel.id)]),
      );
      await openAndArchive(tester);

      await tester.tap(
        find.text(en.libraryArchiveKeepCategoryAction('Travel')),
      );
      await tester.pumpAndSettle();

      expect(capturedArchiveEvent().clearCategory, isFalse);
    });

    testWidgets('removing the category archives and unfiles', (tester) async {
      await tester.pumpWidget(
        buildHost([clip('filed', categoryId: travel.id)]),
      );
      await openAndArchive(tester);

      await tester.tap(
        find.text(en.libraryArchiveRemoveCategoryAction('Travel')),
      );
      await tester.pumpAndSettle();

      expect(capturedArchiveEvent().clearCategory, isTrue);
    });

    testWidgets('several clips in one category are still one category', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildHost([
          clip('one', categoryId: travel.id),
          clip('two', categoryId: travel.id),
          clip('three', categoryId: travel.id),
        ]),
      );
      await openAndArchive(tester);

      // The title asks about the destination, so three clips filed under
      // Travel must not read as several categories while the buttons below
      // name exactly one.
      expect(find.text(en.libraryArchiveKeepCategoryTitle(1)), findsOneWidget);
      expect(
        find.text(en.libraryArchiveKeepCategoryAction('Travel')),
        findsOneWidget,
      );
    });

    testWidgets('a selection spanning two categories asks about both', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildHost([
          clip('one', categoryId: travel.id),
          clip('two', categoryId: work.id),
        ]),
      );
      await openAndArchive(tester);

      expect(find.text(en.libraryArchiveKeepCategoryTitle(2)), findsOneWidget);
      expect(
        find.text(en.libraryArchiveKeepCategoryActionMixed),
        findsOneWidget,
      );
    });

    testWidgets('dismissing the question cancels the archive entirely', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildHost([clip('filed', categoryId: travel.id)]),
      );
      await openAndArchive(tester);

      expect(find.text(en.libraryArchiveKeepCategoryTitle(1)), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      verifyNever(() => bloc.add(any()));
    });
  });
}
