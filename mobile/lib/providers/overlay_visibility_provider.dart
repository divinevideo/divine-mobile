// ABOUTME: Provider for tracking overlay visibility (settings, modals)
// ABOUTME: Videos should pause when overlays are visible

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';

part 'overlay_visibility_provider.g.dart';

/// State class to track which overlays are currently visible
class OverlayVisibilityState {
  const OverlayVisibilityState({
    this.isPageOpen = false,
    this.isBottomSheetOpen = false,
  });

  /// Full-screen page overlay (e.g., settings, profile).
  ///
  /// When open, the feed pauses and the neighbouring players and their disk
  /// prefetch are released; the current player is retained. Only a
  /// codec-heavy surface releases the current player, through
  /// `InfiniteVideoFeed.releaseCurrentWhenInactive`, which this state never
  /// drives.
  final bool isPageOpen;

  /// Bottom sheet overlay (e.g., comments, share).
  ///
  /// When open, the feed pauses but the neighbours stay warm for a fast
  /// resume — see [shouldRetainPlayer], which additionally requires that no
  /// page owner is held.
  final bool isBottomSheetOpen;

  /// Returns true if any overlay that should pause videos is visible
  bool get hasVisibleOverlay => isPageOpen || isBottomSheetOpen;

  /// Returns true if only lightweight overlays are open (bottom sheet).
  /// These overlays retain the current player for instant resume.
  /// Returns false if a full-screen page is open (requires full player release).
  bool get shouldRetainPlayer => isBottomSheetOpen && !isPageOpen;

  OverlayVisibilityState copyWith({bool? isPageOpen, bool? isBottomSheetOpen}) {
    return OverlayVisibilityState(
      isPageOpen: isPageOpen ?? this.isPageOpen,
      isBottomSheetOpen: isBottomSheetOpen ?? this.isBottomSheetOpen,
    );
  }

  @override
  String toString() =>
      'OverlayVisibilityState(page=$isPageOpen, '
      'bottomSheet=$isBottomSheetOpen)';
}

/// Notifier for managing overlay visibility state
@Riverpod(keepAlive: true)
class OverlayVisibility extends _$OverlayVisibility {
  final Set<Object> _pageOpenOwners = {};
  final Set<Object> _bottomSheetOwners = {};

  @override
  OverlayVisibilityState build() => OverlayVisibilityState(
    isPageOpen: _isPageOpen,
    isBottomSheetOpen: _isBottomSheetOpen,
  );

  /// Whether this notifier can still accept writes.
  bool get isMounted => ref.mounted;

  bool get _isPageOpen => _pageOpenOwners.isNotEmpty;
  bool get _isBottomSheetOpen => _bottomSheetOwners.isNotEmpty;

  /// Sets page visibility for one independently mounted owner.
  void setPageOpenForOwner(Object owner, {required bool isOpen}) {
    if (isOpen) {
      _pageOpenOwners.add(owner);
    } else {
      _pageOpenOwners.remove(owner);
    }
    _updatePageOpen();
  }

  /// Clears every page-open source after navigation proves none remain.
  void clearPageOpen() {
    _pageOpenOwners.clear();
    _updatePageOpen();
  }

  /// Clears every overlay-open source after navigation proves none remain.
  void clearOverlays() {
    _pageOpenOwners.clear();
    _bottomSheetOwners.clear();
    _updatePageOpen();
    _updateBottomSheetOpen();
  }

  void _updatePageOpen() {
    final isOpen = _isPageOpen;
    if (state.isPageOpen != isOpen) {
      Log.info(
        'Page ${isOpen ? 'opened' : 'closed'}',
        name: 'OverlayVisibility',
        category: LogCategory.ui,
      );
      state = state.copyWith(isPageOpen: isOpen);
    }
  }

  /// Sets bottom sheet visibility for one independently mounted owner.
  /// When a bottom sheet is open, only the current player is paused.
  void setBottomSheetOpenForOwner(Object owner, {required bool isOpen}) {
    if (isOpen) {
      _bottomSheetOwners.add(owner);
    } else {
      _bottomSheetOwners.remove(owner);
    }
    _updateBottomSheetOpen();
  }

  void _updateBottomSheetOpen() {
    final isOpen = _isBottomSheetOpen;
    if (state.isBottomSheetOpen != isOpen) {
      Log.info(
        'BottomSheet ${isOpen ? 'opened' : 'closed'}',
        name: 'OverlayVisibility',
        category: LogCategory.ui,
      );
      state = state.copyWith(isBottomSheetOpen: isOpen);
    }
  }
}

/// Convenience provider that returns true if any overlay is visible
final hasVisibleOverlayProvider = Provider<bool>((ref) {
  final state = ref.watch(overlayVisibilityProvider);
  return state.hasVisibleOverlay;
});
