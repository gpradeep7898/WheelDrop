import AppKit

// Connects EventObserver → WheelPanel → Tool execution.
final class WheelController {
    private let panel = WheelPanel()
    private var observer: EventObserver?

    init() {
        panel.onDrop = { [weak self] urls, tool in
            self?.run(tool, on: urls)
        }
    }

    @discardableResult
    func startObserving() -> Bool {
        let obs = EventObserver(
            onShow: { [weak self] location in self?.panel.show(at: location) },
            onHide: { [weak self] _ in self?.panel.hide() }
        )
        self.observer = obs
        return obs.start()
    }

    // MARK: - Execution

    private func run(_ tool: any WheelTool, on urls: [URL]) {
        panel.hide()

        Task.detached(priority: .userInitiated) {
            do {
                // Per-file output directory — prefers the file's own folder if writable.
                let dirs = Dictionary(grouping: urls) { OutputWriter.outputDir(for: $0) }
                var outputs: [URL] = []

                for (dir, group) in dirs {
                    let result = try await tool.execute(urls: group, outputDir: dir)
                    outputs.append(contentsOf: result)
                }

                await MainActor.run {
                    let noun = outputs.isEmpty ? "" : " — \(outputs.count) file(s)"
                    FeedbackHUD.show("✅ \(tool.completionVerb)\(noun)")
                    if !outputs.isEmpty {
                        // Reveal the first output in Finder.
                        NSWorkspace.shared.activateFileViewerSelecting(outputs)
                    }
                }
            } catch {
                await MainActor.run {
                    FeedbackHUD.show("❌ \(tool.displayName): \(error.localizedDescription)", isError: true)
                }
            }
        }
    }
}
