public enum FilePriority: Sendable, Equatable {
    case skip, normal, high

    public var ltValue: Int {
        switch self { case .skip: return 0; case .normal: return 4; case .high: return 7 }
    }

    public static func from(ltValue: Int) -> FilePriority {
        switch ltValue { case 0: return .skip; case 7: return .high; default: return .normal }
    }
}

public struct FileEntry: Sendable, Identifiable {
    public let id: Int
    public var path: String
    public var size: Int64
    public var progress: Float
    public var priority: FilePriority

    public init(id: Int, path: String, size: Int64, progress: Float = 0, priority: FilePriority = .normal) {
        self.id = id; self.path = path; self.size = size; self.progress = progress; self.priority = priority
    }
}
