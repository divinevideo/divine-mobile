#!/usr/bin/env bash
# ABOUTME: Executes Apple diagnostic lifetime tests and typechecks plugin wiring.
# ABOUTME: Requires Xcode and a Flutter SDK precached for iOS and macOS.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCES="$SCRIPT_DIR/divine_video_player/Sources/divine_video_player"
DIAGNOSTICS_DIR="$(mktemp -d)"
trap 'rm -f "$DIAGNOSTICS_DIR/playback_network_tests" "$DIAGNOSTICS_DIR/http_playback_error_tests" "$DIAGNOSTICS_DIR/tests" "$DIAGNOSTICS_DIR/loop_pcm_tests" "$DIAGNOSTICS_DIR/audio_overlay_fade_tests" "$DIAGNOSTICS_DIR/audio_overlay_entry_tests" "$DIAGNOSTICS_DIR/audio_overlay_seek_lead_tests" "$DIAGNOSTICS_DIR/audio_equalizer_tests" "$DIAGNOSTICS_DIR/equalized_audio_file_tests" "$DIAGNOSTICS_DIR/video_frame_effects_tests" "$DIAGNOSTICS_DIR/clip_audio_loop_tests" "$DIAGNOSTICS_DIR/shown_frame_tests" "$DIAGNOSTICS_DIR/reported_playback_status_tests" "$DIAGNOSTICS_DIR/frozen_picture_tests" "$DIAGNOSTICS_DIR/data_wait_tests" "$DIAGNOSTICS_DIR/paused_frame_pull_tests" "$DIAGNOSTICS_DIR/paused_frame_redelivery_tests"; rmdir "$DIAGNOSTICS_DIR"' EXIT

xcrun swiftc -parse-as-library "$SOURCES/ShownFrame.swift" \
  "$SCRIPT_DIR/Tests/ShownFrameTests.swift" \
  -o "$DIAGNOSTICS_DIR/shown_frame_tests"
"$DIAGNOSTICS_DIR/shown_frame_tests"

xcrun swiftc -parse-as-library "$SOURCES/ReportedPlaybackStatus.swift" \
  "$SCRIPT_DIR/Tests/ReportedPlaybackStatusTests.swift" \
  -o "$DIAGNOSTICS_DIR/reported_playback_status_tests"
"$DIAGNOSTICS_DIR/reported_playback_status_tests"

xcrun swiftc -parse-as-library "$SOURCES/DataWait.swift" \
  "$SCRIPT_DIR/Tests/DataWaitTests.swift" \
  -o "$DIAGNOSTICS_DIR/data_wait_tests"
"$DIAGNOSTICS_DIR/data_wait_tests"

xcrun swiftc -parse-as-library "$SOURCES/FrozenPicture.swift" \
  "$SCRIPT_DIR/Tests/FrozenPictureTests.swift" \
  -o "$DIAGNOSTICS_DIR/frozen_picture_tests"
"$DIAGNOSTICS_DIR/frozen_picture_tests"

xcrun swiftc -parse-as-library "$SOURCES/PausedFramePull.swift" \
  "$SCRIPT_DIR/Tests/PausedFramePullTests.swift" \
  -o "$DIAGNOSTICS_DIR/paused_frame_pull_tests"
"$DIAGNOSTICS_DIR/paused_frame_pull_tests"

xcrun swiftc -parse-as-library "$SOURCES/PausedFrameRedelivery.swift" \
  "$SCRIPT_DIR/Tests/PausedFrameRedeliveryTests.swift" \
  -o "$DIAGNOSTICS_DIR/paused_frame_redelivery_tests"
"$DIAGNOSTICS_DIR/paused_frame_redelivery_tests"

xcrun swiftc "$SOURCES/HTTPPlaybackError.swift" \
  "$SOURCES/CachingAssetLoader.swift" "$SOURCES/PlaybackNetworkObservation.swift" \
  "$SCRIPT_DIR/Tests/HTTPPlaybackErrorTests.swift" \
  -o "$DIAGNOSTICS_DIR/http_playback_error_tests"
"$DIAGNOSTICS_DIR/http_playback_error_tests"

xcrun swiftc "$SOURCES/PlaybackNetworkObservation.swift" \
  "$SCRIPT_DIR/Tests/PlaybackNetworkObservationTests.swift" \
  -o "$DIAGNOSTICS_DIR/playback_network_tests"
"$DIAGNOSTICS_DIR/playback_network_tests"

xcrun swiftc "$SOURCES/PlaybackDiagnostics.swift" \
  "$SCRIPT_DIR/Tests/PlaybackDiagnosticsTests.swift" \
  -o "$DIAGNOSTICS_DIR/tests"
"$DIAGNOSTICS_DIR/tests"

xcrun swiftc "$SOURCES/LoopPcm.swift" \
  "$SCRIPT_DIR/Tests/LoopPcmTests.swift" \
  -o "$DIAGNOSTICS_DIR/loop_pcm_tests"
"$DIAGNOSTICS_DIR/loop_pcm_tests"

xcrun swiftc "$SOURCES/AudioEqualizer.swift" \
  "$SCRIPT_DIR/Tests/AudioEqualizerTests.swift" \
  -o "$DIAGNOSTICS_DIR/audio_equalizer_tests"
"$DIAGNOSTICS_DIR/audio_equalizer_tests"

xcrun swiftc -parse-as-library "$SOURCES/AudioEqualizer.swift" \
  "$SOURCES/EqualizedAudioFile.swift" \
  "$SCRIPT_DIR/Tests/EqualizedAudioFileTests.swift" \
  -o "$DIAGNOSTICS_DIR/equalized_audio_file_tests"
"$DIAGNOSTICS_DIR/equalized_audio_file_tests"

xcrun swiftc "$SOURCES/AudioOverlayFade.swift" \
  "$SCRIPT_DIR/Tests/AudioOverlayFadeTests.swift" \
  -o "$DIAGNOSTICS_DIR/audio_overlay_fade_tests"
"$DIAGNOSTICS_DIR/audio_overlay_fade_tests"

xcrun swiftc -parse-as-library "$SOURCES/AudioOverlayManager.swift" \
  "$SOURCES/AudioOverlaySeekLead.swift" \
  "$SOURCES/AudioOverlayFade.swift" \
  "$SOURCES/AudioEqualizer.swift" \
  "$SOURCES/EqualizedAudioFile.swift" \
  "$SOURCES/DivineVideoPlayerLog.swift" \
  "$SCRIPT_DIR/Tests/AudioOverlayEntryTests.swift" \
  -o "$DIAGNOSTICS_DIR/audio_overlay_entry_tests"
"$DIAGNOSTICS_DIR/audio_overlay_entry_tests"

xcrun swiftc -parse-as-library "$SOURCES/AudioOverlaySeekLead.swift" \
  "$SCRIPT_DIR/Tests/AudioOverlaySeekLeadTests.swift" \
  -o "$DIAGNOSTICS_DIR/audio_overlay_seek_lead_tests"
"$DIAGNOSTICS_DIR/audio_overlay_seek_lead_tests"

xcrun swiftc "$SOURCES/VideoFrameEffects.swift" \
  "$SOURCES/DivineVideoPlayerLog.swift" \
  "$SCRIPT_DIR/Tests/VideoFrameEffectsTests.swift" \
  -o "$DIAGNOSTICS_DIR/video_frame_effects_tests"
"$DIAGNOSTICS_DIR/video_frame_effects_tests"

xcrun swiftc -parse-as-library "$SOURCES/ClipAudioLoop.swift" \
  "$SOURCES/LoopPcm.swift" \
  "$SOURCES/AudioEqualizer.swift" \
  "$SCRIPT_DIR/Tests/ClipAudioLoopTests.swift" \
  -o "$DIAGNOSTICS_DIR/clip_audio_loop_tests"
"$DIAGNOSTICS_DIR/clip_audio_loop_tests"

ENGINE="${FLUTTER_ROOT:?Set FLUTTER_ROOT to the precached Flutter SDK}/bin/cache/artifacts/engine"
xcrun swiftc -typecheck -target arm64-apple-macos13.0 \
  -F "$ENGINE/darwin-x64/FlutterMacOS.xcframework/macos-arm64_x86_64" \
  "$SOURCES"/*.swift
xcrun --sdk iphonesimulator swiftc -typecheck \
  -target arm64-apple-ios16.0-simulator \
  -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -F "$ENGINE/ios/Flutter.xcframework/ios-arm64_x86_64-simulator" \
  "$SOURCES"/*.swift
