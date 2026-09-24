// ABOUTME: Bottom sheet shown when gallery/camera-roll permission is denied.
// ABOUTME: Offers to open system settings or skip gallery saves permanently.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:permissions_service/permissions_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key that, when `true`, suppresses the gallery-permission
/// sheet and silently skips gallery saves.
const _kGalleryPermissionDismissedKey = 'gallery_permission_dismissed_forever';

/// Result of showing the gallery-permission bottom sheet.
enum GalleryPermissionChoice {
  /// User tapped "Open Settings" and may have granted permission.
  openedSettings,

  /// User granted permission via the OS dialog.
  granted,

  /// User tapped "Don't Ask Again" — skip gallery saves from now on.
  dismissedForever,

  /// User tapped "Not Now" or swiped away — skip this time only.
  skipped,
}

/// Returns `true` when the user has previously chosen "Don't Ask Again".
Future<bool> isGalleryPermissionDismissedForever() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kGalleryPermissionDismissedKey) ?? false;
}

/// Shows a bottom sheet explaining that gallery permission is needed.
///
/// Returns a [GalleryPermissionChoice] describing the user's decision.
/// If the user chose [GalleryPermissionChoice.openedSettings] and
/// subsequently granted access, the caller should retry the save.
Future<GalleryPermissionChoice> showGalleryPermissionSheet(
  BuildContext context, {
  required PermissionsService permissionsService,
}) async {
  final destination = GallerySaveService.destinationName;
  final status = await permissionsService.checkGalleryStatus();

  // Permission may have been granted since the save attempt.
  if (status == PermissionStatus.granted) {
    return GalleryPermissionChoice.granted;
  } else if (!context.mounted) {
    return GalleryPermissionChoice.skipped;
  }

  final requiresSettings = status == PermissionStatus.requiresSettings;

  // Resolved while the caller is still mounted, then held: every button here
  // answers after an await — a round trip through Settings, a platform
  // permission prompt, a preferences write — by which point the opening
  // widget may be gone while this sheet remains open. Only pop if this exact
  // sheet is still the active route, so a late response cannot pop a new page.
  final navigator = Navigator.of(context);
  Route<dynamic>? sheetRoute;

  void popSheet(GalleryPermissionChoice choice) {
    final route = sheetRoute;
    if (route != null && route.isActive && route.isCurrent) {
      navigator.pop(choice);
    }
  }

  final result = await VineBottomSheet.show<GalleryPermissionChoice>(
    context: context,
    scrollable: false,
    showHeaderDivider: false,
    body: Builder(
      builder: (sheetContext) {
        sheetRoute = ModalRoute.of(sheetContext);
        return VineBottomSheetPrompt(
          sticker: DivineStickerName.alert,
          // TODO(l10n): Replace with context.l10n when localization is added.
          title: 'Let us save your videos',
          subtitle: requiresSettings
              ? 'Flip on $destination access in Settings so we can save your videos.'
              : 'To keep a copy of your videos on your device, '
                    'we need $destination access.',
          primaryButtonText: requiresSettings
              ? 'Open Settings'
              : 'Allow Access',
          onPrimaryPressed: requiresSettings
              ? () async {
                  await permissionsService.openAppSettings();
                  popSheet(GalleryPermissionChoice.openedSettings);
                }
              : () async {
                  final requested = await permissionsService
                      .requestGalleryPermission();
                  popSheet(
                    requested == PermissionStatus.granted
                        ? GalleryPermissionChoice.granted
                        : GalleryPermissionChoice.skipped,
                  );
                },
          secondaryButtonText: 'Not Now',
          onSecondaryPressed: () {
            popSheet(GalleryPermissionChoice.skipped);
          },
          tertiaryButtonText: "Don't Ask Again",
          onTertiaryPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(_kGalleryPermissionDismissedKey, true);
            popSheet(GalleryPermissionChoice.dismissedForever);
          },
        );
      },
    ),
  );

  return result ?? GalleryPermissionChoice.skipped;
}
