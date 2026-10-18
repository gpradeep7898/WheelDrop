import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ConvertToWebPTool: WheelTool {
    let id = "img.to-webp"
    let displayName = "WebP"
    let sfSymbol = "w.square"

    private static let webpUTI = "public.webp"

    static let isAvailable: Bool = {
        let types = CGImageDestinationCopyTypeIdentifiers() as! [String]
        return types.contains(webpUTI)
    }()

    func accepts(_ urls: [URL]) -> Bool {
        Self.isAvailable && urls.allSatisfy { isImage($0) }
    }

    func execute(urls: [URL], outputDir: URL) async throws -> [URL] {
        guard Self.isAvailable,
              let webpType = UTType(Self.webpUTI)
        else { throw ToolError.encoderUnavailable("WebP") }

        return try urls.map { url in
            let out = OutputWriter.uniqueURL(for: url, ext: "webp", outputDir: outputDir)
            try ImageConverter.convert(url, to: out, utType: webpType, flattenAlpha: false)
            return out
        }
    }
}
