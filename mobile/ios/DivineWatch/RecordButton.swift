// ABOUTME: The shutter button of the Watch remote.
// ABOUTME: Keeps the proportions of the iPhone recorder's record button.

import SwiftUI

/// The shutter: a ring whose inner shape morphs between the idle dot and the
/// recording square.
///
/// Every measure is the iPhone record button's, scaled from its 96 pt ring.
struct RecordButton: View {
  let isRecording: Bool
  let isEnabled: Bool
  let diameter: CGFloat
  let action: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var scale: CGFloat { diameter / 96 }

  private var label: LocalizedStringKey {
    isRecording ? "divine_watch_stop_recording" : "divine_watch_start_recording"
  }

  var body: some View {
    Button(action: action) {
      ZStack {
        RoundedRectangle(cornerRadius: 36 * scale)
          .strokeBorder(isRecording ? DivinePalette.error : Color.white, lineWidth: 4 * scale)
        RoundedRectangle(cornerRadius: (isRecording ? 6 : 20) * scale)
          .fill(DivinePalette.error)
          .frame(width: (isRecording ? 32 : 64) * scale, height: (isRecording ? 32 : 64) * scale)
      }
      .frame(width: diameter, height: diameter)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
    .opacity(isEnabled ? 1 : 0.5)
    .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: isRecording)
    .accessibilityLabel(Text(label))
  }
}
