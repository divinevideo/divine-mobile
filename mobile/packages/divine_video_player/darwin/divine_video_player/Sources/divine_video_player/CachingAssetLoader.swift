import AVFoundation
import Foundation
import UniformTypeIdentifiers

/// Streams a remote clip to `AVPlayer` through one download it keeps, so the
/// clip's audio can be decoded from the same bytes without fetching them
/// again — the Apple counterpart of decoding from ExoPlayer's cache on
/// Android (#9327).
///
/// `AVAssetReader` refuses a remote asset and `AVPlayer` keeps what it
/// downloads to itself, so the player is handed an asset whose URL scheme only
/// this loader can resolve. The loader fetches the file once, answers the
/// player's byte-range requests from what has arrived, and writes the file out
/// when it is complete. Feed clips are seconds long, so the bytes are held in
/// memory while the item lives.
final class CachingAssetLoader: NSObject, AVAssetResourceLoaderDelegate, URLSessionDataDelegate {

    /// The asset to play: the remote URL under a scheme `AVFoundation` hands
    /// to this loader.
    let asset: AVURLAsset

    /// Called on the main queue with the file the complete download was
    /// written to — at once when set after the download has finished, which
    /// a clip of a few seconds often has by the time its item is built.
    var onDownloaded: ((URL) -> Void)? {
        didSet {
            if let downloadedURL { onDownloaded?(downloadedURL) }
        }
    }

    /// The written file, once the download is complete. Main queue only.
    private var downloadedURL: URL?

    private let remoteURL: URL
    private let headers: [String: String]
    private let queue = DispatchQueue(label: "co.divine.video_player.caching_asset_loader")
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var data = Data()
    private var contentLength: Int64?
    private var contentType: String?
    private var finished = false
    private var failure: Error?
    private var cancelled = false
    private var fileURL: URL?
    private var pending: [AVAssetResourceLoadingRequest] = []

    /// A loader for [remoteURL], or nil for a URL it cannot serve.
    init?(remoteURL: URL, headers: [String: String]) {
        guard var components = URLComponents(url: remoteURL, resolvingAgainstBaseURL: false),
            let scheme = components.scheme?.lowercased(),
            scheme == "https" || scheme == "http"
        else { return nil }
        components.scheme = Self.schemePrefix + scheme
        guard let loaderURL = components.url else { return nil }
        self.remoteURL = remoteURL
        self.headers = headers
        self.asset = AVURLAsset(url: loaderURL)
        super.init()
        asset.resourceLoader.setDelegate(self, queue: queue)
    }

    /// Stops the download, fails whatever the player still waits for, and
    /// deletes the written file.
    func cancel() {
        queue.async { [self] in
            cancelled = true
            task?.cancel()
            session?.invalidateAndCancel()
            session = nil
            let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)
            pending.forEach { $0.finishLoading(with: error) }
            pending.removeAll()
            data = Data()
            if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
            fileURL = nil
        }
    }

    // MARK: - AVAssetResourceLoaderDelegate

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        guard !cancelled else { return false }
        pending.append(loadingRequest)
        startIfNeeded()
        serve()
        return true
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        didCancel loadingRequest: AVAssetResourceLoadingRequest
    ) {
        pending.removeAll { $0 === loadingRequest }
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            failure = NSError(
                domain: NSURLErrorDomain,
                code: NSURLErrorBadServerResponse,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"]
            )
            completionHandler(.cancel)
            serve()
            return
        }
        if response.expectedContentLength > 0 {
            contentLength = response.expectedContentLength
            data.reserveCapacity(Int(response.expectedContentLength))
        }
        contentType = response.mimeType.flatMap { UTType(mimeType: $0)?.identifier }
            ?? AVFileType.mp4.rawValue
        completionHandler(.allow)
        serve()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive chunk: Data) {
        data.append(chunk)
        serve()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        defer {
            self.session?.finishTasksAndInvalidate()
            self.session = nil
        }
        guard !cancelled else { return }
        if let error {
            if failure == nil { failure = error }
            serve()
            return
        }
        finished = true
        if contentLength == nil { contentLength = Int64(data.count) }
        serve()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("divine-loop-\(UUID().uuidString).mp4")
        do {
            try data.write(to: url)
        } catch {
            return
        }
        fileURL = url
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.downloadedURL = url
            self.onDownloaded?(url)
        }
    }

    // MARK: - Serving

    private func startIfNeeded() {
        guard task == nil, !finished, failure == nil, !cancelled else { return }
        let operationQueue = OperationQueue()
        operationQueue.underlyingQueue = queue
        operationQueue.maxConcurrentOperationCount = 1
        let session = URLSession(
            configuration: .default,
            delegate: self,
            delegateQueue: operationQueue
        )
        self.session = session
        var request = URLRequest(url: remoteURL)
        for (field, value) in headers { request.setValue(value, forHTTPHeaderField: field) }
        let task = session.dataTask(with: request)
        self.task = task
        task.resume()
    }

    /// Answers every waiting request as far as the bytes that have arrived
    /// allow, and finishes the ones that are complete.
    private func serve() {
        pending.removeAll { request in
            if let failure {
                request.finishLoading(with: failure)
                return true
            }
            guard let contentLength else { return false }
            if let info = request.contentInformationRequest {
                info.contentType = contentType
                info.contentLength = contentLength
                info.isByteRangeAccessSupported = true
            }
            guard let dataRequest = request.dataRequest else {
                request.finishLoading()
                return true
            }
            let requestEnd = dataRequest.requestsAllDataToEndOfResource
                ? Int(contentLength)
                : Int(dataRequest.requestedOffset) + dataRequest.requestedLength
            let offset = Int(dataRequest.currentOffset)
            if data.count > offset {
                let upper = min(data.count, requestEnd)
                if upper > offset {
                    dataRequest.respond(with: data.subdata(in: offset..<upper))
                }
            }
            let reached = Int(dataRequest.currentOffset)
            if reached >= requestEnd || (finished && reached >= data.count) {
                request.finishLoading()
                return true
            }
            return false
        }
    }

    /// Prefixed to the remote URL's scheme, so `AVFoundation` cannot load
    /// the asset itself and asks this loader.
    private static let schemePrefix = "divine-cache-"
}
