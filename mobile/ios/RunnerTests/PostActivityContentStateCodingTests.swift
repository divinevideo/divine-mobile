import CryptoKit
import XCTest
@testable import Runner

/// The push service sends `updatedAt` as Unix seconds (since 1970), but
/// ActivityKit decodes pushed state with a default `JSONDecoder`, whose Date
/// strategy counts from 2001. These tests pin the shared contract fixture.
final class PostActivityContentStateCodingTests: XCTestCase {
    private static let fixtureSha256 =
        "52c18d40f29b4a24458e1fd33a211b86ec1bab96d74f30d1f3de57e072089f55"

    private func fixtureData() throws -> Data {
        // RunnerTests run on the simulator on the same Mac, so the host
        // source path is readable.
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // RunnerTests
            .deletingLastPathComponent() // ios
            .deletingLastPathComponent() // mobile
            .appendingPathComponent("test/fixtures/live_activity_contract.json")
        return try Data(contentsOf: url)
    }

    private func fixture() throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: fixtureData())
        return try XCTUnwrap(object as? [String: Any])
    }

    func testDecodesEveryFixtureContentState() throws {
        let cases = try XCTUnwrap(fixture()["contentStates"] as? [[String: Any]])
        XCTAssertFalse(cases.isEmpty)
        for entry in cases {
            let name = entry["name"] as? String ?? "?"
            let json = try JSONSerialization.data(
                withJSONObject: try XCTUnwrap(entry["json"])
            )
            let expected = try XCTUnwrap(entry["expected"] as? [String: Any])
            // Default decoder, as ActivityKit uses.
            let state = try JSONDecoder().decode(
                PostActivityContentState.self, from: json
            )
            XCTAssertEqual(state.phase.rawValue, expected["phase"] as? String, name)
            XCTAssertEqual(state.views, expected["views"] as? Int, name)
            XCTAssertEqual(state.likes, expected["likes"] as? Int, name)
            XCTAssertEqual(state.comments, expected["comments"] as? Int, name)
            XCTAssertEqual(
                state.updatedAt.timeIntervalSince1970,
                try XCTUnwrap(expected["updatedAt"] as? Double),
                name
            )
            XCTAssertEqual(
                state.showFirstRunNote, expected["showFirstRunNote"] as? Bool, name
            )
            XCTAssertEqual(
                state.postCoordinate, expected["postCoordinate"] as? String, name
            )
            XCTAssertEqual(
                state.postEventId, expected["postEventId"] as? String, name
            )
        }
    }

    func testRoundTripsThroughDefaultCoders() throws {
        let original = PostActivityContentState(
            phase: .live,
            views: 7,
            likes: nil,
            comments: 0,
            updatedAt: Date(timeIntervalSince1970: 1_763_500_123),
            showFirstRunNote: true,
            postCoordinate: "34236:abc:d",
            postEventId: "def"
        )
        let data = try JSONEncoder().encode(original)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertEqual(object["updatedAt"] as? Double, 1_763_500_123)
        let decoded = try JSONDecoder().decode(
            PostActivityContentState.self, from: data
        )
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(
            decoded.updatedAt.timeIntervalSince1970.rounded(), 1_763_500_123
        )
    }

    func testFixtureChecksumIsPinned() throws {
        let digest = SHA256.hash(data: try fixtureData())
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(hex, Self.fixtureSha256)
    }

    func testLinksMatchFixture() throws {
        let links = try XCTUnwrap(fixture()["links"] as? [[String: Any]])
        XCTAssertFalse(links.isEmpty)
        for link in links {
            let expected = try XCTUnwrap(link["url"] as? String)
            let url = PostActivityLink.url(
                postEventId: link["postEventId"] as? String,
                postCoordinate: link["postCoordinate"] as? String
            )
            XCTAssertEqual(url?.absoluteString, expected)
        }
    }
}
