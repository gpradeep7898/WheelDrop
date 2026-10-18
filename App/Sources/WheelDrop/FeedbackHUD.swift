import AppKit

// Lightweight toast — appears at the bottom-centre of the screen, auto-dismisses.
enum FeedbackHUD {
    static func show(_ message: String, isError: Bool = false) {
        DispatchQueue.main.async {
            let panel = makePanel(message: message, isError: isError)

            guard let screen = NSScreen.main else { return }
            let px = screen.visibleFrame.midX - panel.frame.width / 2
            let py = screen.visibleFrame.minY + 36
            panel.setFrameOrigin(NSPoint(x: px, y: py))

            panel.alphaValue = 0
            panel.orderFrontRegardless()

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                panel.animator().alphaValue = 1
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = 0.28
                    panel.animator().alphaValue = 0
                }, completionHandler: { panel.orderOut(nil) })
            }
        }
    }

    private static func makePanel(message: String, isError: Bool) -> NSPanel {
        let padding: CGFloat = 14
        let label = NSTextField(wrappingLabelWithString: message)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.sizeToFit()

        let w = max(180, label.frame.width + padding * 2)
        let h = label.frame.height + padding * 2
        label.frame = NSRect(x: padding, y: padding, width: label.frame.width, height: label.frame.height)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: w, height: h),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.isReleasedWhenClosed = false
        panel.hasShadow = true

        let bg = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        bg.wantsLayer = true
        bg.layer?.backgroundColor = isError
            ? NSColor(calibratedRed: 0.65, green: 0.10, blue: 0.10, alpha: 0.96).cgColor
            : NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.10, alpha: 0.94).cgColor
        bg.layer?.cornerRadius = 10
        bg.addSubview(label)
        panel.contentView = bg
        return panel
    }
}
