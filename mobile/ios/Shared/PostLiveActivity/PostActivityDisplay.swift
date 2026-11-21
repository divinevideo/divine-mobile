import Foundation
import UIKit

/// The line a post's Live Activity leads with.
enum PostActivityHeadline: Equatable {
    case posting
    case live
    case noViewsYet
    case cantFind
    case firstHour
    case noViewsFirstHour
}

enum PostActivityMetric: CaseIterable {
    case views
    case likes
    case comments
}

struct PostActivityCount: Equatable {
    let metric: PostActivityMetric
    let value: Int
}

/// What a post's Live Activity shows for a given state. Every presentation
/// reads this rather than the raw state, so the rules live in one place.
struct PostActivityDisplay: Equatable {
    let headline: PostActivityHeadline
    /// Known counts in views, likes, comments order. Unknown (nil) counts are
    /// left out; confirmed zeros are kept.
    let counts: [PostActivityCount]
    let showsFirstRunNote: Bool
    let showsUpdatedAt: Bool
    /// The single count the compact Dynamic Island shows.
    let compactCount: PostActivityCount?

    static func make(state: PostActivityContentState, isStale: Bool) -> PostActivityDisplay {
        let known = knownCounts(state)
        let allConfirmedZero = state.views == 0 && state.likes == 0 && state.comments == 0
        let headline: PostActivityHeadline
        let counts: [PostActivityCount]
        switch state.phase {
        case .posting:
            (headline, counts) = (.posting, [])
        case .notFound:
            (headline, counts) = (.cantFind, [])
        case .live:
            (headline, counts) = allConfirmedZero ? (.noViewsYet, []) : (.live, known)
        case .summary:
            (headline, counts) = allConfirmedZero ? (.noViewsFirstHour, []) : (.firstHour, known)
        }
        let inProgress = state.phase == .posting || state.phase == .live
        return PostActivityDisplay(
            headline: headline,
            counts: counts,
            showsFirstRunNote: state.showFirstRunNote && counts.isEmpty && inProgress
                && headline != .noViewsYet,
            showsUpdatedAt: isStale && inProgress,
            compactCount: [PostActivityMetric.likes, .views, .comments]
                .lazy
                .compactMap { metric in counts.first { $0.metric == metric } }
                .first
        )
    }

    private static func knownCounts(_ state: PostActivityContentState) -> [PostActivityCount] {
        [
            state.views.map { PostActivityCount(metric: .views, value: $0) },
            state.likes.map { PostActivityCount(metric: .likes, value: $0) },
            state.comments.map { PostActivityCount(metric: .comments, value: $0) },
        ].compactMap { $0 }
    }
}

/// One piece of what VoiceOver reads for the activity, in reading order.
enum PostActivitySpokenPart: Equatable {
    case yourPost
    case headline(PostActivityHeadline)
    case count(PostActivityCount)
    case firstRunNote
    case updated
}

extension PostActivityDisplay {
    /// Everything a sighted person can see, in the order it should be read,
    /// including that the numbers have gone stale.
    var spokenParts: [PostActivitySpokenPart] {
        [.yourPost, .headline(headline)]
            + counts.map(PostActivitySpokenPart.count)
            + (showsFirstRunNote ? [.firstRunNote] : [])
            + (showsUpdatedAt ? [.updated] : [])
    }
}

enum PostActivityFormat {
    /// A locale-aware compact number, so 1,234,567 reads "1.2M" in English.
    static func compact(_ value: Int, locale: Locale) -> String {
        value.formatted(.number.notation(.compactName).locale(locale))
    }
}

/// The post's thumbnail, which the app writes into the shared app group
/// because a Live Activity cannot fetch from the network.
enum PostActivityThumbnail {
    static let appGroup = "group.co.openvine.app"
    static let directory = "LiveActivityThumbnails"

    /// Nil for a missing name or container, a missing file, or bytes that are
    /// not an image; the presentation then shows its placeholder.
    static func load(fileName: String?, containerURL: URL?) -> UIImage? {
        guard let fileName, let containerURL else { return nil }
        let url = containerURL
            .appendingPathComponent(directory, isDirectory: true)
            .appendingPathComponent(fileName)
        return UIImage(contentsOfFile: url.path)
    }
}

/// Where tapping the activity goes: that post's stats. Until the app's
/// deep-link handling knows this route, a tap opens the app at its default
/// screen.
enum PostActivityLink {
    /// Characters a query value may carry unescaped. `&`, `=`, `+` and `?`
    /// are legal in a query but would split or corrupt the value, so they
    /// are escaped too.
    private static let queryValueAllowed: CharacterSet = {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+?/")
        return allowed
    }()

    /// Carries the post's address as well as its first event id: after an
    /// edit that id no longer resolves, and the address still does.
    ///
    /// Nil until the post has both, so the widget sets no link before then.
    static func url(postEventId: String?, postCoordinate: String?) -> URL? {
        guard let postEventId, !postEventId.isEmpty,
              let postCoordinate, !postCoordinate.isEmpty
        else { return nil }
        var components = URLComponents()
        components.scheme = "divine"
        components.host = ""
        components.path = "/post-analytics/\(postEventId)"
        guard let coordinate = postCoordinate.addingPercentEncoding(
            withAllowedCharacters: queryValueAllowed
        ) else { return nil }
        components.percentEncodedQuery = "coordinate=\(coordinate)"
        return components.url
    }
}
