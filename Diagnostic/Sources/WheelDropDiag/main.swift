import AppKit

// SPM executable entry point — boot NSApplication manually.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
