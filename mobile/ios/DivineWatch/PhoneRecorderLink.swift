// ABOUTME: The Watch's connection to the recorder on the iPhone.
// ABOUTME: Receives the recorder's state and sends shutter taps back.

import Combine
import Foundation
import WatchConnectivity

/// The recorder on the paired iPhone, as the Watch sees it.
///
/// `recorder` is `nil` while the iPhone has no recorder on screen. Keys match
/// `WatchRemoteLink` in the iPhone app's camera plugin.
final class PhoneRecorderLink: NSObject, ObservableObject, WCSessionDelegate {
  private enum Wire {
    static let available = "available"
    static let recordedMs = "recordedMs"
    static let activeTakeStartedAtMs = "activeTakeStartedAtMs"
    static let budgetMs = "budgetMs"
    static let modeName = "modeName"
    static let shutterActive = "shutterActive"
    static let command = "command"
    static let toggleRecording = "toggleRecording"
  }

  @Published private(set) var recorder: RecorderSnapshot?

  /// Whether a tap can reach the iPhone now. While it cannot, `recorder` is
  /// the last state received and may be out of date.
  @Published private(set) var isPhoneReachable = false

  /// Sends a value each time a tap could not be delivered.
  let deliveryFailures = PassthroughSubject<Void, Never>()

  private let session = WCSession.default

  func activate() {
    session.delegate = self
    session.activate()
  }

  /// Asks the iPhone to start or stop a take. What the recorder then does
  /// comes back as a new `recorder`.
  func toggleRecording() {
    guard session.isReachable else {
      updateReachability()
      deliveryFailures.send()
      return
    }
    session.sendMessage(
      [Wire.command: Wire.toggleRecording],
      replyHandler: nil,
      errorHandler: { [weak self] _ in
        DispatchQueue.main.async {
          self?.updateReachability()
          self?.deliveryFailures.send()
        }
      }
    )
  }

  /// Reads what the iPhone sent; `nil` for a closed recorder.
  static func snapshot(from payload: [String: Any]) -> RecorderSnapshot? {
    guard payload[Wire.available] as? Bool == true else { return nil }
    var snapshot = RecorderSnapshot()
    if let recordedMs = payload[Wire.recordedMs] as? Double {
      snapshot.recordedDuration = recordedMs / 1000
    }
    if let startedAtMs = payload[Wire.activeTakeStartedAtMs] as? Double {
      snapshot.activeTakeStartedAt = Date(timeIntervalSince1970: startedAtMs / 1000)
    }
    if let budgetMs = payload[Wire.budgetMs] as? Double, budgetMs > 0 {
      snapshot.budget = budgetMs / 1000
    }
    if let modeName = payload[Wire.modeName] as? String {
      snapshot.modeName = modeName
    }
    snapshot.isShutterActive = payload[Wire.shutterActive] as? Bool ?? snapshot.isRecording
    return snapshot
  }

  private func receive(_ payload: [String: Any]) {
    let snapshot = Self.snapshot(from: payload)
    DispatchQueue.main.async { [weak self] in
      self?.recorder = snapshot
    }
  }

  private func updateReachability() {
    let isReachable = session.isReachable
    DispatchQueue.main.async { [weak self] in
      self?.isPhoneReachable = isReachable
    }
  }

  // MARK: WCSessionDelegate

  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    receive(session.receivedApplicationContext)
    updateReachability()
  }

  func sessionReachabilityDidChange(_ session: WCSession) {
    updateReachability()
  }

  func session(
    _ session: WCSession,
    didReceiveApplicationContext applicationContext: [String: Any]
  ) {
    receive(applicationContext)
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    receive(message)
  }
}
