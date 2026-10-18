# WheelDrop

A native macOS file-conversion utility for daily Syessa work.

Drag files from anywhere → tap **Shift** mid-drag → a floating circular tool wheel appears → drop onto a segment to convert.

**Shift + Option** opens the advanced-tools wheel.

---

## Status

| Phase | Description | Status |
|---|---|---|
| 0 | Drag-interaction diagnostic | ✅ Built — awaiting manual test |
| 1 | Circular wheel + tool registry | 🔜 |
| 2 | Image conversion tools | 🔜 |
| 3 | Video / audio / PDF tools | 🔜 |
| 4 | File actions | 🔜 |
| 5 | Settings, onboarding, menu bar | 🔜 |
| 6 | Build, sign, package for work Mac | 🔜 |

---

## Requirements

- macOS 14 or newer
- Apple Silicon or Intel Mac
- **Accessibility permission** (Privacy & Security → Accessibility) — required for global drag detection
- ffmpeg (optional, for video/audio tools) — see [Dependency setup](#dependency-setup)

---

## Quick start (development Mac)

```bash
git clone https://github.com/gpradeep7898/WheelDrop.git
cd WheelDrop/Diagnostic
bash build_diag.sh
open WheelDropDiag.app
```

Grant **Accessibility** when prompted. The menu-bar icon changes from ⊘ to ◉.

---

## Daily use (work Mac, when released)

1. Copy `WheelDrop.app` to `/Applications`.
2. Launch it — it sits in the menu bar with no Dock icon.
3. Grant Accessibility permission once.
4. Drag files from Finder or any app → tap Shift mid-drag → drop onto a wheel segment.

---

## Interaction model

```
Drag files  ──→  tap Shift  ──→  wheel appears  ──→  drop on segment  ──→  converted file saved
                                                 └──→  drop outside    ──→  normal system drop
                 tap Shift+Option  ──→  advanced wheel
```

- The original files are **never modified or deleted**.
- Output is saved beside the input (or in a configured output folder).
- Dropping outside the wheel performs the normal system drop at that location.

---

## Architecture

```
WheelDrop/
├── Diagnostic/              Phase 0 — proves the drag+key mechanism
│   ├── Package.swift
│   ├── Sources/WheelDropDiag/
│   │   ├── main.swift
│   │   ├── AppDelegate.swift   menu bar, permission polling
│   │   ├── EventObserver.swift CGEventTap drag+Shift detection
│   │   └── DiagPanel.swift     floating panel + NSDraggingDestination log
│   ├── Resources/Info.plist
│   ├── build_diag.sh
│   └── README_DIAG.md
├── NETWORK_POLICY.md
└── README.md
```

Main app modules (Phase 1+):

| Module | Responsibility |
|---|---|
| `PermissionManager` | Accessibility status, onboarding, recovery |
| `DragObserver` | CGEventTap, trigger state machine |
| `WheelController` | NSPanel presentation, segment layout, animation |
| `ToolRegistry` | `WheelTool` protocol, compatibility filtering |
| `JobQueue` | Background execution, cancellation, concurrency cap |
| `OutputWriter` | Temp-file-then-move, naming, collision handling |
| `DependencyChecker` | ffmpeg detection, capability flags |
| `SettingsStore` | UserDefaults, launch-at-login |

---

## Tool protocol

Every conversion tool conforms to:

```swift
protocol WheelTool {
    var id: String { get }               // stable, never changes
    var displayName: String { get }
    var sfSymbol: String { get }
    func accepts(_ urls: [URL]) -> Bool  // input compatibility predicate
    func execute(urls: [URL], outputDir: URL) async throws -> [URL]
}
```

Adding a tool = one file + one registry entry.

---

## Dependency setup

### ffmpeg (video, audio, GIF)

WheelDrop never downloads or installs ffmpeg automatically.

**Option A — Homebrew (development Mac):**
```bash
brew install ffmpeg
```

**Option B — Bundle with app (work Mac, self-contained):**
See `BUILD_AND_INSTALL.md` (added in Phase 6) for bundling instructions, architecture requirements, and license obligations.

---

## Building for the work Mac

See `BUILD_AND_INSTALL.md` (Phase 6). Summary:

- The app is packaged as `WheelDrop.app` inside a ZIP or DMG.
- The work Mac needs no Xcode, source code, or developer tools.
- Requires a Developer ID certificate for notarized distribution (Phase 6 step).
- Ad-hoc signing works for personal use on your own machines.

---

## Network policy

WheelDrop makes zero network connections. See [NETWORK_POLICY.md](NETWORK_POLICY.md).

---

## License

Private / internal tool. See individual dependency licenses in `LICENSES/` (Phase 6).
