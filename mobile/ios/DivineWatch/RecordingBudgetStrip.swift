// ABOUTME: The strip along the bottom of the Watch remote.
// ABOUTME: Fills with green from the left as the clip budget is recorded.

import SwiftUI

/// The clip budget, filling from the left as it is recorded.
///
/// Says nothing to VoiceOver: the shutter button carries the recorder's state.
struct RecordingBudgetStrip: View {
  let fill: RecordingBudgetFill

  var body: some View {
    GeometryReader { proxy in
      HStack(spacing: 0) {
        DivinePalette.primary
          .frame(width: proxy.size.width * fill.filled)
        Spacer(minLength: 0)
        DivinePalette.primaryContainer
          .frame(width: proxy.size.width * fill.overflow)
      }
    }
    .background(DivinePalette.onSurfaceDisabled)
    .accessibilityHidden(true)
  }
}
