// ABOUTME: The macOS menu bar: the standard app, Edit, View, Window and Help
// ABOUTME: menus plus a Video menu that drives the feed with keyboard focus

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/ui/back_on_escape.dart';
import 'package:openvine/ui/feed_keyboard_shortcuts.dart';

/// Gives the macOS app its menu bar, with a Video menu for the feed commands
/// beside the menus every Mac app has.
///
/// A [PlatformMenuBar] replaces the whole native menu bar, so the app, Edit,
/// View, Window and Help menus are rebuilt here. The app, View and Window
/// items are the system's own. The Edit and Video items run the same intent
/// their key does where the keyboard focus is, so the Edit items reach the
/// focused text field and the Video items reach the feed with focus, and do
/// nothing anywhere else.
///
/// On every other platform this returns [child] unchanged.
class MacosMenuBar extends StatelessWidget {
  const MacosMenuBar({
    required this.onOpenSupportCenter,
    required this.child,
    super.key,
  });

  /// Called by the Help menu's Support Center item.
  final VoidCallback onOpenSupportCenter;

  /// The app.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return child;
    final l10n = context.l10n;
    final isMuted = context.select(
      (VideoVolumeCubit cubit) => cubit.state.isMuted,
    );
    return PlatformMenuBar(
      menus: [
        const PlatformMenu(
          // macOS titles the first menu with the app's name whatever this
          // says, and the items are the system's.
          label: 'Divine',
          menus: [
            PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.about,
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.servicesSubmenu,
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.hide,
                ),
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.hideOtherApplications,
                ),
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.showAllApplications,
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.quit,
                ),
              ],
            ),
          ],
        ),
        PlatformMenu(
          label: l10n.menuBarEdit,
          menus: [
            PlatformMenuItemGroup(
              members: [
                _intentItem(
                  label: l10n.menuBarUndo,
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyZ,
                    meta: true,
                  ),
                  intent: const UndoTextIntent(SelectionChangedCause.keyboard),
                ),
                _intentItem(
                  label: l10n.menuBarRedo,
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyZ,
                    meta: true,
                    shift: true,
                  ),
                  intent: const RedoTextIntent(SelectionChangedCause.keyboard),
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                _intentItem(
                  label: l10n.menuBarCut,
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyX,
                    meta: true,
                  ),
                  intent: const CopySelectionTextIntent.cut(
                    SelectionChangedCause.keyboard,
                  ),
                ),
                _intentItem(
                  label: l10n.menuBarCopy,
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyC,
                    meta: true,
                  ),
                  intent: CopySelectionTextIntent.copy,
                ),
                _intentItem(
                  label: l10n.menuBarPaste,
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyV,
                    meta: true,
                  ),
                  intent: const PasteTextIntent(SelectionChangedCause.keyboard),
                ),
                _intentItem(
                  label: l10n.menuBarSelectAll,
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyA,
                    meta: true,
                  ),
                  intent: const SelectAllTextIntent(
                    SelectionChangedCause.keyboard,
                  ),
                ),
              ],
            ),
          ],
        ),
        PlatformMenu(
          label: l10n.menuBarView,
          menus: const [
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.toggleFullScreen,
            ),
          ],
        ),
        PlatformMenu(
          label: l10n.menuBarVideo,
          menus: [
            PlatformMenuItemGroup(
              members: [
                _intentItem(
                  label: l10n.menuBarPreviousVideo,
                  shortcut: FeedShortcutKeys.previousVideo,
                  intent: const PreviousVideoIntent(),
                ),
                _intentItem(
                  label: l10n.menuBarNextVideo,
                  shortcut: FeedShortcutKeys.nextVideo,
                  intent: const NextVideoIntent(),
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                _intentItem(
                  label: l10n.menuBarPlayPause,
                  shortcut: FeedShortcutKeys.togglePlayback,
                  intent: const TogglePlaybackIntent(),
                ),
                _intentItem(
                  label: isMuted ? l10n.menuBarUnmute : l10n.menuBarMute,
                  shortcut: FeedShortcutKeys.toggleMute,
                  intent: const ToggleMuteIntent(),
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                _intentItem(
                  label: l10n.commonBack,
                  shortcut: const SingleActivator(LogicalKeyboardKey.escape),
                  intent: const GoBackIntent(),
                ),
              ],
            ),
          ],
        ),
        PlatformMenu(
          label: l10n.menuBarWindow,
          menus: const [
            PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.minimizeWindow,
                ),
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.zoomWindow,
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.arrangeWindowsInFront,
                ),
              ],
            ),
          ],
        ),
        PlatformMenu(
          label: l10n.menuBarHelp,
          menus: [
            PlatformMenuItem(
              label: l10n.supportTitle,
              onSelected: onOpenSupportCenter,
            ),
          ],
        ),
      ],
      child: child,
    );
  }
}

/// A menu item that runs [intent] where the keyboard focus is, as pressing
/// [shortcut] would.
///
/// [PlatformMenuItem.onSelectedIntent] does the same but fails when nothing
/// has focus.
PlatformMenuItem _intentItem({
  required String label,
  required MenuSerializableShortcut shortcut,
  required Intent intent,
}) => PlatformMenuItem(
  label: label,
  shortcut: shortcut,
  onSelected: () {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext != null) Actions.maybeInvoke(focusContext, intent);
  },
);
