// ABOUTME: Ties an Apple Watch shutter press to the recorder state it was made on
// ABOUTME: Pure logic, apart from WatchConnectivity, so RunnerTests can check it

import Foundation

/// Numbers the recorder states sent to the Apple Watch and decides which
/// presses still apply.
///
/// Each state carries a revision, and a press names the revision of the state
/// the Watch showed. A press made on any other state is dropped: a Stop shown
/// for one take must not stop the next, and a Start made before the recorder
/// closed or changed modes does nothing.
///
/// Dart can move the recorder on before this side hears of it, so a press
/// that passes goes on to Dart with Dart's own number for the state it was
/// made on (`stateId`), and Dart checks it again. The Wear OS remote works
/// the same way.
public struct WatchShutterGate {
    /// Keys shared with the Watch app's `PhoneRecorderLink`, and with Dart's
    /// `MethodChannelDivineCamera`.
    public enum Wire {
        public static let available = "available"
        public static let command = "command"
        public static let revision = "revision"
        /// Dart's number for a state it sent. It stays on the iPhone: the
        /// Watch names states by revision.
        public static let stateId = "stateId"
        public static let trigger = "trigger"
    }

    /// The shutter actions a Watch press can ask for.
    public enum Action: String {
        case start = "watchStart"
        case stop = "watchStop"
    }

    /// The revision of the state published last.
    public private(set) var revision: Int64

    /// Dart's number for the state published last, or `nil` while the
    /// recorder is closed.
    public private(set) var stateId: Int64?

    /// Starts from the clock, so a restarted app numbers its states above
    /// what a Watch may still show from the run before.
    public init(nowMs: Int64) {
        revision = max(1, nowMs)
    }

    /// What the Watch is told before Dart has published a state: the
    /// recorder is closed.
    public var closedPayload: [String: Any] {
        [Wire.available: false, Wire.revision: revision]
    }

    /// Numbers the next state, `state` as Dart sent it or `nil` for a closed
    /// recorder, and returns what the Watch should show.
    public mutating func publish(_ state: [String: Any]?, nowMs: Int64) -> [String: Any] {
        revision = max(revision + 1, nowMs)
        stateId = (state?[Wire.stateId] as? NSNumber)?.int64Value
        guard let state else { return closedPayload }
        // A take that is not running arrives as NSNull, which a
        // WatchConnectivity payload cannot carry.
        var payload = state.filter { !($0.value is NSNull) && $0.key != Wire.stateId }
        payload[Wire.available] = true
        payload[Wire.revision] = revision
        return payload
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

    /// What Dart is handed for a press on the state published last: the
    /// trigger, and Dart's number for that state.
    public func triggerArguments(for action: Action) -> [String: Any] {
        [
            Wire.trigger: action.rawValue,
            Wire.stateId: stateId.map { NSNumber(value: $0) } ?? NSNull(),
        ]
    }
}
