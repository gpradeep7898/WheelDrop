import AppKit
import Foundation

struct CopyPathTool: WheelTool {
    let id = "file.copy-path"
    let displayName = "Copy Path"
    let sfSymbol = "doc.on.clipboard"
    let completionVerb = "Copied"

    func accepts(_ urls: [URL]) -> Bool { !urls.isEmpty }

    func execute(urls: [URL], outputDir: URL) async throws -> [URL] {
        // Shell-quote each path safely — never interpolate raw paths into shell strings.
        let quoted = urls.map { shellQuote($0.path) }.joined(separator: "\n")
        await MainActor.run {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(quoted, forType: .string)
        }
        return [] // clipboard action — no output files
    }

    private func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
