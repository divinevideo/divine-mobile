// ABOUTME: Forwards curated native camera diagnostics to Dart's UnifiedLogger
// ABOUTME: so recording issues (e.g. missing audio) appear in user bug reports

import Foundation

/// Bridges relevant native diagnostics to the Dart side so they are captured
/// by the app's `UnifiedLogger` and included in bug-report log dumps.
///
/// Native recording code calls these methods (instead of bare `print`) for the
/// handful of events worth surfacing to support: audio-session configuration,
/// interruptions and recovery, recording start/stop, and asset-writer
/// failures. Per-frame / verbose logging must stay on `print` so it does not
/// flood the captured buffer.
///
/// `DivineCameraPlugin` installs `sink` at registration to forward each entry
/// over the method channel. Before that is wired (or in unit/host contexts)
/// entries fall back to the console only.
final class DivineCameraLog {
    static let shared = DivineCameraLog()

    private init() {}

    private let sinkLock = NSLock()
    private var _sink: ((String, String, String, Double) -> Void)?

    /// Forwards `(level, message, name, timestampMs)` to Dart. `level` is one
    /// of `debug`, `info`, `warning`, `error`; `timestampMs` is milliseconds
    /// since the epoch, stamped at the call site. Set by the plugin; `nil`
    /// until then.
    ///
    /// Lock-guarded: the UI engine reclaims ownership from non-main queues
    /// (e.g. `CameraController.captureOutput` on `videoOutputQueue`) while
    /// `handle`/`emit` touch it on other queues. The lock serializes the
    /// non-atomic closure store/load so a write is never torn against a read.
    /// See #5128.
    var sink: ((String, String, String, Double) -> Void)? {
        get {
            sinkLock.lock()
            defer { sinkLock.unlock() }
            return _sink
        }
        set {
            sinkLock.lock()
            defer { sinkLock.unlock() }
            _sink = newValue
        }
    }

    func debug(_ message: String, name: String = "DivineCamera") {
        emit("debug", message, name)
    }

    func info(_ message: String, name: String = "DivineCamera") {
        emit("info", message, name)
    }

    func warning(_ message: String, name: String = "DivineCamera") {
        emit("warning", message, name)
    }

    func error(_ message: String, name: String = "DivineCamera") {
        emit("error", message, name)
    }

    private func emit(_ level: String, _ message: String, _ name: String) {
        // Stamp here, on whichever queue raised the event. The sink hops to
        // main before it reaches Dart, and Dart stamps on arrival, so without
        // this a line held up by a busy or suspending main queue reads exactly
        // like native work that ran late. Milliseconds since the epoch; Dart
        // renders it beside its own UTC stamp. See #9291.
        let timestampMs = Date().timeIntervalSince1970 * 1000
        // Keep the console fallback so on-device debugging is unchanged.
        print("[\(name)] \(message)")
        // Snapshot under the lock, then invoke outside it so the forwarding
        // closure can log without re-entering the lock.
        let sink = self.sink
        sink?(level, message, name, timestampMs)
    }
}
