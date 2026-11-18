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
}

/// The fixed part of a post's Live Activity: which post, whose, and when.
///
/// Identifiers are kept whole (full 64-character hex), never shortened.
@available(iOS 16.2, *)
struct PostActivityAttributes: ActivityAttributes {
    typealias ContentState = PostActivityContentState

    let ownerPubkey: String
    let postCoordinate: String
    let postEventId: String
    let thumbnailFileName: String?
    let postedAt: Date
}
