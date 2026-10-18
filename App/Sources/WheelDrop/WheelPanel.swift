import AppKit
import UniformTypeIdentifiers

// MARK: - WheelPanel

final class WheelPanel: NSPanel {
    private(set) var wheelView: WheelView

    var onDrop: (([URL], any WheelTool) -> Void)? {
        get { wheelView.onDrop }
        set { wheelView.onDrop = newValue }
    }

    init() {
        let side: CGFloat = 292
        let rect = NSRect(x: 0, y: 0, width: side, height: side)

        wheelView = WheelView(frame: rect)

        super.init(
            contentRect: rect,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        isFloatingPanel = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        hasShadow = true

        // Visual effect (dark blurred circle) behind the wheel segments
        let effect = NSVisualEffectView(frame: rect)
        effect.material = .hudWindow
        effect.state = .active
        effect.blendingMode = .behindWindow
        effect.wantsLayer = true
        effect.layer?.cornerRadius = side / 2
        effect.layer?.masksToBounds = true

        wheelView.autoresizingMask = [.width, .height]
        effect.addSubview(wheelView)
        contentView = effect
    }

    // MARK: - Show / hide

    func show(at cgPoint: CGPoint) {
        // Convert Quartz coordinates (y-down) to AppKit (y-up, primary screen origin).
        guard let primary = NSScreen.screens.first else { return }
        let appKitY = primary.frame.height - cgPoint.y

        let size = frame.size
        var ox = cgPoint.x - size.width / 2
        var oy = appKitY  - size.height / 2

        // Keep wheel on-screen, using the screen the pointer is actually on.
        let pointerNSPoint = NSPoint(x: cgPoint.x, y: appKitY)
        let screen = NSScreen.screens.first(where: { $0.frame.contains(pointerNSPoint) }) ?? primary
        let vf = screen.visibleFrame
        ox = max(vf.minX, min(ox, vf.maxX - size.width))
        oy = max(vf.minY, min(oy, vf.maxY - size.height))

        setFrameOrigin(NSPoint(x: ox, y: oy))
        wheelView.reset(keepTools: false)

        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        alphaValue = reduce ? 1 : 0
        orderFrontRegardless()

        if !reduce {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.12
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.animator().alphaValue = 1
            }
        }
    }

    func hide() {
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if reduce {
            orderOut(nil)
            wheelView.reset(keepTools: false)
        } else {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.08
                self.animator().alphaValue = 0
            }, completionHandler: {
                self.orderOut(nil)
                self.wheelView.reset(keepTools: false)
            })
        }
    }
}

// MARK: - WheelView

final class WheelView: NSView {
    var onDrop: (([URL], any WheelTool) -> Void)?

    private var tools: [any WheelTool] = []
    private var hoveredIndex: Int? = nil
    private var pendingURLs: [URL]? = nil

    // Geometry
    private let outerR: CGFloat = 132
    private let innerR: CGFloat = 48
    private let gapDeg: CGFloat = 1.8

    // Colors
    private let segmentNormal   = NSColor.white.withAlphaComponent(0.07)
    private let segmentHovered  = NSColor(calibratedRed: 1.0, green: 0.41, blue: 0.0, alpha: 0.92)
    private let segmentInactive = NSColor.white.withAlphaComponent(0.03)
    private let accentOrange    = NSColor(calibratedRed: 1.0, green: 0.41, blue: 0.0, alpha: 1.0)

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType("NSFilenamesPboardType")
        ])
        tools = ToolRegistry.shared.allTools
    }
    required init?(coder: NSCoder) { fatalError() }

    func reset(keepTools: Bool) {
        hoveredIndex = nil
        pendingURLs = nil
        if !keepTools { tools = ToolRegistry.shared.allTools }
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard !tools.isEmpty else { return }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)

        for (i, tool) in tools.enumerated() {
            let active = pendingURLs.map { tool.accepts($0) } ?? true
            let hovered = hoveredIndex == i

            let path = segmentPath(index: i, count: tools.count, center: center)

            if hovered {
                segmentHovered.setFill()
            } else if active {
                segmentNormal.setFill()
            } else {
                segmentInactive.setFill()
            }
            path.fill()

            // Subtle separator line
            NSColor.white.withAlphaComponent(0.06).setStroke()
            path.lineWidth = 0.5
            path.stroke()

            drawContent(tool: tool, index: i, count: tools.count, center: center,
                        hovered: hovered, active: active)
        }

        // Centre hint when no drag has entered yet
        if pendingURLs == nil {
            let hint = NSAttributedString(string: "drop files", attributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(0.30)
            ])
            let sz = hint.size()
            hint.draw(at: NSPoint(x: center.x - sz.width/2, y: center.y - sz.height/2))
        }
    }

    private func drawContent(tool: any WheelTool, index: Int, count: Int,
                             center: CGPoint, hovered: Bool, active: Bool) {
        let span    = 360.0 / Double(count)
        let midDeg  = 90.0 - (Double(index) + 0.5) * span
        let midRad  = midDeg * .pi / 180.0
        let midR    = (outerR + innerR) / 2 + 4

        let cx = center.x + CGFloat(cos(midRad)) * midR
        let cy = center.y + CGFloat(sin(midRad)) * midR

        let alpha: CGFloat = active ? (hovered ? 1.0 : 0.85) : 0.30
        let tint = NSColor.white.withAlphaComponent(alpha)

        // SF Symbol icon
        let cfg = NSImage.SymbolConfiguration(pointSize: 17, weight: hovered ? .semibold : .regular)
        if let img = NSImage(systemSymbolName: tool.sfSymbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg) {
            img.isTemplate = true
            tint.set()
            let iSize: CGFloat = 20
            img.draw(
                in: NSRect(x: cx - iSize/2, y: cy + 2, width: iSize, height: iSize),
                from: .zero, operation: .sourceOver, fraction: 1
            )
        }

        // Label
        let labelStr = NSAttributedString(string: tool.displayName, attributes: [
            .font: NSFont.systemFont(ofSize: 9, weight: hovered ? .semibold : .regular),
            .foregroundColor: tint
        ])
        let lsz = labelStr.size()
        labelStr.draw(at: NSPoint(x: cx - lsz.width/2, y: cy - lsz.height - 2))
    }

    // MARK: - Geometry helpers

    private func segmentPath(index: Int, count: Int, center: CGPoint) -> NSBezierPath {
        let n     = CGFloat(count)
        let span  = 360.0 / n
        let start = 90.0 - CGFloat(index)     * span - gapDeg
        let end   = 90.0 - CGFloat(index + 1) * span + gapDeg

        let path = NSBezierPath()
        path.appendArc(withCenter: center, radius: outerR,
                       startAngle: start, endAngle: end, clockwise: true)
        path.appendArc(withCenter: center, radius: innerR,
                       startAngle: end, endAngle: start, clockwise: false)
        path.close()
        return path
    }

    private func segmentIndex(at point: NSPoint) -> Int? {
        guard !tools.isEmpty else { return nil }
        let c  = NSPoint(x: bounds.midX, y: bounds.midY)
        let dx = point.x - c.x
        let dy = point.y - c.y
        let d  = (dx*dx + dy*dy).squareRoot()
        guard d >= innerR && d <= outerR else { return nil }

        var angleDeg = atan2(Double(dy), Double(dx)) * 180.0 / .pi
        var cwFromTop = 90.0 - angleDeg
        if cwFromTop < 0 { cwFromTop += 360 }
        cwFromTop = cwFromTop.truncatingRemainder(dividingBy: 360)

        let idx = Int(cwFromTop * Double(tools.count) / 360.0)
        return min(max(idx, 0), tools.count - 1)
    }

    // MARK: - NSDraggingDestination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let urls = fileURLs(from: sender), !urls.isEmpty else { return [] }
        pendingURLs = urls
        tools = ToolRegistry.shared.compatible(with: urls)
        needsDisplay = true
        return updateHover(at: sender.draggingLocation)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return updateHover(at: sender.draggingLocation)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        hoveredIndex = nil
        pendingURLs = nil
        tools = ToolRegistry.shared.allTools
        needsDisplay = true
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        hoveredIndex != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let idx = hoveredIndex,
              idx < tools.count,
              let urls = pendingURLs ?? fileURLs(from: sender) else { return false }
        let tool = tools[idx]
        onDrop?(urls, tool)
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        hoveredIndex = nil
        needsDisplay = true
    }

    // MARK: - Helpers

    private func updateHover(at point: NSPoint) -> NSDragOperation {
        let newIdx = segmentIndex(at: point)
        if newIdx != hoveredIndex {
            hoveredIndex = newIdx
            needsDisplay = true
        }
        // Only allow drop on segments that accept the current files
        if let idx = hoveredIndex, let urls = pendingURLs, tools[idx].accepts(urls) {
            return .copy
        }
        return hoveredIndex != nil ? .copy : []
    }

    private func fileURLs(from info: NSDraggingInfo) -> [URL]? {
        info.draggingPasteboard
            .readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
            as? [URL]
    }
}
