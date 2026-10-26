import AppIntents
import SwiftUI
import WidgetKit

struct HighlightEntry: TimelineEntry {
    let date: Date
    let state: LabState
}

struct HighlightProvider: TimelineProvider {
    func placeholder(in context: Context) -> HighlightEntry {
        HighlightEntry(date: .now, state: LabState())
    }

    func getSnapshot(in context: Context, completion: @escaping (HighlightEntry) -> Void) {
        completion(HighlightEntry(date: .now, state: LabStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HighlightEntry>) -> Void) {
        completion(Timeline(entries: [HighlightEntry(date: .now, state: LabStore.load())], policy: .never))
    }
}

struct HighlightCard: View {
    let entry: HighlightEntry
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.widgetFamily) private var family

    private var compact: Bool { family == .systemSmall }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                ZStack {
                    if entry.state.motion && !reduceMotion {
                        ForEach(0..<LabStyle.frameCount, id: \.self) { frame in
                            Image(LabStyle.frame(entry.state.index, frame))
                                .resizable().scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                                .id("\(entry.state.revision)-\(frame)")
                                .transition(.asymmetric(
                                    insertion: .opacity.animation(.linear(duration: 0.01)
                                        .delay(Double(frame) * LabStyle.frameDuration)),
                                    removal: .opacity.animation(.linear(duration: 0.01))
                                ))
                        }
                    } else {
                        Image(LabStyle.frame(entry.state.index, 0))
                            .resizable().scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    }
                }
                .animation(.linear(duration: LabStyle.previewDuration), value: entry.state.revision)
                .accessibilityLabel("Sample video \(entry.state.index + 1)")

                VStack {
                    HStack {
                        Text("Divine")
                            .font(.system(size: compact ? 13 : 16, weight: .bold))
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .background(.black.opacity(0.5), in: Capsule())
                        Spacer()
                        Link(destination: URL(string: "divinewidgetlab://watch/\(entry.state.index)")!) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 15, weight: .bold))
                                .frame(width: 44, height: 44)
                                .background(.black.opacity(0.5), in: Circle())
                        }
                        .accessibilityLabel("Open")
                    }
                    .padding(compact ? 8 : 12)
                    Spacer(minLength: 0)
                    VStack(alignment: .leading, spacing: 0) {
                        if !compact {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(LabStyle.titles[entry.state.index])
                                    .font(.system(size: 20, weight: .semibold)).lineLimit(2)
                                Text("6 seconds. All human.").font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .padding(.horizontal, 16).padding(.top, 14)
                        }
                        HStack(spacing: 0) {
                            Button(intent: LikeHighlight()) {
                                Image(systemName: entry.state.isLiked ? "heart.fill" : "heart")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(entry.state.isLiked ? LabStyle.green : .white)
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityLabel(entry.state.isLiked ? "Liked" : "Like")
                            Spacer(minLength: 0)
                            Link(destination: LabRoutes.camera) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.black)
                                    .frame(width: 44, height: 44)
                                    .background(LabStyle.green, in: Circle())
                            }
                            .accessibilityLabel("Open Divine camera")
                            Spacer(minLength: 0)
                            Button(intent: NextHighlight()) {
                                HStack(spacing: 6) {
                                    if !compact { Text("Next").font(.system(size: 14, weight: .semibold)) }
                                    Image(systemName: "forward.end.fill")
                                        .font(.system(size: 18, weight: .medium))
                                }
                                .frame(minWidth: 44, minHeight: 44)
                            }
                            .accessibilityLabel("Next")
                        }
                        .padding(.horizontal, compact ? 10 : 16)
                    }
                    .background(.black.opacity(0.65))
                }
                .foregroundStyle(.white)
                .buttonStyle(.plain)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .containerBackground(.black, for: .widget)
    }
}

@main
struct HighlightWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DivineHighlightLab", provider: HighlightProvider()) { entry in
            HighlightCard(entry: entry)
        }
        .configurationDisplayName("Divine · Moment of joy")
        .description("Prototype: Next tries a two-second frame sequence. Likes stay on this device.")
        .supportedFamilies([.systemSmall, .systemLarge])
        .contentMarginsDisabled()
    }
}
