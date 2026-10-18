import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ConvertToHEICTool: WheelTool {
    let id = "img.to-heic"
    let displayName = "HEIC"
    let sfSymbol = "h.square"

    // Checked once at startup — if the encoder isn't in the SDK, the tool silently
    // declines all inputs via accepts(), greying itself out on the wheel.
    static let isAvailable: Bool = {
        let types = CGImageDestinationCopyTypeIdentifiers() as! [String]
        return types.contains(UTType.heic.identifier)
    }()

    func accepts(_ urls: [URL]) -> Bool {
        Self.isAvailable && urls.allSatisfy { isImage($0) }
    }

    func execute(urls: [URL], outputDir: URL) async throws -> [URL] {
        guard Self.isAvailable else { throw ToolError.encoderUnavailable("HEIC") }
        return try urls.map { url in
            let out = OutputWriter.uniqueURL(for: url, ext: "heic", outputDir: outputDir)
            try ImageConverter.convert(url, to: out, utType: .heic, flattenAlpha: false)
            return out
        }
    }
}
