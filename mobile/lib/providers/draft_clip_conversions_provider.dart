// ABOUTME: Shares the draft conversion in flight between library screens,
// ABOUTME: so a library reopened mid-render follows it instead of a new one.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/drafts_library/draft_clip_conversion_cubit.dart';

/// The app's single [DraftClipConversions].
///
/// App-scoped because the render outlives the library screen that started
/// it.
final draftClipConversionsProvider = Provider<DraftClipConversions>(
  (ref) => DraftClipConversions(),
);
