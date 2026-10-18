import Foundation
import CoreGraphics
import CoreImage
import ImageIO
import UniformTypeIdentifiers

// Shared image conversion utilities used by all image tools.
enum ImageConverter {

    // Convert a source image to a given UTType and save to destURL.
    // Uses a temp-then-move pattern. If flattenAlpha is true, composites onto white (for JPEG).
    static func convert(
        _ sourceURL: URL,
        to destURL: URL,
        utType: UTType,
        flattenAlpha: Bool,
        quality: CGFloat = 0.88
    ) throws {
        let (source, image) = try loadImage(from: sourceURL)
        let oriented = applyOrientation(image, source: source)
        let final = flattenAlpha ? flattened(oriented) : oriented

        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            data, utType.identifier as CFString, 1, nil
        ) else {
            throw ToolError.encoderUnavailable(utType.identifier)
        }
        CGImageDestinationAddImage(dest, final, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw ToolError.outputWriteFailed }

        try OutputWriter.write(data as Data, to: destURL)
    }

    // Load source + first frame CGImage.
    static func loadImage(from url: URL) throws -> (CGImageSource, CGImage) {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ToolError.unreadableSource(url)
        }
        guard let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            throw ToolError.unreadableSource(url)
        }
        return (src, img)
    }

    // Re-orient a CGImage using the EXIF orientation tag from its source.
    static func applyOrientation(_ image: CGImage, source: CGImageSource) -> CGImage {
        guard
            let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let raw = props[kCGImagePropertyOrientation] as? UInt32,
            let orient = CGImagePropertyOrientation(rawValue: raw),
            orient != .up
        else { return image }

        let ci = CIImage(cgImage: image).oriented(orient)
        let ctx = CIContext(options: [.useSoftwareRenderer: false])
        return ctx.createCGImage(ci, from: ci.extent) ?? image
    }

    // Composite the image onto a white background (removes transparency for JPEG).
    static func flattened(_ image: CGImage) -> CGImage {
        guard let ctx = CGContext(
            data: nil,
            width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return image }

        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return ctx.makeImage() ?? image
    }

    // Encode a CGImage to JPEG Data at the given quality level.
    static func jpegData(_ image: CGImage, quality: CGFloat) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            data, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(
            dest, image,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        return CGImageDestinationFinalize(dest) ? (data as Data) : nil
    }

    // Scale a CGImage by a fractional factor (0 < factor ≤ 1).
    static func scaled(_ image: CGImage, factor: CGFloat) -> CGImage {
        let w = max(1, Int(CGFloat(image.width) * factor))
        let h = max(1, Int(CGFloat(image.height) * factor))
        guard let ctx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return image }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage() ?? image
    }

    // Check if an image source has multiple frames (animated GIF/APNG).
    static func isAnimated(_ source: CGImageSource) -> Bool {
        return CGImageSourceGetCount(source) > 1
    }
}
