import Foundation

enum OutputWriter {
    // Returns a guaranteed-unique URL that doesn't exist yet.
    // Pattern: name-converted.ext → name-converted-2.ext → ... → name-converted-UUID.ext
    static func uniqueURL(for source: URL, ext: String, outputDir: URL) -> URL {
        let base = source.deletingPathExtension().lastPathComponent
        let fm = FileManager.default

        let first = outputDir.appendingPathComponent("\(base)-converted.\(ext)")
        if !fm.fileExists(atPath: first.path) { return first }

        for n in 2...999 {
            let candidate = outputDir.appendingPathComponent("\(base)-converted-\(n).\(ext)")
            if !fm.fileExists(atPath: candidate.path) { return candidate }
        }

        let tag = UUID().uuidString.prefix(8)
        return outputDir.appendingPathComponent("\(base)-converted-\(tag).\(ext)")
    }

    // Write data to a temp path then atomically move into place.
    // Cleans up the temp file if move fails.
    static func write(_ data: Data, to dest: URL) throws {
        let tmp = dest.appendingPathExtension("wdtmp")
        do {
            try data.write(to: tmp, options: .atomic)
            try FileManager.default.moveItem(at: tmp, to: dest)
        } catch {
            try? FileManager.default.removeItem(at: tmp)
            throw error
        }
    }

    // Suitable output directory for a source URL.
    // Prefers the source's own folder if writable; falls back to Downloads.
    static func outputDir(for source: URL) -> URL {
        let dir = source.deletingLastPathComponent()
        if FileManager.default.isWritableFile(atPath: dir.path) { return dir }
        return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
    }
}
