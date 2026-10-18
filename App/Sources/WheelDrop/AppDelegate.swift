import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var wheelController: WheelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        checkPermission()
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem?.button {
            // Use the bundled icon image; fall back to text if missing.
            let iconURL = Bundle.main.resourceURL?.appendingPathComponent("StatusIcon.png")
            if let url = iconURL, let img = NSImage(contentsOf: url) {
                img.isTemplate = true
                img.size = NSSize(width: 18, height: 18)
                btn.image = img
            } else {
                btn.title = "⊘"
            }
        }
        setIcon(ready: false)

        let menu = NSMenu()
        menu.addItem(withTitle: "WheelDrop", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Drag files + tap Shift to convert", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        statusItem?.menu = menu
    }

    private func setIcon(ready: Bool) {
        // Tint the template icon: full opacity when active, dimmed when waiting for permission.
        if let btn = statusItem?.button, btn.image != nil {
            btn.alphaValue = ready ? 1.0 : 0.4
        } else {
            statusItem?.button?.title = ready ? "◉" : "⊘"
        }
        statusItem?.button?.toolTip = ready
            ? "WheelDrop — drag files, tap Shift to open wheel"
            : "WheelDrop — needs Accessibility permission"
    }

    // MARK: - Permission

    private func checkPermission() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(opts) {
            startWheel()
        } else {
            pollForPermission()
        }
    }

    private func pollForPermission() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            if AXIsProcessTrusted() { self?.startWheel() }
            else { self?.pollForPermission() }
        }
    }

    private func startWheel() {
        let ctrl = WheelController()
        self.wheelController = ctrl
        setIcon(ready: ctrl.startObserving())
    }
}
