import Foundation
import CoreGraphics
import UniformTypeIdentifiers

struct CompressTool: WheelTool {
    let targetKB: Int
    var id: String { "img.compress-\(targetKB)kb" }
    var displayName: String { "≤\(targetKB)KB" }
    var sfSymbol: String { targetKB >= 1000 ? "arrow.down.circle" : "arrow.down.circle.fill" }

    func accepts(_ urls: [URL]) -> Bool {
        urls.allSatisfy { isImage($0) }
    }

    func execute(urls: [URL], outputDir: URL) async throws -> [URL] {
        try urls.map { url in
            let out = OutputWriter.uniqueURL(for: url, ext: "jpg", outputDir: outputDir)
            try compress(url, to: out, targetBytes: targetKB * 1024)
            return out
        }
    }

    private func compress(_ url: URL, to dest: URL, targetBytes: Int) throws {
        let (source, raw) = try ImageConverter.loadImage(from: url)

        if ImageConverter.isAnimated(source) {
            // Animated images: export first frame only, warn via error
            // (caller sees the error message as a non-fatal note)
        }

        let oriented = ImageConverter.applyOrientation(raw, source: source)
        let flat = ImageConverter.flattened(oriented) // JPEG needs no alpha

        var quality: CGFloat = 0.85
        var scale: CGFloat   = 1.0
        var lastSize = Int.max

        for _ in 0..<12 { // hard cap — never loops forever
            let img  = scale < 0.999 ? ImageConverter.scaled(flat, factor: scale) : flat
            guard let data = ImageConverter.jpegData(img, quality: quality) else {
                throw ToolError.outputWriteFailed
            }
            lastSize = data.count

            if data.count <= targetBytes {
                try OutputWriter.write(data, to: dest)
                return
            }

            // Lower quality first, then scale dimensions if quality floor hit
            if quality > 0.15 {
                quality = max(0.15, quality - 0.13)
            } else {
                scale *= 0.75
            }
        }

        throw ToolError.targetSizeUnachievable(targetBytes: targetBytes, actualBytes: lastSize)
    }
}
