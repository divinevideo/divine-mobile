import AVKit
import SwiftUI
import WidgetKit

@main
struct WidgetLabApp: App {
    var body: some Scene { WindowGroup { LabDashboard() } }
}

struct LabDashboard: View {
    @State private var state = LabStore.load()
    @State private var player: AVPlayer?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Form {
                Section("Moment of joy") {
                    Text("An actual home-screen widget experiment. Add ‘Divine · Moment of joy’ from the widget gallery, then tap Next there.")
                    Text("Motion is experimental: compare the widget with this app’s ordinary video playback.")
                    Toggle("Try two-second frame transitions", isOn: $state.motion)
                        .onChange(of: state.motion) { _, _ in save() }
                    Button("Highlight another sample") { state.next(); save() }
                    Button("Watch selected sample") { play(state.index) }
                    if let player {
                        VideoPlayer(player: player).frame(height: 220)
                    }
                }
                Section("Create something") {
                    Text("Give an ordinary object a dramatic entrance.")
                    Link("Open Divine camera", destination: LabRoutes.camera)
                }
                Section("Local actions · no analytics uploaded") {
                    Text("Next taps: \(state.nextCount)")
                    Text("Like / unlike taps: \(state.likeCount)")
                    Text("Open taps: \(state.openCount)")
                    Text("Rendering the widget never counts as a view or an active user. Likes are demo state; nothing is published.")
                    Button("Reset experiment") { player?.pause(); state.reset(); save() }
                }
            }
            .navigationTitle("Divine Widget Lab")
            .tint(LabStyle.green)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { state = LabStore.load() } else { player?.pause() }
        }
        .onOpenURL { url in
            guard url.scheme == "divinewidgetlab", url.host == "watch",
                  let index = Int(url.lastPathComponent), (0..<LabState.clipCount).contains(index) else { return }
            state = LabStore.load()
            state.open()
            save()
            play(index)
        }
    }

    private func save() {
        LabStore.save(state)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func play(_ index: Int) {
        player?.pause()
        guard let url = Bundle.main.url(forResource: "clip_\(index)", withExtension: "mp4") else { return }
        player = AVPlayer(url: url)
        player?.play()
    }
}
