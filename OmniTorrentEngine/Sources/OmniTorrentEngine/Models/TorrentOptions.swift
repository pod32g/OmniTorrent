import Foundation

public enum CompletionAction: String, Codable, Sendable, CaseIterable {
    case doNothing
    case openFile
    case revealInFinder
}

public struct TorrentOptions: Codable, Sendable, Equatable {
    public var completionAction: CompletionAction
    public var moveToPath: String?
    public var hasCompleted: Bool

    public init(completionAction: CompletionAction = .doNothing, moveToPath: String? = nil, hasCompleted: Bool = false) {
        self.completionAction = completionAction
        self.moveToPath = moveToPath
        self.hasCompleted = hasCompleted
    }
}
