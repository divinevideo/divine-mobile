import ActivityKit
import Foundation

/// Where a post's Live Activity is in its first hour.
enum PostActivityPhase: String, Codable, Hashable {
    case posting
    case live
    case notFound
    case summary
}

/// The changing part of a post's Live Activity, sent by the app and the
/// push service.
///
/// Numbers and enums only: all copy is localized in the widget extension.
/// A nil count means "not known yet" and is never shown; zero is a confirmed
/// zero. The push service sends nil for zeros before the 10-minute settle
/// point, so this type never decides that itself.
struct PostActivityContentState: Codable, Hashable {
    var phase: PostActivityPhase
    var views: Int?
    var likes: Int?
    var comments: Int?
    var updatedAt: Date
    var showFirstRunNote: Bool
    /// The post's address and first event id. The activity starts before the
    /// post has either (the d tag is the uploaded file's hash), so they
    /// arrive with a later update. Nil decodes from pushes that omit them.
    var postCoordinate: String?
    var postEventId: String?

    init(
        phase: PostActivityPhase,
        views: Int?,
        likes: Int?,
        comments: Int?,
        updatedAt: Date,
        showFirstRunNote: Bool,
        postCoordinate: String? = nil,
        postEventId: String? = nil
    ) {
        self.phase = phase
        self.views = views
        self.likes = likes
        self.comments = comments
        self.updatedAt = updatedAt
        self.showFirstRunNote = showFirstRunNote
        self.postCoordinate = postCoordinate
        self.postEventId = postEventId
    }

    private enum CodingKeys: String, CodingKey {
        case phase, views, likes, comments, updatedAt, showFirstRunNote
        case postCoordinate, postEventId
    }

    /// ActivityKit decodes pushed state with a default `JSONDecoder`, whose
    /// Date strategy counts seconds from 2001. The push service sends
    /// standard Unix seconds (since 1970), so `updatedAt` is read and written
    /// as `timeIntervalSince1970` regardless of the coder's strategy.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        phase = try container.decode(PostActivityPhase.self, forKey: .phase)
        views = try container.decodeIfPresent(Int.self, forKey: .views)
        likes = try container.decodeIfPresent(Int.self, forKey: .likes)
        comments = try container.decodeIfPresent(Int.self, forKey: .comments)
        updatedAt = Date(
            timeIntervalSince1970:
                try container.decode(Double.self, forKey: .updatedAt)
        )
        showFirstRunNote = try container.decode(Bool.self, forKey: .showFirstRunNote)
        postCoordinate = try container.decodeIfPresent(
            String.self, forKey: .postCoordinate
        )
        postEventId = try container.decodeIfPresent(
            String.self, forKey: .postEventId
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(phase, forKey: .phase)
        try container.encodeIfPresent(views, forKey: .views)
        try container.encodeIfPresent(likes, forKey: .likes)
        try container.encodeIfPresent(comments, forKey: .comments)
        try container.encode(updatedAt.timeIntervalSince1970, forKey: .updatedAt)
        try container.encode(showFirstRunNote, forKey: .showFirstRunNote)
        try container.encodeIfPresent(postCoordinate, forKey: .postCoordinate)
        try container.encodeIfPresent(postEventId, forKey: .postEventId)
    }
}

/// The fixed part of a post's Live Activity: whose, and when it started.
///
/// Which post it is lives in the content state, because the post has no
/// identity when the activity starts. Identifiers are kept whole (full
/// 64-character hex), never shortened.
@available(iOS 16.2, *)
struct PostActivityAttributes: ActivityAttributes {
    typealias ContentState = PostActivityContentState

    let ownerPubkey: String
    let thumbnailFileName: String?
    let startedAt: Date
}
