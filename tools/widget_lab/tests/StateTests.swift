import Foundation

@main
struct StateTests {
    static func main() throws {
        precondition(LabRoutes.camera.absoluteString == "divine://quick-action/camera")
        var state = LabState()
        state.next()
        precondition(state.index == 1 && state.nextCount == 1)
        state.toggleLike()
        precondition(state.isLiked && state.likeCount == 1)
        state.next()
        precondition(!state.isLiked)
        state.next()
        precondition(state.index == 0)
        state.next()
        precondition(state.isLiked)
        state.toggleLike()
        precondition(!state.isLiked && state.likeCount == 2)
        state.open()
        precondition(state.openCount == 1)
        let restored = try JSONDecoder().decode(LabState.self, from: JSONEncoder().encode(state))
        precondition(restored == state)
        let previousRevision = state.revision
        state.reset()
        precondition(state.index == 0 && !state.isLiked && state.nextCount == 0)
        precondition(state.revision > previousRevision)
        print("Swift state: navigation, per-clip likes, counters, persistence passed")
    }
}
