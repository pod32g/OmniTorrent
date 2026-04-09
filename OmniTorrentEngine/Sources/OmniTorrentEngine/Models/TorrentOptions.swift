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
    public var tag: TorrentTag

    public init(completionAction: CompletionAction = .doNothing, moveToPath: String? = nil, hasCompleted: Bool = false, tag: TorrentTag = .none) {
        self.completionAction = completionAction
        self.moveToPath = moveToPath
        self.hasCompleted = hasCompleted
        self.tag = tag
    }
}
