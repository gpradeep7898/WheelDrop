import Foundation

final class ToolRegistry {
    static let shared = ToolRegistry()

    private(set) var allTools: [any WheelTool]

    private init() {
        allTools = [
            ConvertHEICToJPEGTool(),
            ConvertToPNGTool(),
            ConvertToJPEGTool(),
            ConvertToHEICTool(),
            ConvertToWebPTool(),
            CompressTool(targetKB: 1024),
            CompressTool(targetKB: 500),
            CopyPathTool(),
            OpenTerminalTool(),
        ]
    }

    // Returns only tools that every file in the selection satisfies.
    func compatible(with urls: [URL]) -> [any WheelTool] {
        guard !urls.isEmpty else { return [] }
        return allTools.filter { tool in urls.allSatisfy { tool.accepts([$0]) } }
    }
}
