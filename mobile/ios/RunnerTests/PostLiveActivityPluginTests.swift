import UIKit
import XCTest
@testable import Runner

/// The pure pieces of the post Live Activity bridge. The ActivityKit calls
/// themselves are thin and are not started here.
final class PostLiveActivityPluginTests: XCTestCase {
    private let owner = String(repeating: "ab", count: 32)

    // MARK: Argument parsing

    func testStartArgumentsAcceptTheFullShape() throws {
        let args = try XCTUnwrap(PostActivityStartArguments([
            "ownerPubkey": owner,
            "thumbnailFileName": "x.jpg",
            "showFirstRunNote": true,
        ]))
        XCTAssertEqual(args.ownerPubkey, owner)
        XCTAssertEqual(args.thumbnailFileName, "x.jpg")
        XCTAssertTrue(args.showFirstRunNote)
    }

    func testStartArgumentsAcceptNoThumbnail() throws {
        let args = try XCTUnwrap(PostActivityStartArguments([
            "ownerPubkey": owner,
            "showFirstRunNote": false,
        ]))
        XCTAssertNil(args.thumbnailFileName)
        XCTAssertFalse(args.showFirstRunNote)
    }

    func testStartArgumentsRejectMissingOrMistypedKeys() {
        XCTAssertNil(PostActivityStartArguments(nil))
        XCTAssertNil(PostActivityStartArguments(["showFirstRunNote": true]))
        XCTAssertNil(PostActivityStartArguments(["ownerPubkey": owner]))
        XCTAssertNil(PostActivityStartArguments(["ownerPubkey": 1, "showFirstRunNote": true]))
        XCTAssertNil(PostActivityStartArguments(["ownerPubkey": owner, "showFirstRunNote": "yes"]))
        XCTAssertNil(PostActivityStartArguments([
            "ownerPubkey": owner, "showFirstRunNote": true, "thumbnailFileName": 3,
        ]))
    }

    func testUpdateArgumentsAcceptTheFullShape() throws {
        let args = try XCTUnwrap(PostActivityUpdateArguments([
            "activityId": "a1",
            "phase": "live",
            "postCoordinate": "34236:\(owner):d",
            "postEventId": "e",
            "showFirstRunNote": true,
        ]))
        XCTAssertEqual(args.activityId, "a1")
        XCTAssertEqual(args.phase, .live)
        XCTAssertEqual(args.postCoordinate, "34236:\(owner):d")
        XCTAssertEqual(args.postEventId, "e")
        XCTAssertTrue(args.showFirstRunNote)
    }

    func testUpdateArgumentsRejectMissingOrMistypedKeys() {
        let ok: [String: Any] = ["activityId": "a1", "phase": "posting", "showFirstRunNote": false]
        XCTAssertNotNil(PostActivityUpdateArguments(ok))
        for key in ["activityId", "phase", "showFirstRunNote"] {
            var args = ok
            args.removeValue(forKey: key)
            XCTAssertNil(PostActivityUpdateArguments(args), "missing \(key)")
        }
        XCTAssertNil(PostActivityUpdateArguments(ok.merging(["phase": "bogus"]) { $1 }))
        XCTAssertNil(PostActivityUpdateArguments(ok.merging(["phase": 2]) { $1 }))
        XCTAssertNil(PostActivityUpdateArguments(ok.merging(["postEventId": 2]) { $1 }))
    }

    // MARK: Thumbnail writer

    private func jpegData(side: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side * 2, height: side), format: format)
        let image = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: side * 2, height: side))
        }
        return image.jpegData(compressionQuality: 1)!
    }

    private func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testThumbnailWriterUsesItsOwnNameAndDownscales() throws {
        let container = try tempDir()
        let name = try PostActivityThumbnailWriter.write(jpegData(side: 500), containerURL: container)
        XCTAssertTrue(name.hasSuffix(".jpg"))
        let stem = String(name.dropLast(4))
        XCTAssertNotNil(UUID(uuidString: stem))
        let file = container
            .appendingPathComponent(PostActivityThumbnail.directory)
            .appendingPathComponent(name)
        let image = try XCTUnwrap(UIImage(contentsOfFile: file.path))
        let longest = max(image.size.width * image.scale, image.size.height * image.scale)
        XCTAssertLessThanOrEqual(longest, 144)
        XCTAssertGreaterThan(longest, 100)
    }

    func testThumbnailWriterDoesNotUpscaleSmallImages() throws {
        let container = try tempDir()
        let name = try PostActivityThumbnailWriter.write(jpegData(side: 20), containerURL: container)
        let file = container
            .appendingPathComponent(PostActivityThumbnail.directory)
            .appendingPathComponent(name)
        let image = try XCTUnwrap(UIImage(contentsOfFile: file.path))
        XCTAssertLessThanOrEqual(image.size.width * image.scale, 40)
    }

    func testThumbnailWriterDeletesEveryOtherFile() throws {
        let container = try tempDir()
        let dir = container.appendingPathComponent(PostActivityThumbnail.directory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data([1]).write(to: dir.appendingPathComponent("old.jpg"))
        try Data([1]).write(to: dir.appendingPathComponent("stray.bin"))
        let name = try PostActivityThumbnailWriter.write(jpegData(side: 50), containerURL: container)
        let remaining = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertEqual(remaining, [name])
    }

    func testThumbnailWriterRejectsNonImageBytesAndKeepsOldFiles() throws {
        let container = try tempDir()
        let dir = container.appendingPathComponent(PostActivityThumbnail.directory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data([1]).write(to: dir.appendingPathComponent("old.jpg"))
        XCTAssertThrowsError(
            try PostActivityThumbnailWriter.write(Data([0, 1, 2]), containerURL: container)
        )
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path), ["old.jpg"])
    }

    // MARK: Push token and replay

    func testPushTokenHexIsLowercaseAndZeroPadded() {
        XCTAssertEqual(PostActivityPushToken.hex(Data([0x00, 0xAB, 0x0F, 0xFF])), "00ab0fff")
    }

    private struct FakeSource: PostActivitySource {
        var items: [PostActivitySnapshot]
        var enabled = true
        func snapshots() -> [PostActivitySnapshot] { items }
        func isEnabled() -> Bool { enabled }
    }

    private func snapshot(_ id: String, token: Data?, state: String = "active") -> PostActivitySnapshot {
        PostActivitySnapshot(
            activityId: id, ownerPubkey: owner, startedAtMs: 5,
            postCoordinate: nil, postEventId: nil, state: state, pushToken: token
        )
    }

    func testOnListenReplaysEnablementTokensAndStates() {
        let source = FakeSource(items: [
            snapshot("a", token: Data([0xAB, 0xCD])),
            snapshot("b", token: nil, state: "ended"),
        ])
        let handler = PostActivityStreamHandler(source: source)
        var events: [[String: Any]] = []
        let error = handler.onListen(withArguments: nil) { event in
            events.append(event as! [String: Any])
            return
        }
        XCTAssertNil(error)
        let kinds = events.map { $0["type"] as? String }
        XCTAssertEqual(kinds, ["enablement", "pushToken", "state", "state"])
        XCTAssertEqual(events[0]["enabled"] as? Bool, true)
        XCTAssertEqual(events[1]["activityId"] as? String, "a")
        XCTAssertEqual(events[1]["token"] as? String, "abcd")
        XCTAssertEqual(events[2]["state"] as? String, "active")
        XCTAssertEqual(events[3]["activityId"] as? String, "b")
        XCTAssertEqual(events[3]["state"] as? String, "ended")
    }

    func testEventsAfterListenReachTheSinkAndStopAfterCancel() {
        let handler = PostActivityStreamHandler(source: FakeSource(items: []))
        var count = 0
        _ = handler.onListen(withArguments: nil) { _ in count += 1 }
        XCTAssertEqual(count, 1)  // enablement only
        handler.emit(["type": "state"])
        XCTAssertEqual(count, 2)
        _ = handler.onCancel(withArguments: nil)
        handler.emit(["type": "state"])
        XCTAssertEqual(count, 2)
    }

    func testEmitFromABackgroundQueueReachesTheSinkOnTheMainThread() {
        let handler = PostActivityStreamHandler(source: FakeSource(items: []))
        let delivered = expectation(description: "state event delivered")
        _ = handler.onListen(withArguments: nil) { event in
            guard (event as? [String: Any])?["type"] as? String == "state" else { return }
            XCTAssertTrue(Thread.isMainThread)
            delivered.fulfill()
        }
        DispatchQueue.global().async { handler.emit(["type": "state"]) }
        wait(for: [delivered], timeout: 5)
    }

    // MARK: Update content state

    private func contentState() -> PostActivityContentState {
        PostActivityContentState(
            phase: .posting, views: 3, likes: 2, comments: 1,
            updatedAt: Date(timeIntervalSince1970: 1), showFirstRunNote: false,
            postCoordinate: "old-coord", postEventId: "old-id"
        )
    }

    func testUpdateWithOmittedIdentityKeepsExistingValuesAndCounts() throws {
        let args = try XCTUnwrap(PostActivityUpdateArguments([
            "activityId": "a", "phase": "live", "showFirstRunNote": true,
        ]))
        let now = Date(timeIntervalSince1970: 99)
        let next = args.applied(to: contentState(), now: now)
        XCTAssertEqual(next.postCoordinate, "old-coord")
        XCTAssertEqual(next.postEventId, "old-id")
        XCTAssertEqual(next.phase, .live)
        XCTAssertTrue(next.showFirstRunNote)
        XCTAssertEqual(next.updatedAt, now)
        XCTAssertEqual([next.views, next.likes, next.comments], [3, 2, 1])
    }

    func testUpdateWithPresentIdentityReplacesIt() throws {
        let args = try XCTUnwrap(PostActivityUpdateArguments([
            "activityId": "a", "phase": "live", "showFirstRunNote": false,
            "postCoordinate": "new-coord", "postEventId": "new-id",
        ]))
        let next = args.applied(to: contentState(), now: Date())
        XCTAssertEqual(next.postCoordinate, "new-coord")
        XCTAssertEqual(next.postEventId, "new-id")
    }
}
