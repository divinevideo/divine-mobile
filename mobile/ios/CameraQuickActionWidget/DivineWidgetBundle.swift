import SwiftUI
import WidgetKit

/// Everything the widget extension offers: the camera quick action, and on
/// iOS 16.2 and later the new-post Live Activity.
@main
struct DivineWidgetBundle: WidgetBundle {
    var body: some Widget {
        CameraQuickActionWidget()
        if #available(iOS 16.2, *) {
            PostLiveActivityWidget()
        }
    }
}
