import SwiftUI
import WidgetKit

private let divineGreen = Color(red: 39 / 255, green: 197 / 255, blue: 139 / 255)
private let divineDeepGreen = Color(red: 0, green: 21 / 255, blue: 13 / 255)

struct CameraQuickActionEntry: TimelineEntry {
    let date: Date
}

struct CameraQuickActionTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> CameraQuickActionEntry {
        CameraQuickActionEntry(date: Date())
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (CameraQuickActionEntry) -> Void
    ) {
        completion(CameraQuickActionEntry(date: Date()))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<CameraQuickActionEntry>) -> Void
    ) {
        completion(Timeline(entries: [CameraQuickActionEntry(date: Date())], policy: .never))
    }
}

struct CameraQuickActionWidgetView: View {
    @Environment(\.widgetFamily) private var widgetFamily

    let entry: CameraQuickActionEntry

    @ViewBuilder
    var body: some View {
        switch widgetFamily {
        case .accessoryCircular:
            accessoryCircularBody
        default:
            systemSmallBody
        }
    }

    private var systemSmallBody: some View {
        Link(destination: divineCameraQuickActionURL) {
            VStack(spacing: 10) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(divineGreen)
                    .frame(width: 72, height: 72)

                Text("divine_quick_actions_camera_widget_name")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityLabel(Text("divine_quick_actions_camera_widget_open_camera"))
        .buttonStyle(.plain)
        .divineWidgetBackground(divineDeepGreen)
    }

    private var accessoryCircularBody: some View {
        ZStack {
            AccessoryWidgetBackground()

            Image(systemName: "camera.fill")
                .font(.system(size: 22, weight: .semibold))
                .widgetAccentable()
        }
        .widgetURL(divineCameraQuickActionURL)
        .accessibilityLabel(Text("divine_quick_actions_camera_widget_open_camera"))
    }
}

struct CameraQuickActionWidget: Widget {
    let kind = "CameraQuickActionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CameraQuickActionTimelineProvider()) { entry in
            CameraQuickActionWidgetView(entry: entry)
        }
        .configurationDisplayName("divine_quick_actions_camera_widget_name")
        .description("divine_quick_actions_camera_widget_description")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

/// A Control Center control that opens the camera. The Action Button lists
/// it under Controls, and it can replace a Lock Screen button.
@available(iOSApplicationExtension 18.0, *)
struct CameraQuickActionControl: ControlWidget {
    let kind = "CameraQuickActionControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: kind) {
            ControlWidgetButton(action: OpenDivineCameraIntent()) {
                Label("divine_camera_name", systemImage: "camera.fill")
            }
        }
        .displayName("divine_camera_name")
        .description("divine_camera_intent_description")
    }
}

@main
struct DivineWidgets: WidgetBundle {
    var body: some Widget {
        CameraQuickActionWidget()
        if #available(iOSApplicationExtension 16.2, *) {
            RecorderLiveActivity()
        }
        if #available(iOSApplicationExtension 18.0, *) {
            CameraQuickActionControl()
        }
    }
}

private extension View {
    @ViewBuilder
    func divineWidgetBackground(_ color: Color) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(color, for: .widget)
        } else {
            background(color)
        }
    }
}
