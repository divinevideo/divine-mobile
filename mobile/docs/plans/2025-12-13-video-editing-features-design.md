# Video Editing Features Design

## Overview

This document describes the design for three video editing features in diVine:

1. **Clip Manager** - Review, delete, and reorder recorded segments before posting
2. **Text Overlay** - Add text/captions to videos
3. **Sound Picker** - Add classic Vine audio tracks to videos

## User Flow

```
Recording → Clip Manager → Editor → Metadata → Upload → Publish
              Screen 1     Screen 2
```

### Screen 1: Clip Manager
User reviews and arranges recorded segments.

### Screen 2: Editor
User adds text overlay and selects sound.

### Existing Screens
Metadata entry, upload, and publish flows remain unchanged.

---

## Feature 1: Clip Manager

### Purpose
Allow users to review recorded segments, delete unwanted takes, and reorder clips before editing.

### UI Design

**Layout: Thumbnail Grid**
- 2-column grid of segment thumbnails
- Each thumbnail shows:
  - First frame of segment
  - Duration badge (e.g., "1.2s")
  - Segment number indicator
  - Delete button (X icon, top-right corner)

**Interactions**
- **Tap thumbnail**: Opens modal with looping video preview of that segment
- **Long-press + drag**: Reorder segments (drag-and-drop)
- **Tap delete (X)**: Removes segment with confirmation
- **Preview all button**: Plays concatenated preview of all segments in order

**Header**
- Back button (discard and return to camera)
- Total duration display (e.g., "4.2s / 6.3s")
- "Next" button (proceed to Editor screen)

**Record More Button**
- Shown when total duration < 6.3 seconds
- Displays remaining time (e.g., "+ Record (2.1s left)")
- Tap returns to camera screen with existing segments preserved
- New recordings append to segment list
- Button hidden when at max duration

**Empty State**
- If all segments deleted, show "No clips" message
- "Record" button returns to camera (same as Record More)

### Data Model

```dart
class RecordingSegment {
  final String id;
  final String filePath;
  final Duration duration;
  final DateTime recordedAt;
  final Uint8List? thumbnailBytes;
  int orderIndex;
}

class ClipManagerState {
  final List<RecordingSegment> segments;
  final String? previewingSegmentId;
  final bool isReordering;
  final Duration totalDuration;
}
```

### Technical Implementation

**Thumbnail Generation**
- Use existing `VideoThumbnailService` (FFmpeg-based)
- Generate on recording stop, cache in memory
- Fallback: first frame via `video_player`

**Preview Playback**
- Use existing `video_player` package
- Modal overlay with looping playback
- Tap outside or X to dismiss

**Reordering**
- Flutter `ReorderableGridView` or custom drag-drop
- Update `orderIndex` on segments
- Persist order to draft storage

**Segment Deletion**
- Remove from list, delete temp file
- Update total duration
- Cannot undo (confirm dialog)

---

## Feature 2: Text Overlay

### Purpose
Add text captions that appear for the full duration of the video.

### UI Design (Editor Screen)

**Text Entry**
- "Add Text" button opens text editor modal
- Text input field with character limit (100 chars)
- Font style selector (3-4 preset styles)
- Color picker (preset palette: white, black, yellow, red, blue)
- Size slider (small, medium, large)

**Text Positioning**
- Drag text on video preview to position
- Default position: center-bottom (caption style)
- Snap guides for center alignment

**Text Preview**
- Real-time preview on video
- Text rendered as Flutter widget over video player
- Final position stored as normalized coordinates (0.0-1.0)

**Multiple Text Blocks**
- Support up to 3 text overlays
- Each can be independently positioned and styled
- Tap to select, tap again to edit

### Data Model

```dart
class TextOverlay {
  final String id;
  final String text;
  final TextStyle style; // font, size, color
  final Offset normalizedPosition; // 0.0-1.0 for x and y
  final TextAlignment alignment;
}

class EditorState {
  final List<TextOverlay> textOverlays;
  final String? selectedTextId;
  final String? selectedSoundId;
}
```

### Technical Implementation

**Preview Rendering**
- Stack widget: video_player + positioned text widgets
- Text widgets use same styling as final render

**Export Rendering**
- Render each TextOverlay to image using Flutter Canvas
- Composite all text into single PNG with transparency
- Pass to `pro_video_editor` as `imageBytes` layer

```dart
// Render text overlays to image
Future<Uint8List> renderTextOverlayImage(
  List<TextOverlay> overlays,
  Size videoSize,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  for (final overlay in overlays) {
    final textPainter = TextPainter(
      text: TextSpan(text: overlay.text, style: overlay.style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final position = Offset(
      overlay.normalizedPosition.dx * videoSize.width,
      overlay.normalizedPosition.dy * videoSize.height,
    );
    textPainter.paint(canvas, position);
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    videoSize.width.toInt(),
    videoSize.height.toInt(),
  );
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}
```

**Apply to Video**
- Use `pro_video_editor` RenderVideoModel with imageBytes

```dart
final task = RenderVideoModel(
  id: 'text-overlay-task',
  video: EditorVideo.file(videoPath),
  imageBytes: textOverlayImage,
);
final result = await ProVideoEditor.instance.render(task);
```

---

## Feature 3: Sound Picker

### Purpose
Select classic Vine audio tracks to add as background music.

### Sound Library

**Content**
- ~200 classic Vine audio tracks
- Bundled in app assets
- Format: AAC or MP3, 128kbps

**Metadata**
```dart
class VineSound {
  final String id;
  final String title;
  final String? artist;
  final Duration duration;
  final String assetPath;
  final List<String> tags; // for search/filter
}
```

**Asset Structure**
```
assets/
  sounds/
    sounds_manifest.json    // metadata for all sounds
    classic_vine_001.mp3
    classic_vine_002.mp3
    ...
```

### UI Design (Editor Screen)

**Sound Picker Button**
- "Add Sound" button on Editor screen
- Shows currently selected sound name, or "No sound"

**Sound Browser Modal**
- Full-screen modal overlay
- Search bar at top (filters by title, artist, tags)
- Scrollable list of sounds
- Each row shows:
  - Title and artist
  - Duration
  - Play/pause button for preview
- Tap row to select sound
- "None" option to remove sound

**Sound Preview**
- Tap play button to preview sound
- Only one sound plays at a time
- Sound plays through speaker
- Preview stops when modal closes or different sound selected

**Selected Sound Display**
- After selection, Editor screen shows sound name
- Small speaker icon with sound title
- Tap to change/remove

### Technical Implementation

**Sound Playback During Recording**
- When user starts recording with sound selected:
  - Play sound through speaker via `audioplayers` or `just_audio`
  - User performs to the sound
  - Video records without the sound (mic captures ambient only)

**Audio Mixing at Export**
- After text overlay applied, mix audio using FFmpeg

```dart
Future<String> mixAudioIntoVideo(
  String videoPath,
  String audioPath,
  String outputPath,
) async {
  // Mix audio, trim to video length, replace any existing audio
  final command = '-i $videoPath -i $audioPath '
      '-c:v copy -c:a aac -map 0:v:0 -map 1:a:0 '
      '-shortest $outputPath';

  await FFmpegKit.execute(command);
  return outputPath;
}
```

**Audio Playback Package**
- Use `just_audio` for sound preview (already handles asset playback well)
- Or `audioplayers` if simpler integration needed

---

## Processing Pipeline

### Export Flow

```
User taps "Done" on Editor screen
           ↓
    [Show progress indicator]
           ↓
1. Concatenate segments (if multiple)
   - FFmpeg: concat demuxer
   - Input: ordered segment files
   - Output: single video file
           ↓
2. Apply text overlay (if any)
   - Render text to PNG image
   - pro_video_editor: overlay image on video
   - Output: video with text baked in
           ↓
3. Mix audio (if sound selected)
   - FFmpeg: audio mixing
   - Input: video + sound asset
   - Output: final video with audio
           ↓
4. Generate thumbnail
   - Existing VideoThumbnailService
           ↓
5. Create VineDraft
   - Store final video path
   - Navigate to Metadata screen
```

### FFmpeg Commands

**Concatenate Segments**
```bash
# Create file list
echo "file 'segment_001.mp4'" > list.txt
echo "file 'segment_002.mp4'" >> list.txt

# Concatenate
ffmpeg -f concat -safe 0 -i list.txt -c copy output.mp4
```

**Mix Audio**
```bash
ffmpeg -i video.mp4 -i sound.mp3 \
  -c:v copy -c:a aac \
  -map 0:v:0 -map 1:a:0 \
  -shortest \
  output.mp4
```

### Progress Tracking

```dart
class ExportProgress {
  final ExportStage stage;
  final double progress; // 0.0 - 1.0
  final String? message;
}

enum ExportStage {
  concatenating,
  applyingTextOverlay,
  mixingAudio,
  generatingThumbnail,
  complete,
  error,
}
```

---

## Dependencies

### New Packages

| Package | Purpose | Version |
|---------|---------|---------|
| `pro_video_editor` | Text overlay, transforms | ^0.4.0 |
| `just_audio` | Sound preview playback | ^0.9.x |

### Existing Packages (Already in Project)

| Package | Purpose |
|---------|---------|
| `ffmpeg_kit_flutter_new` | Concat, audio mixing |
| `video_player` | Preview playback |
| `video_thumbnail` | Thumbnail generation |

---

## File Structure

```
lib/
  screens/
    clip_manager_screen.dart        # Screen 1: segment management
    video_editor_screen.dart        # Screen 2: text + sound (replace placeholder)

  widgets/
    clip_manager/
      segment_thumbnail.dart        # Grid item widget
      segment_preview_modal.dart    # Playback modal
      reorderable_segment_grid.dart # Drag-drop grid

    video_editor/
      text_overlay_editor.dart      # Text entry modal
      text_overlay_preview.dart     # Draggable text on video
      sound_picker_modal.dart       # Sound browser
      sound_preview_player.dart     # Audio playback for preview

  services/
    segment_manager_service.dart    # Segment CRUD, reordering
    text_overlay_renderer.dart      # Flutter canvas → PNG
    sound_library_service.dart      # Load/search sounds from assets
    video_export_service.dart       # Orchestrate export pipeline

  models/
    recording_segment.dart          # Segment data model
    text_overlay.dart               # Text overlay data model
    vine_sound.dart                 # Sound metadata model
    export_progress.dart            # Export state tracking

assets/
  sounds/
    sounds_manifest.json
    *.mp3
```

---

## Platform Support

| Feature | iOS | Android | macOS | Windows |
|---------|-----|---------|-------|---------|
| Clip Manager | ✅ | ✅ | ✅ | ✅ |
| Text Overlay | ✅ | ✅ | ✅ | ❌* |
| Sound Picker | ✅ | ✅ | ✅ | ✅ |
| Audio Mixing | ✅ | ✅ | ✅ | ✅ |

*`pro_video_editor` has limited Windows support for transforms

---

## V1 Scope

### Included
- Clip Manager with thumbnail grid, delete, reorder
- Text overlay with 3-4 font presets, color picker, drag positioning
- Sound picker with scrollable list, search, preview
- Sound playback during recording (guide track)
- Audio mixing at export via FFmpeg
- Full export pipeline

### Deferred to V2
- Timed text (appear/disappear at specific times)
- Text animations (fade in, etc.)
- Sound categories/tabs
- Trending sounds / social discovery
- User sound uploads
- Sound trimming (use full track only for v1)
- Video speed adjustment
- Filters/color grading

---

## Decisions

1. **Sound licensing**: No attribution needed for classic Vine sounds (for now)

2. **App size**: ~200 sounds at 128kbps ≈ 30-50MB. Approved.

3. **Export time**: Show progress indicator, or background process with callback when complete. Both acceptable.

4. **Sound during recording**: If user records without sound selected first, can they add sound later? Yes, at Editor screen.

5. **Segment limit**: Max number of segments to allow? Unlimited segments within 6-second total duration.

---

## Success Criteria

1. User can delete unwanted recording segments before posting
2. User can reorder segments via drag-and-drop
3. User can add text that appears on final video
4. User can browse and preview ~200 bundled sounds
5. User can select a sound that plays during recording
6. Final exported video includes selected sound as audio track
7. Export completes in under 15 seconds on mid-range devices
8. All features work on iOS and Android (primary targets)
