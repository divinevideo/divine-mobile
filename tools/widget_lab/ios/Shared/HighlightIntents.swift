import AppIntents
import WidgetKit

struct NextHighlight: AppIntent {
    static var title: LocalizedStringResource = "Next highlight"
    func perform() async throws -> some IntentResult {
        var state = LabStore.load()
        state.next()
        LabStore.save(state)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct LikeHighlight: AppIntent {
    static var title: LocalizedStringResource = "Like highlight locally"
    func perform() async throws -> some IntentResult {
        var state = LabStore.load()
        state.toggleLike()
        LabStore.save(state)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
