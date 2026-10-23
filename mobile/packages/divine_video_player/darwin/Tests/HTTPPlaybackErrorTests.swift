import Foundation

@main
enum HTTPPlaybackErrorTests {
    static func main() {
        precondition(httpServiceUnavailableCode(status: 503) == "service_unavailable")
        for status in [202, 401, 403, 404, 410, 500, 502, 504] {
            precondition(httpServiceUnavailableCode(status: status) == nil,
                         "HTTP \(status) must not permit mirror readiness fallback")
        }
        print("HTTP playback error tests passed")
    }
}
