import Foundation

/// One actual URLSession request; no content or identity enters the sample.
final class PlaybackNetworkObservation {
    private let loadID: String
    private let requestID = UUID().uuidString.lowercased()
    private let now: () -> UInt64
    private let started: UInt64
    private let emit: ([String: Any]) -> Void
    private var headerMS: Int?
    private var bytes = 0
    private var active = true

    init?(loadID: String, now: @escaping () -> UInt64 = { DispatchTime.now().uptimeNanoseconds },
          emit: @escaping ([String: Any]) -> Void) {
        guard loadID.range(of: "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", options: .regularExpression) != nil else { return nil }
        self.loadID = loadID
        self.now = now
        self.started = now()
        self.emit = emit
    }

    static func withoutCorrelation(_ headers: [String: String]) -> [String: String] {
        headers.filter { $0.key.lowercased() != "x-playback-load-id" }
    }

    func invalidate() { active = false }
    func received(_ count: Int) { bytes += count }
    func headers() {
        guard active else { return }
        headerMS = elapsed()
        emit(sample(outcome: "unavailable", terminal: false))
    }
    func finish(outcome: String) {
        guard active else { return }
        active = false
        emit(sample(outcome: outcome, terminal: true))
    }
    private func elapsed() -> Int { Int((now() - started) / 1_000_000) }
    private func sample(outcome: String, terminal: Bool) -> [String: Any] {
        var result: [String: Any] = ["type": "playback_network", "load_id": loadID,
                                     "request_id": requestID, "network_outcome": outcome]
        if let headerMS, headerMS <= 600000 { result["network_headers_ms"] = headerMS }
        if terminal {
            let duration = elapsed()
            if duration <= 600000 { result["network_duration_ms"] = duration }
            if bytes <= 1073741824 { result["network_bytes"] = bytes }
        }
        return result
    }
}
