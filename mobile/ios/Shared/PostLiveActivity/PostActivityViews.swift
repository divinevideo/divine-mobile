import SwiftUI
import UIKit

/// Every string key the post Live Activity uses, in one list so tests can
/// check each one exists in every widget localization.
enum PostActivityStrings {
    static let yourPost = "divine_post_activity_your_post"
    static let posting = "divine_post_activity_posting"
    static let live = "divine_post_activity_live"
    static let noViewsYet = "divine_post_activity_no_views_yet %@"
    static let cantFind = "divine_post_activity_cant_find"
    static let firstHour = "divine_post_activity_first_hour"
    static let noViewsFirstHour = "divine_post_activity_no_views_first_hour"
    static let updated = "divine_post_activity_updated %@"
    static let firstRunNote = "divine_post_activity_first_run_note"

    static let keys = [
        yourPost, posting, live, noViewsYet, cantFind,
        firstHour, noViewsFirstHour, updated, firstRunNote,
    ]

    /// Plural forms for VoiceOver, in `Localizable.stringsdict`. The ` %lld`
    /// suffix is the key SwiftUI derives from an `Int` interpolation.
    static let pluralKeys = [
        "divine_post_activity_views_count %lld",
        "divine_post_activity_likes_count %lld",
        "divine_post_activity_comments_count %lld",
    ]
}

enum PostActivityColors {
    static let green = Color(red: 39 / 255, green: 197 / 255, blue: 139 / 255)
    /// The activity's own background, so its white text reads the same in
    /// dark and light.
    static let deepGreen = Color(red: 0, green: 21 / 255, blue: 13 / 255)
}

/// The activity's text styles. Rounded, like the camera's Live Activity
/// (#11134), so Divine's activities read as one family.
enum PostActivityFonts {
    static let headline = Font.system(.headline, design: .rounded)
    static let detail = Font.system(.subheadline, design: .rounded).weight(.semibold)
    static let caption = Font.system(.caption, design: .rounded)
    static let compactCount = Font.system(.caption2, design: .rounded).weight(.semibold)
}

// MARK: - Presentations

@available(iOS 16.2, *)
struct PostActivityLockScreenView: View {
    let attributes: PostActivityAttributes
    let display: PostActivityDisplay
    let state: PostActivityContentState
    let thumbnail: UIImage?
    let bundle: Bundle

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            PostActivityThumbnailView(image: thumbnail, size: 52, cornerRadius: 10)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    PostActivityHeadlineText(
                        headline: display.headline,
                        postedAt: attributes.postedAt,
                        bundle: bundle
                    )
                    .font(PostActivityFonts.headline)
                    Spacer(minLength: 4)
                    PostActivityTimeText(
                        display: display,
                        state: state,
                        postedAt: attributes.postedAt,
                        bundle: bundle
                    )
                    .font(PostActivityFonts.caption)
                    .foregroundStyle(.white.opacity(0.7))
                }
                PostActivityDetailLine(display: display, bundle: bundle)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            PostActivityAccessibility.label(
                parts: display.spokenParts,
                postedAt: attributes.postedAt,
                updatedAt: state.updatedAt,
                bundle: bundle
            )
        )
    }
}

/// The compact island's leading side. It carries the headline for VoiceOver,
/// since the thumbnail alone says nothing.
struct PostActivityCompactLeadingView: View {
    let thumbnail: UIImage?
    let display: PostActivityDisplay
    let postedAt: Date
    let bundle: Bundle

    var body: some View {
        PostActivityThumbnailView(image: thumbnail, size: 22, cornerRadius: 5)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                PostActivityAccessibility.label(
                    parts: [.yourPost, .headline(display.headline)],
                    postedAt: postedAt,
                    updatedAt: postedAt,
                    bundle: bundle
                )
            )
    }
}

/// The compact island's single count. Dimmed, and said to be old, when the
/// server has stopped checking in, so a frozen number never reads as current.
struct PostActivityCompactTrailingView: View {
    let display: PostActivityDisplay
    let updatedAt: Date
    let bundle: Bundle

    var body: some View {
        if let count = display.compactCount {
            PostActivityCountLabel(count: count)
                .font(PostActivityFonts.compactCount)
                .foregroundStyle(PostActivityColors.green)
                .opacity(display.showsUpdatedAt ? 0.5 : 1)
                .frame(maxWidth: 52)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    PostActivityAccessibility.label(
                        parts: [.count(count)] + (display.showsUpdatedAt ? [.updated] : []),
                        postedAt: updatedAt,
                        updatedAt: updatedAt,
                        bundle: bundle
                    )
                )
        }
    }
}

struct PostActivityMinimalView: View {
    let thumbnail: UIImage?
    let display: PostActivityDisplay
    let postedAt: Date
    let bundle: Bundle

    var body: some View {
        PostActivityThumbnailView(image: thumbnail, size: 20, cornerRadius: 10)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                PostActivityAccessibility.label(
                    parts: [.yourPost, .headline(display.headline)],
                    postedAt: postedAt,
                    updatedAt: postedAt,
                    bundle: bundle
                )
            )
    }
}

/// The expanded island's bottom region: counts or note, then "Updated … ago"
/// when stale. It carries the whole activity's VoiceOver label, so the
/// counts are never read as bare numbers.
struct PostActivityExpandedBottomView: View {
    let display: PostActivityDisplay
    let postedAt: Date
    let updatedAt: Date
    let bundle: Bundle

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            PostActivityDetailLine(display: display, bundle: bundle)
            if display.showsUpdatedAt {
                Text("divine_post_activity_updated \(Text(updatedAt, style: .relative))", bundle: bundle)
                    .font(PostActivityFonts.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            PostActivityAccessibility.label(
                parts: display.spokenParts,
                postedAt: postedAt,
                updatedAt: updatedAt,
                bundle: bundle
            )
        )
    }
}

// MARK: - Pieces

struct PostActivityHeadlineText: View {
    let headline: PostActivityHeadline
    let postedAt: Date
    let bundle: Bundle

    var body: some View {
        // Two lines: the longest messages ("can't find stats", "no views yet
        // · live for …") are the ones that must not be cut off.
        PostActivityAccessibility.headlineText(headline, postedAt: postedAt, bundle: bundle)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Time since posting, or how long ago the server last checked in when the
/// content has gone stale. Hidden where the headline already says it, or
/// where it no longer matters.
@available(iOS 16.2, *)
struct PostActivityTimeText: View {
    let display: PostActivityDisplay
    let state: PostActivityContentState
    let postedAt: Date
    let bundle: Bundle

    var body: some View {
        if display.showsUpdatedAt {
            Text("divine_post_activity_updated \(Text(state.updatedAt, style: .relative))", bundle: bundle)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        } else if display.headline == .posting || display.headline == .live {
            Text(postedAt, style: .relative)
                .lineLimit(1)
                .monospacedDigit()
        }
    }
}

/// The counts row, or the first-run note while nothing is known yet.
struct PostActivityDetailLine: View {
    let display: PostActivityDisplay
    let bundle: Bundle

    var body: some View {
        if !display.counts.isEmpty {
            HStack(spacing: 14) {
                ForEach(display.counts, id: \.metric) { count in
                    PostActivityCountLabel(count: count)
                }
            }
            .font(PostActivityFonts.detail)
        } else if display.showsFirstRunNote {
            Text(LocalizedStringKey(PostActivityStrings.firstRunNote), bundle: bundle)
                .font(PostActivityFonts.caption)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }
}

struct PostActivityCountLabel: View {
    let count: PostActivityCount
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: count.metric.symbolName)
                .imageScale(.small)
                .accessibilityHidden(true)
            Text(PostActivityFormat.compact(count.value, locale: locale))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

struct PostActivityThumbnailView: View {
    let image: UIImage?
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                PostActivityColors.green
                    .overlay(
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: size * 0.45, weight: .semibold))
                            .foregroundStyle(.white)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }
}

extension PostActivityMetric {
    var symbolName: String {
        switch self {
        case .views: return "play.fill"
        case .likes: return "heart.fill"
        case .comments: return "bubble.right.fill"
        }
    }
}

// MARK: - Accessibility and copy

enum PostActivityAccessibility {
    static func headlineText(_ headline: PostActivityHeadline, postedAt: Date, bundle: Bundle) -> Text {
        switch headline {
        case .posting:
            return Text(LocalizedStringKey(PostActivityStrings.posting), bundle: bundle)
        case .live:
            return Text(LocalizedStringKey(PostActivityStrings.live), bundle: bundle)
        case .noViewsYet:
            return Text("divine_post_activity_no_views_yet \(Text(postedAt, style: .relative))", bundle: bundle)
        case .cantFind:
            return Text(LocalizedStringKey(PostActivityStrings.cantFind), bundle: bundle)
        case .firstHour:
            return Text(LocalizedStringKey(PostActivityStrings.firstHour), bundle: bundle)
        case .noViewsFirstHour:
            return Text(LocalizedStringKey(PostActivityStrings.noViewsFirstHour), bundle: bundle)
        }
    }

    static func countText(_ count: PostActivityCount, bundle: Bundle) -> Text {
        switch count.metric {
        case .views:
            return Text("divine_post_activity_views_count \(count.value)", bundle: bundle)
        case .likes:
            return Text("divine_post_activity_likes_count \(count.value)", bundle: bundle)
        case .comments:
            return Text("divine_post_activity_comments_count \(count.value)", bundle: bundle)
        }
    }

    /// Reads the given parts as one label, counts with their plural forms.
    static func label(
        parts: [PostActivitySpokenPart],
        postedAt: Date,
        updatedAt: Date,
        bundle: Bundle
    ) -> Text {
        let pieces = parts.map { part -> Text in
            switch part {
            case .yourPost:
                return Text(LocalizedStringKey(PostActivityStrings.yourPost), bundle: bundle)
            case .headline(let headline):
                return headlineText(headline, postedAt: postedAt, bundle: bundle)
            case .count(let count):
                return countText(count, bundle: bundle)
            case .firstRunNote:
                return Text(LocalizedStringKey(PostActivityStrings.firstRunNote), bundle: bundle)
            case .updated:
                return Text("divine_post_activity_updated \(Text(updatedAt, style: .relative))", bundle: bundle)
            }
        }
        guard let first = pieces.first else { return Text("") }
        return pieces.dropFirst().reduce(first) { $0 + Text(", ") + $1 }
    }
}
