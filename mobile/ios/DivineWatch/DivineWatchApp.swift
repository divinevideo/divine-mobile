// ABOUTME: Entry point of the Divine Apple Watch app.
// ABOUTME: Shows the remote shutter for the recorder.

import SwiftUI
import WatchKit

@main
struct DivineWatchApp: App {
  @StateObject private var phone = PhoneRecorderLink()

  var body: some Scene {
    WindowGroup {
      RemoteShutterView(
        recorder: phone.recorder,
        isPhoneReachable: phone.isPhoneReachable && !phone.isShutterPending,
        onToggleRecording: { phone.toggleRecording() }
      )
      .onReceive(phone.deliveryFailures) {
        WKInterfaceDevice.current().play(.failure)
      }
      .onAppear { phone.activate() }
    }
  }
}
