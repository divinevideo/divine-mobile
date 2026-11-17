// ABOUTME: Connects the recorder to the Apple Watch remote over WatchConnectivity
// ABOUTME: Sends the recorder's state to the Watch and receives its shutter taps

#if os(iOS)
import Foundation
import WatchConnectivity

/// Keeps the Apple Watch remote in step with the recorder.
///
/// The latest state goes out twice: as the session's application context,
/// which the Watch reads whenever it next opens, and as a message when the
/// Watch app is on screen, which arrives at once.
final class WatchRemoteLink: NSObject, WCSessionDelegate {
    /// Keys and values shared with the Watch app's `PhoneRecorderLink`.
    enum Wire {
        static let available = "available"
        static let command = "command"
        static let toggleRecording = "toggleRecording"
    }

    private let session: WCSession?
    private let onToggleRecording: () -> Void
    private let onWatchRemoteChanged: ([String: Any]?) -> Void

    /// What the Watch should show. Only touched on the main queue.
    private var payload: [String: Any] = [Wire.available: false]

    /// - Parameters:
    ///   - onToggleRecording: Called on the main queue when the Watch's
    ///     shutter is tapped.
    ///   - onWatchRemoteChanged: Called on the main queue with the recorder
    ///     state a Watch remote can show, or `nil` when the recorder is closed
    ///     or no paired Watch has the app.
    init(
        onToggleRecording: @escaping () -> Void,
        onWatchRemoteChanged: @escaping ([String: Any]?) -> Void
    ) {
        self.session = WCSession.isSupported() ? WCSession.default : nil
        self.onToggleRecording = onToggleRecording
        self.onWatchRemoteChanged = onWatchRemoteChanged
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
        send()
    }

    private func send() {
        guard let session, session.activationState == .activated else { return }
        let isRecorderOpen = payload[Wire.available] as? Bool == true
        let hasWatchApp = session.isPaired && session.isWatchAppInstalled
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
        guard message[Wire.command] as? String == Wire.toggleRecording else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onToggleRecording()
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
