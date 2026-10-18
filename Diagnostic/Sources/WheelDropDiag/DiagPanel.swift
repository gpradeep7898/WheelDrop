import AppKit

// MARK: - DiagPanel

final class DiagPanel: NSObject {
    private var panel: NSPanel!
    private var dropView: DropTargetView!
    private var stateLabel: NSTextField!
    private var logView: NSTextView!
    private var logScrollView: NSScrollView!

    override init() {
        super.init()
        buildPanel()
        log("WheelDrop Diagnostic — Phase 0")
        log("Checking Accessibility permission...")
    }

    // MARK: - Build

    private func buildPanel() {
        let w: CGFloat = 460
        let h: CGFloat = 340
        let rect = NSRect(x: 0, y: 0, width: w, height: h)

        panel = NSPanel(
            contentRect: rect,
            styleMask: [.nonactivatingPanel, .titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "WheelDrop Diagnostic"
        panel.level = .floating
        panel.isFloatingPanel = true
        // Stay visible across spaces and full-screen apps.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false

        let content = NSView(frame: rect)
        content.autoresizingMask = [.width, .height]

        // ── Drop target zone ──────────────────────────────────
        dropView = DropTargetView(frame: NSRect(x: 0, y: h - 90, width: w, height: 90))
        dropView.autoresizingMask = [.width, .minYMargin]
        dropView.onLog = { [weak self] msg in self?.log(msg) }
        content.addSubview(dropView)

        // ── Separator ─────────────────────────────────────────
        let sep = NSBox(frame: NSRect(x: 0, y: h - 92, width: w, height: 2))
        sep.boxType = .separator
        sep.autoresizingMask = [.width, .minYMargin]
        content.addSubview(sep)

        // ── Drag state label ──────────────────────────────────
        stateLabel = NSTextField(frame: NSRect(x: 8, y: h - 110, width: w - 16, height: 16))
        stateLabel.autoresizingMask = [.width, .minYMargin]
        stateLabel.isEditable = false
        stateLabel.isBordered = false
        stateLabel.backgroundColor = .clear
        stateLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        stateLabel.textColor = .secondaryLabelColor
        stateLabel.stringValue = "state: idle"
        content.addSubview(stateLabel)

        // ── Log scroll + text view ────────────────────────────
        let logHeight = h - 114
        logScrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: w, height: logHeight))
        logScrollView.autoresizingMask = [.width, .height]
        logScrollView.hasVerticalScroller = true
        logScrollView.autohidesScrollers = true
        logScrollView.borderType = .noBorder

        let logContainerSize = logScrollView.contentSize
        logView = NSTextView(frame: NSRect(origin: .zero, size: logContainerSize))
        logView.minSize = NSSize(width: 0, height: logContainerSize.height)
        logView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        logView.isVerticallyResizable = true
        logView.isHorizontallyResizable = false
        logView.textContainer?.containerSize = NSSize(width: logContainerSize.width, height: CGFloat.greatestFiniteMagnitude)
        logView.textContainer?.widthTracksTextView = true
        logView.isEditable = false
        logView.isSelectable = true
        logView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        logView.backgroundColor = NSColor.textBackgroundColor
        logScrollView.documentView = logView

        content.addSubview(logScrollView)
        panel.contentView = content
    }

    // MARK: - Public interface

    func showAlways() {
        panel.center()
        panel.orderFrontRegardless()
    }

    /// Move the panel so the drop zone is near the pointer, without covering it.
    func showAtPointer(location: CGPoint) {
        // Convert Quartz coords (y-down, origin top-left of primary display)
        // to AppKit coords (y-up, origin bottom-left of primary display).
        guard let primary = NSScreen.screens.first else { return }
        let appKitY = primary.frame.height - location.y
        let cx = location.x
        let cy = appKitY

        let pSize = panel.frame.size
        var ox = cx - pSize.width / 2
        var oy = cy - pSize.height + 90 // put drop zone under pointer

        // Clamp to visible area of the screen containing the pointer.
        let targetScreen = NSScreen.screens.first(where: {
            $0.frame.contains(NSPoint(x: cx, y: cy))
        }) ?? primary
        let vf = targetScreen.visibleFrame
        ox = max(vf.minX, min(ox, vf.maxX - pSize.width))
        oy = max(vf.minY, min(oy, vf.maxY - pSize.height))

        panel.setFrameOrigin(NSPoint(x: ox, y: oy))
        panel.orderFrontRegardless()
    }

    func updateDragState(_ state: DragState) {
        let parts = [
            "btn:\(state.isButtonDown ? "↓" : "↑")",
            "drag:\(state.isDragging ? "yes" : "no")",
            "shift@down:\(state.shiftHeldAtMouseDown ? "yes" : "no")",
            "wheel:\(state.isWheelShown ? "shown" : "hidden")",
            "pos:(\(Int(state.lastPointer.x)),\(Int(state.lastPointer.y)))"
        ]
        stateLabel.stringValue = "state: " + parts.joined(separator: "  ")
    }

    func log(_ msg: String) {
        // Safe to call from any thread.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let ts = Self.timeFormatter.string(from: Date())
            let line = "[\(ts)] \(msg)\n"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.labelColor
            ]
            self.logView.textStorage?.append(NSAttributedString(string: line, attributes: attrs))
            self.logView.scrollToEndOfDocument(nil)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
}

// MARK: - DropTargetView

final class DropTargetView: NSView {
    var onLog: ((String) -> Void)?

    private var isHighlighted = false {
        didSet { needsDisplay = true }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        // Register for file URLs (modern) and legacy Finder filename type.
        registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType("NSFilenamesPboardType")
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        let bg: NSColor = isHighlighted
            ? .controlAccentColor.withAlphaComponent(0.25)
            : .windowBackgroundColor.withAlphaComponent(0.6)
        bg.setFill()
        bounds.fill()

        // Dashed border
        let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 4), xRadius: 6, yRadius: 6)
        border.lineWidth = 1.5
        let dash: [CGFloat] = [6, 4]
        border.setLineDash(dash, count: 2, phase: 0)
        (isHighlighted ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        border.stroke()

        let label = isHighlighted ? "Release to drop files here" : "▼  DROP FILES HERE  ▼"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: isHighlighted ? NSColor.controlAccentColor : NSColor.secondaryLabelColor
        ]
        let str = NSAttributedString(string: label, attributes: attrs)
        let sz = str.size()
        str.draw(at: NSPoint(x: (bounds.width - sz.width) / 2, y: (bounds.height - sz.height) / 2))
    }

    // MARK: - NSDraggingDestination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pb = sender.draggingPasteboard
        onLog?("draggingEntered  source=\(sourceDesc(sender))")
        onLog?("  pasteboard types: \(pb.types?.map(\.rawValue).joined(separator: ", ") ?? "none")")

        if let urls = fileURLs(from: pb), !urls.isEmpty {
            onLog?("  ✅ \(urls.count) file URL(s): \(urls.map(\.lastPathComponent).joined(separator: ", "))")
            isHighlighted = true
            return .copy
        } else {
            onLog?("  ⚠ No file URLs found (possible: promised files, non-file drag)")
            return []
        }
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return isHighlighted ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isHighlighted = false
        onLog?("draggingExited")
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return isHighlighted
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isHighlighted = false
        let pb = sender.draggingPasteboard
        guard let urls = fileURLs(from: pb), !urls.isEmpty else {
            onLog?("performDragOperation: no file URLs — rejecting")
            return false
        }
        onLog?("✅ DROP ACCEPTED — \(urls.count) file(s):")
        for url in urls {
            onLog?("   • \(url.path)")
        }
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        onLog?("concludeDragOperation — NSDraggingDestination lifecycle complete ✓")
    }

    // MARK: - Helpers

    private func fileURLs(from pb: NSPasteboard) -> [URL]? {
        pb.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL]
    }

    private func sourceDesc(_ info: NSDraggingInfo) -> String {
        guard let src = info.draggingSource else { return "external (Finder/other)" }
        return String(describing: type(of: src))
    }
}
