import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var diagPanel: DiagPanel?
    private var eventObserver: EventObserver?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()

        let panel = DiagPanel()
        self.diagPanel = panel
        panel.showAlways()

        checkPermissions()
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon(trusted: false)

        let menu = NSMenu()
        menu.addItem(withTitle: "WheelDrop Diagnostic", action: nil, keyEquivalent: "")
        menu.addItem(.separator())

        let showItem = NSMenuItem(title: "Show Panel", action: #selector(showPanel), keyEquivalent: "p")
        showItem.target = self
        menu.addItem(showItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        statusItem?.menu = menu
    }

    @objc private func showPanel() {
        diagPanel?.showAlways()
    }

    private func updateIcon(trusted: Bool) {
        // ◉ = monitoring active  ⊘ = no permission
        statusItem?.button?.title = trusted ? "◉" : "⊘"
        statusItem?.button?.toolTip = trusted
            ? "WheelDrop: monitoring active"
            : "WheelDrop: needs Accessibility permission"
    }

    // MARK: - Accessibility permission

    private func checkPermissions() {
        // Prompt the user to grant Accessibility if not already trusted.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        handlePermissionResult(trusted: trusted)
    }

    private func handlePermissionResult(trusted: Bool) {
        updateIcon(trusted: trusted)
        if trusted {
            startObserver()
        } else {
            diagPanel?.log("⚠ Accessibility permission not granted yet.")
            diagPanel?.log("  Open System Settings → Privacy & Security → Accessibility")
            diagPanel?.log("  Enable this app, then it will start automatically.")
            pollForPermission()
        }
    }

    private func pollForPermission() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            if AXIsProcessTrusted() {
                self.updateIcon(trusted: true)
                self.diagPanel?.log("✅ Accessibility granted — starting event observer.")
                self.startObserver()
            } else {
                self.pollForPermission()
            }
        }
    }

    // MARK: - Event observer

    private func startObserver() {
        guard let panel = diagPanel else { return }

        eventObserver = EventObserver(
            onStateChange: { [weak panel] state in
                panel?.updateDragState(state)
            },
            onShowWheel: { [weak panel] location in
                panel?.showAtPointer(location: location)
                panel?.log("🎯 Shift+drag detected — panel moved to pointer. Now drag over the drop zone.")
            },
            onHideWheel: { [weak panel] reason in
                panel?.log("ℹ️  Wheel hidden: \(reason)")
                // Keep panel visible for diagnostics — don't hide in Phase 0.
            }
        )

        let ok = eventObserver?.start() ?? false
        if ok {
            panel.log("✅ Event observer running. Try: drag a file → tap Shift mid-drag.")
        } else {
            panel.log("❌ Failed to create event tap. Is Accessibility permission granted?")
        }
    }
}
