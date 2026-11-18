import Foundation

@main
enum HTTPPlaybackErrorTests {
    static func main() {
        let url = URL(string: "https://example.test/clip.mp4")!
        for (status, expected) in [
            (202, "media_processing"), (401, "auth_required"),
            (403, "forbidden"), (404, "not_found"), (410, "http_client_error"),
            (500, "http_server_error"), (502, "http_server_error"),
            (503, "service_unavailable"), (504, "http_server_error")
        ] {
            let loaderError = responseError(url: url, status: status)
            precondition(playbackNetworkErrorCode(in: loaderError) == expected)
            precondition(playbackNetworkErrorCode(in: wrapping(loaderError)) == expected)
        }

        for (code, expected) in [
            (NSURLErrorTimedOut, "timeout"),
            (NSURLErrorCannotFindHost, "network_error"),
            (NSURLErrorDNSLookupFailed, "network_error"),
            (NSURLErrorCannotConnectToHost, "network_error"),
            (NSURLErrorNetworkConnectionLost, "network_error")
        ] {
            let transport = NSError(domain: NSURLErrorDomain, code: code)
            precondition(playbackNetworkErrorCode(in: transport) == expected)
            precondition(playbackNetworkErrorCode(in: wrapping(wrapping(transport))) == expected)
        }
        let denied = [(401, "auth_required"), (403, "forbidden"), (404, "not_found")]
        for (status, expected) in denied {
            let denial = responseError(url: url, status: status)
            let timedOut = NSError(
                domain: NSURLErrorDomain,
                code: NSURLErrorTimedOut,
                userInfo: [NSUnderlyingErrorKey: denial]
            )
            precondition(playbackNetworkErrorCode(in: timedOut) == expected)
        }
        var deeplyNested = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        for _ in 0..<8 {
            deeplyNested = wrapping(deeplyNested)
        }
        precondition(playbackNetworkErrorCode(in: deeplyNested) == nil)
        let cancelled = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)
        precondition(playbackNetworkErrorCode(in: wrapping(cancelled)) == nil)
        let badCertificate = NSError(domain: NSURLErrorDomain, code: NSURLErrorServerCertificateUntrusted)
        precondition(playbackNetworkErrorCode(in: wrapping(badCertificate)) == nil)

        print("HTTP playback error tests passed")
    }
}

private func wrapping(_ error: NSError) -> NSError {
    NSError(domain: "AVFoundationErrorDomain", code: -11800, userInfo: [NSUnderlyingErrorKey: error])
}

private func responseError(url: URL, status: Int) -> NSError {
    let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
    return NSError(
        domain: NSURLErrorDomain,
        code: NSURLErrorBadServerResponse,
        userInfo: ["NSURLErrorFailingURLResponseErrorKey": response]
    )
}
