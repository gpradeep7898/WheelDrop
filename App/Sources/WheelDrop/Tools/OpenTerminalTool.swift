import AppKit
import Foundation

struct OpenTerminalTool: WheelTool {
    let id = "file.open-terminal"
    let displayName = "Terminal"
    let sfSymbol = "terminal"
    let completionVerb = "Opened"

    func accepts(_ urls: [URL]) -> Bool { !urls.isEmpty }

    func execute(urls: [URL], outputDir: URL) async throws -> [URL] {
        // Deduplicate folders, open Terminal at each.
        let dirs = Array(Set(urls.map { $0.deletingLastPathComponent() }))

        await MainActor.run {
            // Use NSWorkspace with a URL array — no shell string, no injection risk.
            guard let terminalURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: "com.apple.Terminal"
            ) else { return }

            for dir in dirs {
                NSWorkspace.shared.open(
                    [dir],
                    withApplicationAt: terminalURL,
                    configuration: NSWorkspace.OpenConfiguration()
                )
            }
        }
        return []
    }
}
