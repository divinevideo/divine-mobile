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
            .widgetURL(link(for: context.state))
        } dynamicIsland: { context in
            let display = PostActivityDisplay.make(state: context.state, isStale: context.isStale)
            let image = thumbnail(for: context.attributes)
            let startedAt = context.attributes.startedAt
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PostActivityThumbnailView(image: image, size: 44, cornerRadius: 9)
                }
                DynamicIslandExpandedRegion(.center) {
                    PostActivityHeadlineText(headline: display.headline, startedAt: startedAt, bundle: .main)
                        .font(PostActivityFonts.headline)
                        .foregroundStyle(.white)
                        // The bottom region reads the whole activity, headline included.
                        .accessibilityHidden(true)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    PostActivityExpandedBottomView(
                        display: display,
                        startedAt: startedAt,
                        updatedAt: context.state.updatedAt,
                        bundle: .main
                    )
                }
            } compactLeading: {
                PostActivityCompactLeadingView(
                    thumbnail: image,
                    display: display,
                    startedAt: startedAt,
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
                    startedAt: startedAt,
                    bundle: .main
                )
            }
            .widgetURL(link(for: context.state))
        }
    }

    private func link(for state: PostActivityContentState) -> URL? {
        PostActivityLink.url(
            postEventId: state.postEventId,
            postCoordinate: state.postCoordinate
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
