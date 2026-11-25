// ABOUTME: Connects the recorder to the Apple Watch remote over WatchConnectivity
// ABOUTME: Sends the recorder's state to the Watch and receives its shutter taps

#if os(iOS)
import Foundation
import WatchConnectivity

/// Keeps the Apple Watch remote in step with the recorder.
///
/// The latest state goes out twice: as the session's application context,
/// which the Watch reads whenever it next opens, and as a message when the
/// Watch app is on screen, which arrives at once. Each state carries its
/// revision, and only a press made on the latest one reaches the recorder.
final class WatchRemoteLink: NSObject, WCSessionDelegate {
    /// Keys shared with the Watch app's `PhoneRecorderLink`.
    enum Wire {
        static let available = "available"
    }

    private let session: WCSession?
    private let onShutterAction: (WatchShutterGate.Action) -> Void
    private let onWatchRemoteChanged: ([String: Any]?) -> Void
    private let onWatchAppChanged: (Bool) -> Void

    /// Whether a paired Watch has the Watch app. Only touched on the main
    /// queue.
    private(set) var hasWatchApp = false

    /// Numbers the states in `payload`. Only touched on the main queue.
    private var gate: WatchShutterGate

    /// What the Watch should show. Only touched on the main queue.
    private var payload: [String: Any]

    /// - Parameters:
    ///   - onShutterAction: Called on the main queue when the Watch's
    ///     shutter is tapped on the state published last.
    ///   - onWatchRemoteChanged: Called on the main queue with the recorder
    ///     state a Watch remote can show, or `nil` when the recorder is closed
    ///     or no paired Watch has the app.
    ///   - onWatchAppChanged: Called on the main queue when a paired Watch
    ///     gains or loses the Watch app.
    init(
        onShutterAction: @escaping (WatchShutterGate.Action) -> Void,
        onWatchRemoteChanged: @escaping ([String: Any]?) -> Void,
        onWatchAppChanged: @escaping (Bool) -> Void
    ) {
        self.session = WCSession.isSupported() ? WCSession.default : nil
        self.onShutterAction = onShutterAction
        self.onWatchRemoteChanged = onWatchRemoteChanged
        self.onWatchAppChanged = onWatchAppChanged
        let gate = WatchShutterGate(nowMs: WatchRemoteLink.nowMs())
        self.gate = gate
        self.payload = [
            Wire.available: false,
            WatchShutterGate.Wire.revision: gate.revision,
        ]
        super.init()
    }

    func activate() {
        session?.delegate = self
        session?.activate()
    }

    /// Publishes the recorder's state, or that the recorder closed when
    /// `state` is `nil`. Call on the main queue.
    func update(state: [String: Any]?) {
        if let state {
            // A take that is not running arrives as NSNull, which a
            // WatchConnectivity payload cannot carry.
            payload = state.filter { !($0.value is NSNull) }
            payload[Wire.available] = true
        } else {
            payload = [Wire.available: false]
        }
        payload[WatchShutterGate.Wire.revision] = gate.advance(nowMs: Self.nowMs())
        send()
    }

    private static func nowMs() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    private func send() {
        guard let session, session.activationState == .activated else { return }
        let isRecorderOpen = payload[Wire.available] as? Bool == true
        let hadWatchApp = hasWatchApp
        hasWatchApp = session.isPaired && session.isWatchAppInstalled
        if hasWatchApp != hadWatchApp {
            onWatchAppChanged(hasWatchApp)
        }
        onWatchRemoteChanged(isRecorderOpen && hasWatchApp ? payload : nil)
        do {
            try session.updateApplicationContext(payload)
        } catch {
            // No paired Watch, or the Watch app is not installed: there is
            // nobody to tell.
        }
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
    }

    private func handle(message: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let action = self.gate.action(for: message) else {
                DivineCameraLog.shared.debug(
                    "Watch press ignored: "
                        + "\(message[WatchShutterGate.Wire.command] ?? "no action") on revision "
                        + "\(message[WatchShutterGate.Wire.revision] ?? "none"), "
                        + "the recorder is at \(self.gate.revision)",
                    name: "DivineCamera.WatchRemote"
                )
                return
            }
            self.onShutterAction(action)
        }
    }

    // MARK: WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async { [weak self] in self?.send() }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in self?.send() }
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        // The Watch app was installed or removed, or a Watch was paired.
        DispatchQueue.main.async { [weak self] in self?.send() }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        // Nothing to hold back: the next activation sends the latest state.
    }

    func sessionDidDeactivate(_ session: WCSession) {
        // The user switched to another Watch; connect to that one.
        session.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message: message)
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        handle(message: message)
        replyHandler([:])
    }
}
#endif
