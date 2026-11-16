// ABOUTME: Entry point of the Divine Apple Watch app.
// ABOUTME: Shows the remote shutter for the recorder.

import SwiftUI

@main
struct DivineWatchApp: App {
  @StateObject private var phone = PhoneRecorderLink()

  var body: some Scene {
    WindowGroup {
      RemoteShutterView(
        recorder: phone.recorder,
        onToggleRecording: { phone.toggleRecording() }
      )
      .onAppear { phone.activate() }
    }
  }
}
