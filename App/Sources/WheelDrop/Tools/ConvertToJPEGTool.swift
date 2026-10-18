import Foundation
import UniformTypeIdentifiers

struct ConvertToJPEGTool: WheelTool {
    let id = "img.to-jpeg"
    let displayName = "JPEG"
    let sfSymbol = "photo.fill"

    func accepts(_ urls: [URL]) -> Bool {
        urls.allSatisfy { isImage($0) }
    }

    func execute(urls: [URL], outputDir: URL) async throws -> [URL] {
        try urls.map { url in
            let out = OutputWriter.uniqueURL(for: url, ext: "jpg", outputDir: outputDir)
            // flattenAlpha: transparent areas get white background (documented behaviour)
            try ImageConverter.convert(url, to: out, utType: .jpeg, flattenAlpha: true)
            return out
        }
    }
}
