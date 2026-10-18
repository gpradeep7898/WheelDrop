import Foundation
import UniformTypeIdentifiers

// Shared predicate used by all image tools.
func isImage(_ url: URL) -> Bool {
    guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
    return type.conforms(to: .image)
}
