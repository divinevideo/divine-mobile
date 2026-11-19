import ActivityKit
import SwiftUI
import WidgetKit

/// The Live Activity for a creator's just-published post: its first hour on
/// the Lock Screen and in the Dynamic Island.
@available(iOS 16.2, *)
struct PostLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PostActivityAttributes.self) { context in
            let display = PostActivityDisplay.make(state: context.state, isStale: context.isStale)
            PostActivityLockScreenView(
                attributes: context.attributes,
                display: display,
                state: context.state,
                thumbnail: thumbnail(for: context.attributes),
                bundle: .main
            )
            .activityBackgroundTint(PostActivityColors.deepGreen)
            .activitySystemActionForegroundColor(.white)
            .widgetURL(link(for: context.attributes))
        } dynamicIsland: { context in
            let display = PostActivityDisplay.make(state: context.state, isStale: context.isStale)
            let image = thumbnail(for: context.attributes)
            let postedAt = context.attributes.postedAt
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PostActivityThumbnailView(image: image, size: 44, cornerRadius: 9)
                }
                DynamicIslandExpandedRegion(.center) {
                    PostActivityHeadlineText(headline: display.headline, postedAt: postedAt, bundle: .main)
                        .font(PostActivityFonts.headline)
                        .foregroundStyle(.white)
                        // The bottom region reads the whole activity, headline included.
                        .accessibilityHidden(true)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    PostActivityExpandedBottomView(
                        display: display,
                        postedAt: postedAt,
                        updatedAt: context.state.updatedAt,
                        bundle: .main
                    )
                }
            } compactLeading: {
                PostActivityCompactLeadingView(
                    thumbnail: image,
                    display: display,
                    postedAt: postedAt,
                    bundle: .main
                )
            } compactTrailing: {
                PostActivityCompactTrailingView(
                    display: display,
                    updatedAt: context.state.updatedAt,
                    bundle: .main
                )
            } minimal: {
                PostActivityMinimalView(
                    thumbnail: image,
                    display: display,
                    postedAt: postedAt,
                    bundle: .main
                )
            }
            .widgetURL(link(for: context.attributes))
        }
    }

    private func link(for attributes: PostActivityAttributes) -> URL? {
        PostActivityLink.url(
            postEventId: attributes.postEventId,
            postCoordinate: attributes.postCoordinate
        )
    }

    private func thumbnail(for attributes: PostActivityAttributes) -> UIImage? {
        PostActivityThumbnail.load(
            fileName: attributes.thumbnailFileName,
            containerURL: FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: PostActivityThumbnail.appGroup
            )
        )
    }
}
