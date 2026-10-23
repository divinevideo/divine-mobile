import Foundation

enum LabStore {
    static let group = "group.video.divine.widgetlab"
    private static let key = "widgetLabState"

    static func load() -> LabState {
        guard let data = UserDefaults(suiteName: group)?.data(forKey: key),
              let state = try? JSONDecoder().decode(LabState.self, from: data),
              (0..<LabState.clipCount).contains(state.index) else { return LabState() }
        return state
    }

    static func save(_ state: LabState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults(suiteName: group)?.set(data, forKey: key)
    }
}
