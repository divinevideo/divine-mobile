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
                    .font(.headline)
                    Spacer(minLength: 4)
                    PostActivityTimeText(
                        display: display,
                        state: state,
                        postedAt: attributes.postedAt,
                        bundle: bundle
                    )
                    .font(.caption)
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
                display: display,
                postedAt: attributes.postedAt,
                bundle: bundle
            )
        )
    }
}

struct PostActivityCompactLeadingView: View {
    let thumbnail: UIImage?

    var body: some View {
        PostActivityThumbnailView(image: thumbnail, size: 22, cornerRadius: 5)
    }
}

struct PostActivityCompactTrailingView: View {
    let display: PostActivityDisplay
    let bundle: Bundle

    var body: some View {
        if let count = display.compactCount {
            PostActivityCountLabel(count: count)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(PostActivityColors.green)
                .frame(maxWidth: 52)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(PostActivityAccessibility.countText(count, bundle: bundle))
        }
    }
}

struct PostActivityMinimalView: View {
    let thumbnail: UIImage?

    var body: some View {
        PostActivityThumbnailView(image: thumbnail, size: 20, cornerRadius: 10)
    }
}

struct PostActivityExpandedBottomView: View {
    let display: PostActivityDisplay
    let bundle: Bundle

    var body: some View {
        PostActivityDetailLine(display: display, bundle: bundle)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Pieces

struct PostActivityHeadlineText: View {
    let headline: PostActivityHeadline
    let postedAt: Date
    let bundle: Bundle

    var body: some View {
        PostActivityAccessibility.headlineText(headline, postedAt: postedAt, bundle: bundle)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
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
            .font(.subheadline.weight(.semibold))
        } else if display.showsFirstRunNote {
            Text(LocalizedStringKey(PostActivityStrings.firstRunNote), bundle: bundle)
                .font(.caption)
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

    /// One label for the whole activity: whose post, the headline, then each
    /// known count read with its plural form.
    static func label(display: PostActivityDisplay, postedAt: Date, bundle: Bundle) -> Text {
        var label = Text(LocalizedStringKey(PostActivityStrings.yourPost), bundle: bundle)
            + Text(", ")
            + headlineText(display.headline, postedAt: postedAt, bundle: bundle)
        for count in display.counts {
            label = label + Text(", ") + countText(count, bundle: bundle)
        }
        if display.showsFirstRunNote {
            label = label + Text(". ")
                + Text(LocalizedStringKey(PostActivityStrings.firstRunNote), bundle: bundle)
        }
        return label
    }
}
