// ABOUTME: Ties an Apple Watch shutter press to the recorder state it was made on
// ABOUTME: Pure logic, apart from WatchConnectivity, so RunnerTests can check it

import Foundation

/// Numbers the recorder states sent to the Apple Watch and decides which
/// presses still apply.
///
/// Each state carries a revision, and a press names the revision of the state
/// the Watch showed. A press made on any other state is dropped: a Stop shown
/// for one take must not stop the next, and a Start made before the recorder
/// closed or changed modes does nothing. The Wear OS remote numbers its states
/// the same way.
public struct WatchShutterGate {
    /// Keys shared with the Watch app's `PhoneRecorderLink`.
    public enum Wire {
        public static let command = "command"
        public static let revision = "revision"
    }

    /// The shutter actions a Watch press can ask for.
    public enum Action: String {
        case start = "watchStart"
        case stop = "watchStop"
    }

    /// The revision of the state published last.
    public private(set) var revision: Int64

    /// Starts from the clock, so a restarted app numbers its states above
    /// what a Watch may still show from the run before.
    public init(nowMs: Int64) {
        revision = max(1, nowMs)
    }

    /// Numbers the next state and returns its revision.
    public mutating func advance(nowMs: Int64) -> Int64 {
        revision = max(revision + 1, nowMs)
        return revision
    }

    /// The action `message` asks for, or `nil` unless it is a press on the
    /// state published last. A press without a revision does not say which
    /// state it was made on, so it is dropped too.
    public func action(for message: [String: Any]) -> Action? {
        guard let command = message[Wire.command] as? String,
              let action = Action(rawValue: command),
              let pressedOn = (message[Wire.revision] as? NSNumber)?.int64Value,
              pressedOn == revision else { return nil }
        return action
    }
}
