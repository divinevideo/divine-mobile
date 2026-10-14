// ABOUTME: Settings toggle that backs up new camera recordings to the gallery
// ABOUTME: Explains that copies there are visible to other apps and backups

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/recording_gallery_backup/recording_gallery_backup_cubit.dart';
import 'package:openvine/blocs/recording_gallery_backup/recording_gallery_backup_state.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/permissions_providers.dart';
import 'package:openvine/providers/preferences_providers.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Opt-in backup of every new camera recording to the device gallery
/// (#10067).
///
/// Offered on Android and iOS only, like the gallery import that brings the
/// copies back.
class RecordingGalleryBackupSetting extends ConsumerWidget {
  const RecordingGalleryBackupSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(
      recordingGalleryBackupPreferenceServiceProvider,
    );
    final permissionsService = ref.watch(permissionsServiceProvider);
    return BlocProvider(
      key: ValueKey((preferences, permissionsService)),
      create: (_) => RecordingGalleryBackupCubit(
        preferences: preferences,
        permissionsService: permissionsService,
      )..load(),
      child: const _RecordingGalleryBackupView(),
    );
  }
}

/// The toggle, and the message when gallery access kept it off.
class _RecordingGalleryBackupView extends StatelessWidget {
  const _RecordingGalleryBackupView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<
      RecordingGalleryBackupCubit,
      RecordingGalleryBackupState
    >(
      listenWhen: (previous, current) =>
          current.permissionDenied && !previous.permissionDenied,
      listener: (context, _) {
        final cubit = context.read<RecordingGalleryBackupCubit>();
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.libraryGalleryPermissionDenied(
              cubit.galleryDestinationName,
            ),
            error: true,
            actionLabel: context.l10n.videoEditorVoiceOverOpenSettings,
            onActionPressed: () => runDetached(
              cubit.openAppSettings(),
              'open app settings for the gallery permission',
              logName: 'RecordingGalleryBackupSetting',
              category: LogCategory.ui,
            ),
          ),
        );
      },
      child: const _RecordingGalleryBackupTile(),
    );
  }
}

class _RecordingGalleryBackupTile extends StatelessWidget {
  const _RecordingGalleryBackupTile();

  @override
  Widget build(BuildContext context) {
    final isEnabled = context.select(
      (RecordingGalleryBackupCubit cubit) => cubit.state.isEnabled,
    );
    return DivineSwitchTile(
      leadingIcon: DivineIconName.images,
      title: context.l10n.settingsBackUpRecordings,
      subtitle: context.l10n.settingsBackUpRecordingsSubtitle,
      value: isEnabled,
      onChanged: (value) =>
          context.read<RecordingGalleryBackupCubit>().setEnabled(value),
    );
  }
}
