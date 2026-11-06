import Foundation

@main
enum PlaybackNetworkObservationTests {
    static func main() {
        var now: UInt64 = 0
        var samples: [[String: Any]] = []
        let observation = PlaybackNetworkObservation(
            loadID: "11111111-1111-4111-8111-111111111111",
            now: { now }, emit: { samples.append($0) }
        )!
        now = 7_000_000
        observation.headers()
        precondition(samples.count == 1)
        precondition(samples[0]["network_headers_ms"] as? Int == 7)
        precondition(samples[0]["network_bytes"] == nil)
        observation.received(3)
        now = 12_000_000
        observation.finish(outcome: "complete")
        observation.finish(outcome: "cancelled")
        precondition(samples.count == 2)
        precondition(samples[1]["network_bytes"] as? Int == 3)
        precondition(samples[1]["network_duration_ms"] as? Int == 12)
        precondition(samples[1]["network_outcome"] as? String == "complete")
        precondition(PlaybackNetworkObservation(loadID: "private", emit: { _ in }) == nil)
        let revoked = PlaybackNetworkObservation(loadID: "11111111-1111-4111-8111-111111111111", emit: { _ in fatalError("revoked") })!
        revoked.invalidate()
        revoked.headers()
        revoked.finish(outcome: "complete")
        let headers = PlaybackNetworkObservation.withoutCorrelation(["x-playback-load-id": "id", "Authorization": "token"])
        precondition(headers == ["Authorization": "token"])
        print("PlaybackNetworkObservationTests passed")
    }
}
