import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_metadata_stripper/image_metadata_stripper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/image_attachment_picker.dart';

class _MockImagePicker extends Mock implements ImagePicker {}

void main() {
  late _MockImagePicker mockPicker;
  late AppLocalizations l10n;

  setUp(() {
    mockPicker = _MockImagePicker();
    ImageAttachmentPicker.imagePicker = mockPicker;
    // Identity by default so unrelated tests are not forced through the
    // platform stripper; the metadata tests below override it.
    ImageAttachmentPicker.stripAttachmentMetadata = (file) async => file;
    l10n = lookupAppLocalizations(const Locale('en'));
  });

  tearDown(() {
    ImageAttachmentPicker.imagePicker = ImagePicker();
    ImageAttachmentPicker.stripAttachmentMetadata =
        ImageMetadataStripper.stripMetadataInPlaceOrThrow;
  });

  Widget buildTestWidget({
    int maxImages = 3,
    bool enabled = true,
    ValueChanged<List<XFile>>? onChanged,
  }) {
    return MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ImageAttachmentPicker(
          maxImages: maxImages,
          enabled: enabled,
          onChanged: onChanged ?? (_) {},
        ),
      ),
    );
  }

  group('ImageAttachmentPicker', () {
    testWidgets('renders add button on mobile', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(buildTestWidget());
        expect(
          find.bySemanticsLabel(l10n.bugReportAttachImages),
          findsOneWidget,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('renders SizedBox.shrink on non-mobile', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await tester.pumpWidget(buildTestWidget());
        expect(find.bySemanticsLabel(l10n.bugReportAttachImages), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('calls onChanged when images are picked', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final pickedFiles = [XFile('/tmp/img1.jpg')];
        when(
          () => mockPicker.pickMultiImage(
            maxWidth: any(named: 'maxWidth'),
            imageQuality: any(named: 'imageQuality'),
          ),
        ).thenAnswer((_) async => pickedFiles);

        List<XFile>? result;
        await tester.pumpWidget(
          buildTestWidget(onChanged: (files) => result = files),
        );

        await tester.tap(find.bySemanticsLabel(l10n.bugReportAttachImages));
        await tester.pumpAndSettle();

        expect(result, isNotNull);
        expect(result!.length, 1);
        expect(result!.first.path, '/tmp/img1.jpg');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('delivers sanitized attachment paths, not the originals', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        when(
          () => mockPicker.pickMultiImage(
            maxWidth: any(named: 'maxWidth'),
            imageQuality: any(named: 'imageQuality'),
          ),
        ).thenAnswer((_) async => [XFile('/tmp/original.jpg')]);
        ImageAttachmentPicker.stripAttachmentMetadata = (file) async =>
            File('/tmp/sanitized.jpg');

        List<XFile>? result;
        await tester.pumpWidget(
          buildTestWidget(onChanged: (files) => result = files),
        );

        await tester.tap(find.bySemanticsLabel(l10n.bugReportAttachImages));
        await tester.pumpAndSettle();

        expect(result, isNotNull);
        expect(result!.single.path, '/tmp/sanitized.jpg');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('drops an attachment whose metadata cannot be stripped', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        when(
          () => mockPicker.pickMultiImage(
            maxWidth: any(named: 'maxWidth'),
            imageQuality: any(named: 'imageQuality'),
          ),
        ).thenAnswer((_) async => [XFile('/tmp/original.jpg')]);
        ImageAttachmentPicker.stripAttachmentMetadata = (file) async =>
            throw const FileSystemException('strip failed');

        List<XFile>? result;
        await tester.pumpWidget(
          buildTestWidget(onChanged: (files) => result = files),
        );

        await tester.tap(find.bySemanticsLabel(l10n.bugReportAttachImages));
        await tester.pump();

        expect(result, isNull);
        expect(find.text(l10n.bugReportUploadFailed), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('shows an error snackbar when image picker throws', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        when(
          () => mockPicker.pickMultiImage(
            maxWidth: any(named: 'maxWidth'),
            imageQuality: any(named: 'imageQuality'),
          ),
        ).thenThrow(Exception('picker failed'));

        await tester.pumpWidget(buildTestWidget());

        await tester.tap(find.bySemanticsLabel(l10n.bugReportAttachImages));
        await tester.pump();

        expect(find.text(l10n.bugReportUploadFailed), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('truncates selection to remaining slots', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final fourFiles = [
          XFile('/tmp/a.jpg'),
          XFile('/tmp/b.jpg'),
          XFile('/tmp/c.jpg'),
          XFile('/tmp/d.jpg'),
        ];
        when(
          () => mockPicker.pickMultiImage(
            maxWidth: any(named: 'maxWidth'),
            imageQuality: any(named: 'imageQuality'),
          ),
        ).thenAnswer((_) async => fourFiles);

        List<XFile>? result;
        await tester.pumpWidget(
          buildTestWidget(onChanged: (files) => result = files),
        );

        await tester.tap(find.bySemanticsLabel(l10n.bugReportAttachImages));
        await tester.pumpAndSettle();

        expect(result!.length, 3);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('hides add button at max count', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final threeFiles = [
          XFile('/tmp/a.jpg'),
          XFile('/tmp/b.jpg'),
          XFile('/tmp/c.jpg'),
        ];
        when(
          () => mockPicker.pickMultiImage(
            maxWidth: any(named: 'maxWidth'),
            imageQuality: any(named: 'imageQuality'),
          ),
        ).thenAnswer((_) async => threeFiles);

        await tester.pumpWidget(buildTestWidget());

        await tester.tap(find.bySemanticsLabel(l10n.bugReportAttachImages));
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel(l10n.bugReportAttachImages), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('remove button removes correct image', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final twoFiles = [XFile('/tmp/a.jpg'), XFile('/tmp/b.jpg')];
        when(
          () => mockPicker.pickMultiImage(
            maxWidth: any(named: 'maxWidth'),
            imageQuality: any(named: 'imageQuality'),
          ),
        ).thenAnswer((_) async => twoFiles);

        List<XFile>? lastResult;
        await tester.pumpWidget(
          buildTestWidget(onChanged: (files) => lastResult = files),
        );

        await tester.tap(find.bySemanticsLabel(l10n.bugReportAttachImages));
        await tester.pumpAndSettle();

        expect(lastResult!.length, 2);

        await tester.tap(
          find.bySemanticsLabel(l10n.bugReportRemoveImage).first,
        );
        await tester.pumpAndSettle();

        expect(lastResult!.length, 1);
        expect(lastResult!.first.path, '/tmp/b.jpg');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('has correct semantics label on add button', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(buildTestWidget());

        final semantics = tester.getSemantics(
          find.bySemanticsLabel(l10n.bugReportAttachImages),
        );
        expect(semantics.label, l10n.bugReportAttachImages);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('disabled state uses themed disabled icon color', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(buildTestWidget(enabled: false));

        final icon = tester.widget<DivineIcon>(
          find.descendant(
            of: find.bySemanticsLabel(l10n.bugReportAttachImages),
            matching: find.byType(DivineIcon),
          ),
        );
        expect(icon.color, VineTheme.lightText);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('remove button keeps a 48dp hit target', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final pickedFiles = [XFile('/tmp/img1.jpg')];
        when(
          () => mockPicker.pickMultiImage(
            maxWidth: any(named: 'maxWidth'),
            imageQuality: any(named: 'imageQuality'),
          ),
        ).thenAnswer((_) async => pickedFiles);

        await tester.pumpWidget(buildTestWidget());

        await tester.tap(find.bySemanticsLabel(l10n.bugReportAttachImages));
        await tester.pumpAndSettle();

        final hitTarget = find.descendant(
          of: find.bySemanticsLabel(l10n.bugReportRemoveImage),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SizedBox && widget.width == 48 && widget.height == 48,
          ),
        );

        expect(hitTarget, findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
