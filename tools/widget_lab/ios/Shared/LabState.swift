import Foundation

struct LabState: Codable, Equatable {
    static let clipCount = 3
    var index = 0
    var liked: Set<Int> = []
    var nextCount = 0
    var likeCount = 0
    var openCount = 0
    var revision = 0
    var motion = true

    var isLiked: Bool { liked.contains(index) }

    mutating func next() {
        index = (index + 1) % Self.clipCount
        nextCount += 1
        revision += 1
    }

    mutating func toggleLike() {
        if isLiked { liked.remove(index) } else { liked.insert(index) }
        likeCount += 1
    }

    mutating func open() { openCount += 1 }

    mutating func reset() {
        let nextRevision = revision + 1
        self = LabState()
        revision = nextRevision
    }
}
