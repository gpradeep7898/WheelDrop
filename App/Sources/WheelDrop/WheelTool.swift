import Foundation
import UniformTypeIdentifiers

// Every conversion action conforms to this. Adding a tool = one file + one registry line.
protocol WheelTool {
    var id: String { get }
    var displayName: String { get }
    var sfSymbol: String { get }
    // User-facing message after a successful run (override for non-file outputs like clipboard).
    var completionVerb: String { get }
    func accepts(_ urls: [URL]) -> Bool
    func execute(urls: [URL], outputDir: URL) async throws -> [URL]
}

extension WheelTool {
    var completionVerb: String { "Saved" }
}

enum ToolError: LocalizedError {
    case unreadableSource(URL)
    case encoderUnavailable(String)
    case targetSizeUnachievable(targetBytes: Int, actualBytes: Int)
    case outputWriteFailed
    case dependencyMissing(String)

    var errorDescription: String? {
        switch self {
        case .unreadableSource(let u):
            return "Cannot read \(u.lastPathComponent)"
        case .encoderUnavailable(let f):
            return "\(f) encoding not supported on this OS version"
        case .targetSizeUnachievable(let t, let a):
            let tk = t / 1024, ak = a / 1024
            return "Target \(tk) KB unreachable — smallest achieved: \(ak) KB"
        case .outputWriteFailed:
            return "Failed to write output file"
        case .dependencyMissing(let d):
            return "\(d) not found — install it or set its path in Settings"
        }
    }
}
