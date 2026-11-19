import UIKit
import XCTest
@testable import Runner

/// Rules for what the post Live Activity shows. A nil count means "not known
/// yet" and must never render; a zero is a confirmed zero and does.
final class PostActivityDisplayTests: XCTestCase {
    private let fullEventId = String(repeating: "ab", count: 32)

    private func state(
        _ phase: PostActivityPhase,
        views: Int? = nil,
        likes: Int? = nil,
        comments: Int? = nil,
        note: Bool = false
    ) -> PostActivityContentState {
        PostActivityContentState(
            phase: phase,
            views: views,
            likes: likes,
            comments: comments,
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            showFirstRunNote: note
        )
    }

    private func display(
        _ state: PostActivityContentState,
        stale: Bool = false
    ) -> PostActivityDisplay {
        PostActivityDisplay.make(state: state, isStale: stale)
    }

    // MARK: - Mapping table

    func testPostingShowsPostingAndNoCounts() {
        let result = display(state(.posting, views: 5, likes: 2, comments: 1))
        XCTAssertEqual(result.headline, .posting)
        XCTAssertEqual(result.counts, [])
    }

    func testLiveWithAllNilShowsLiveAndNoCounts() {
        let result = display(state(.live))
        XCTAssertEqual(result.headline, .live)
        XCTAssertEqual(result.counts, [])
    }

    func testLiveWithAllConfirmedZerosShowsNoViewsYet() {
        let result = display(state(.live, views: 0, likes: 0, comments: 0))
        XCTAssertEqual(result.headline, .noViewsYet)
        XCTAssertEqual(result.counts, [])
    }

    func testLiveWithCountsShowsLiveAndEveryKnownCount() {
        let result = display(state(.live, views: 48, likes: 9, comments: 2))
        XCTAssertEqual(result.headline, .live)
        XCTAssertEqual(result.counts, [
            PostActivityCount(metric: .views, value: 48),
            PostActivityCount(metric: .likes, value: 9),
            PostActivityCount(metric: .comments, value: 2),
        ])
    }

    func testNotFoundShowsCantFindAndNoCounts() {
        let result = display(state(.notFound, views: 3))
        XCTAssertEqual(result.headline, .cantFind)
        XCTAssertEqual(result.counts, [])
    }

    func testSummaryWithAllConfirmedZerosShowsNoViewsInFirstHour() {
        let result = display(state(.summary, views: 0, likes: 0, comments: 0))
        XCTAssertEqual(result.headline, .noViewsFirstHour)
        XCTAssertEqual(result.counts, [])
    }

    func testSummaryWithCountsShowsFirstHourAndKnownCounts() {
        let result = display(state(.summary, views: 212, likes: 31, comments: 6))
        XCTAssertEqual(result.headline, .firstHour)
        XCTAssertEqual(result.counts.map(\.value), [212, 31, 6])
    }

    // MARK: - Unknown versus zero

    func testLiveWithSomeNilCountsShowsOnlyKnownCounts() {
        let result = display(state(.live, views: 12, likes: 3))
        XCTAssertEqual(result.headline, .live)
        XCTAssertEqual(result.counts, [
            PostActivityCount(metric: .views, value: 12),
            PostActivityCount(metric: .likes, value: 3),
        ])
    }

    func testConfirmedZerosAreShownAlongsideOtherCounts() {
        let result = display(state(.live, views: 40, likes: 0, comments: 0))
        XCTAssertEqual(result.counts, [
            PostActivityCount(metric: .views, value: 40),
            PostActivityCount(metric: .likes, value: 0),
            PostActivityCount(metric: .comments, value: 0),
        ])
    }

    func testNilIsNeverRenderedAsZero() {
        let result = display(state(.live, likes: 0, comments: 0))
        XCTAssertEqual(result.headline, .live)
        XCTAssertEqual(result.counts, [
            PostActivityCount(metric: .likes, value: 0),
            PostActivityCount(metric: .comments, value: 0),
        ])
    }

    // MARK: - Staleness and first-run note

    func testStalePostingShowsUpdatedAt() {
        XCTAssertTrue(display(state(.posting), stale: true).showsUpdatedAt)
    }

    func testFreshLiveDoesNotShowUpdatedAt() {
        XCTAssertFalse(display(state(.live, views: 4), stale: false).showsUpdatedAt)
    }

    func testStaleSummaryDoesNotShowUpdatedAt() {
        XCTAssertFalse(display(state(.summary, views: 4), stale: true).showsUpdatedAt)
    }

    func testFirstRunNoteShownBeforeCountsArrive() {
        XCTAssertTrue(display(state(.live, note: true)).showsFirstRunNote)
    }

    func testFirstRunNoteHiddenOnceCountsArrive() {
        XCTAssertFalse(display(state(.live, likes: 1, note: true)).showsFirstRunNote)
    }

    func testFirstRunNoteHiddenWhenNoViewsYet() {
        let result = display(state(.live, views: 0, likes: 0, comments: 0, note: true))
        XCTAssertFalse(result.showsFirstRunNote)
    }

    // MARK: - Compact count

    func testCompactCountPrefersLikesThenViews() {
        XCTAssertEqual(
            display(state(.live, views: 10, likes: 2, comments: 1)).compactCount,
            PostActivityCount(metric: .likes, value: 2)
        )
        XCTAssertEqual(
            display(state(.live, views: 10, comments: 1)).compactCount,
            PostActivityCount(metric: .views, value: 10)
        )
        XCTAssertEqual(
            display(state(.live, comments: 1)).compactCount,
            PostActivityCount(metric: .comments, value: 1)
        )
        XCTAssertNil(display(state(.live)).compactCount)
    }

    // MARK: - Formatting, thumbnail, link, size

    func testCompactFormatsLargeCountsPerLocale() {
        let english = PostActivityFormat.compact(1_234_567, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(english, "1.2M")

        let germanLocale = Locale(identifier: "de_DE")
        let german = PostActivityFormat.compact(1_234_567, locale: germanLocale)
        XCTAssertEqual(
            german,
            1_234_567.formatted(.number.notation(.compactName).locale(germanLocale))
        )
        XCTAssertFalse(german.contains("1234567"))
        XCTAssertFalse(german.contains("1.234.567"))
    }

    func testThumbnailLoadReturnsNilForMissingNameFileOrBadBytes() throws {
        let container = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let directory = container.appendingPathComponent(
            PostActivityThumbnail.directory,
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: container) }

        XCTAssertNil(PostActivityThumbnail.load(fileName: nil, containerURL: container))
        XCTAssertNil(PostActivityThumbnail.load(fileName: "a.png", containerURL: nil))
        XCTAssertNil(PostActivityThumbnail.load(fileName: "missing.png", containerURL: container))

        try Data("not an image".utf8).write(to: directory.appendingPathComponent("bad.png"))
        XCTAssertNil(PostActivityThumbnail.load(fileName: "bad.png", containerURL: container))

        let png = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
            .image { context in
                UIColor.green.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
            }
            .pngData()
        try XCTUnwrap(png).write(to: directory.appendingPathComponent("good.png"))
        XCTAssertNotNil(PostActivityThumbnail.load(fileName: "good.png", containerURL: container))
    }

    func testLinkCarriesFullEventIdAndCoordinate() throws {
        let coordinate = "34236:\(String(repeating: "cd", count: 32)):my-post"
        let url = try XCTUnwrap(
            PostActivityLink.url(postEventId: fullEventId, postCoordinate: coordinate)
        )
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.scheme, "divine")
        XCTAssertEqual(components.path, "/post-analytics/\(fullEventId)")
        XCTAssertEqual(
            components.queryItems?.first { $0.name == "coordinate" }?.value,
            coordinate
        )
    }

    /// After an edit the first event id no longer resolves, so the address
    /// has to survive the trip, whatever characters its d-tag holds.
    func testLinkEncodesACoordinateWithAnyDTag() throws {
        let coordinate = "34236:\(String(repeating: "cd", count: 32)):a b&c=d/é?#"
        let url = try XCTUnwrap(
            PostActivityLink.url(postEventId: fullEventId, postCoordinate: coordinate)
        )
        let decoded = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "coordinate" }?.value
        XCTAssertEqual(decoded, coordinate)
    }

    // MARK: - What VoiceOver reads

    func testSpokenPartsReadHeadlineThenEachKnownCountInOrder() {
        let parts = display(state(.live, views: 48, likes: 9)).spokenParts
        XCTAssertEqual(parts, [
            .yourPost,
            .headline(.live),
            .count(PostActivityCount(metric: .views, value: 48)),
            .count(PostActivityCount(metric: .likes, value: 9)),
        ])
    }

    func testSpokenPartsSayWhenTheActivityIsStale() {
        let parts = display(state(.live, views: 48), stale: true).spokenParts
        XCTAssertEqual(parts.last, .updated)
    }

    func testSpokenPartsIncludeTheFirstRunNote() {
        let parts = display(state(.live, note: true)).spokenParts
        XCTAssertEqual(parts, [.yourPost, .headline(.live), .firstRunNote])
    }

    func testContentStateRoundTripsAndStaysSmall() throws {
        let original = state(.summary, views: 1_234_567, likes: 89_012, comments: 3_456, note: true)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PostActivityContentState.self, from: encoded)
        XCTAssertEqual(decoded, original)
        XCTAssertLessThan(encoded.count, 4096)
    }
}
