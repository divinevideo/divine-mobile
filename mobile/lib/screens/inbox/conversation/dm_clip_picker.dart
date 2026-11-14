// ABOUTME: Opens the clip library as a sheet to pick clips to send in a DM,
// ABOUTME: behind a provider so the composer's clip path can be tested.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart'
    show LibraryClipTypeFilter;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/screens/library_screen.dart';

/// Opens the clip library to pick clips to send in a DM. Resolves to the
/// picked clips, or null when the sheet is dismissed.
typedef DmClipPicker = Future<List<DivineVideoClip>?> Function(
  BuildContext context,
);

/// The composer's clip picker.
///
/// A provider for the same reason as `dmVideoPickerProvider`: widget tests
/// hand back clips with a fake instead of driving the library sheet, whose
/// selection returns through go_router.
final dmClipPickerProvider = Provider<DmClipPicker>(
  (_) => pickDmClipsFromLibrary,
);

/// Shows the clip library in selection mode, video clips only.
Future<List<DivineVideoClip>?> pickDmClipsFromLibrary(BuildContext context) =>
    VineBottomSheet.show<List<DivineVideoClip>>(
      context: context,
      maxChildSize: 1,
      initialChildSize: 0.9,
      minChildSize: VineTheme.bottomSheetDismissFloor,
      buildScrollBody: (scrollController) => LibraryScreen(
        initialTabIndex: 1,
        selectionMode: true,
        clipTypeFilter: LibraryClipTypeFilter.video,
        scrollController: scrollController,
      ),
    );
