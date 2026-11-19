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
    static let shutterEnabled = "shutterEnabled"
    static let stillShutterCount = "stillShutterCount"
    static let command = "command"
    static let startRecording = "watchStart"
    static let stopRecording = "watchStop"
  }

  @Published private(set) var recorder: RecorderSnapshot?

  /// Whether a tap can reach the iPhone now. While it cannot, `recorder` is
  /// the last state received and may be out of date.
  @Published private(set) var isPhoneReachable = false
  @Published private(set) var isShutterPending = false

  /// Sends a value each time a tap could not be delivered.
  let deliveryFailures = PassthroughSubject<Void, Never>()

  private let session = WCSession.default
  private var pendingID: UUID?
  private var pendingStop = false
  private var pendingStillShutterCount = 0

  func activate() {
    session.delegate = self
    session.activate()
  }

  /// Asks the iPhone to start or stop a take. What the recorder then does
  /// comes back as a new `recorder`.
  func toggleRecording() {
    guard let recorder, recorder.isShutterEnabled, !isShutterPending else { return }
    guard session.isReachable else {
      updateReachability()
      deliveryFailures.send()
      return
    }
    let id = UUID()
    pendingID = id
    pendingStop = recorder.isShutterActive
    pendingStillShutterCount = recorder.stillShutterCount
    isShutterPending = true
    let command = pendingStop ? Wire.stopRecording : Wire.startRecording
    session.sendMessage(
      [Wire.command: command],
      replyHandler: nil,
      errorHandler: { [weak self] _ in
        DispatchQueue.main.async {
          self?.updateReachability()
          self?.failPending(id)
        }
      }
    )
    // A tap the phone ignores changes nothing it publishes. A timeout
    // releases the button then.
    DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
      guard self?.pendingID == id else { return }
      self?.clearPending()
    }
  }

  private func clearPending() {
    pendingID = nil
    isShutterPending = false
  }

  private func failPending(_ id: UUID) {
    guard pendingID == id else { return }
    clearPending()
    deliveryFailures.send()
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
    snapshot.isShutterEnabled = payload[Wire.shutterEnabled] as? Bool ?? true
    if let stillShutterCount = payload[Wire.stillShutterCount] as? Int {
      snapshot.stillShutterCount = stillShutterCount
    }
    return snapshot
  }

  private func receive(_ payload: [String: Any]) {
    let snapshot = Self.snapshot(from: payload)
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.recorder = snapshot
      // A video tap flips the shutter. A still leaves it unchanged and
      // acknowledges completion through the capture count.
      if snapshot?.isShutterActive != self.pendingStop
        || snapshot?.stillShutterCount != self.pendingStillShutterCount {
        self.clearPending()
      }
    }
  }

  private func updateReachability() {
    let isReachable = session.isReachable
    DispatchQueue.main.async { [weak self] in
      self?.isPhoneReachable = isReachable
      if !isReachable { self?.clearPending() }
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
