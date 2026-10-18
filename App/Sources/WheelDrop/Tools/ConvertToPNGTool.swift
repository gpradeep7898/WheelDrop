import Foundation
import UniformTypeIdentifiers

struct ConvertToPNGTool: WheelTool {
    let id = "img.to-png"
    let displayName = "PNG"
    let sfSymbol = "photo"

    func accepts(_ urls: [URL]) -> Bool {
        urls.allSatisfy { isImage($0) }
    }

    func execute(urls: [URL], outputDir: URL) async throws -> [URL] {
        try urls.map { url in
            let out = OutputWriter.uniqueURL(for: url, ext: "png", outputDir: outputDir)
            try ImageConverter.convert(url, to: out, utType: .png, flattenAlpha: false)
            return out
        }
    }
}
