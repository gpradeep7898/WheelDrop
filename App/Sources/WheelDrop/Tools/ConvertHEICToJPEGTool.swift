import Foundation
import UniformTypeIdentifiers

struct ConvertHEICToJPEGTool: WheelTool {
    let id = "img.heic-to-jpeg"
    let displayName = "HEIC→JPG"
    let sfSymbol = "arrow.right.square"

    func accepts(_ urls: [URL]) -> Bool {
        // Only shows active when ALL selected files are HEIC/HEIF.
        urls.allSatisfy { url in
            guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
            return type.conforms(to: .heic) || type == UTType("public.heif")
        }
    }

    func execute(urls: [URL], outputDir: URL) async throws -> [URL] {
        try urls.map { url in
            let out = OutputWriter.uniqueURL(for: url, ext: "jpg", outputDir: outputDir)
            // HEIC can have transparency in some encoders; flatten to white for JPEG.
            try ImageConverter.convert(url, to: out, utType: .jpeg, flattenAlpha: true)
            return out
        }
    }
}
