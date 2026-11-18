import Foundation

@main
enum HTTPPlaybackErrorTests {
    static func main() {
        precondition(httpServiceUnavailableCode(status: 503) == "service_unavailable")
        for status in [202, 401, 403, 404, 410, 500, 502, 504] {
            precondition(httpServiceUnavailableCode(status: status) == nil,
                         "HTTP \(status) must not permit mirror readiness fallback")
        }
        let url = URL(string: "https://example.test/clip.mp4")!
        for status in [401, 403, 404, 503] {
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
            let loaderError = NSError(
                domain: NSURLErrorDomain,
                code: NSURLErrorBadServerResponse,
                userInfo: ["NSURLErrorFailingURLResponseErrorKey": response]
            )
            let playerError = NSError(
                domain: "AVFoundationErrorDomain",
                code: -11800,
                userInfo: [NSUnderlyingErrorKey: loaderError]
            )
            precondition(playbackHTTPStatus(in: loaderError) == status)
            precondition(playbackHTTPStatus(in: playerError) == status)
        }
        let transportError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        precondition(playbackHTTPStatus(in: transportError) == nil)

        print("HTTP playback error tests passed")
    }
}
