# WheelDrop Diagnostic — Phase 0

Proves the core interaction before building the real wheel.

## What it tests

| Mechanism | API used | Permission |
|---|---|---|
| Global mouse + modifier tracking | `CGEventTap` (listenOnly) | Accessibility |
| Detecting Shift tapped *during* drag (not held before) | `event.flags` + state machine | same |
| File URLs from drag pasteboard | `NSPasteboard.readObjects(forClasses:options:)` | none |
| Non-activating floating panel | `NSPanel(.nonactivatingPanel)` | none |
| NSDraggingDestination lifecycle | `draggingEntered/performDragOperation` | none |

## First launch setup

1. `open /Users/pradeepgatti/WheelDrop/Diagnostic/WheelDropDiag.app`
   - If Gatekeeper blocks it: System Settings → Privacy & Security → **Open Anyway**
2. A floating panel appears. The menu-bar icon shows **⊘**.
3. macOS shows an Accessibility prompt — click **Open System Settings**.
4. In Settings → Privacy & Security → Accessibility, toggle **WheelDropDiag** on.
5. The panel logs "✅ Accessibility granted" and the menu-bar icon changes to **◉**.

## Manual test procedure

For each test, watch the **state** line at the top of the panel and the log below.

### Test A — Drag from Finder

1. Open Finder, navigate to any folder with a file.
2. Start dragging a file slowly.
3. While still dragging, tap **Shift** (don't hold it before you start).
4. The panel should move to near your pointer and log "🎯 Shift+drag detected".
5. Drag the file over the **DROP FILES HERE** zone.
   - Zone highlights when file URLs are detected.
   - Drop it.
6. Log should show: `draggingEntered`, file names, `✅ DROP ACCEPTED`, `concludeDragOperation`.

### Test B — Shift held before drag starts

1. Hold Shift first.
2. While holding Shift, start dragging a file.
3. **Expected:** wheel does NOT appear (spec requires fresh Shift tap during drag).
4. Log should show state transitions but no "🎯 Shift+drag" line.

### Test C — Desktop (Finder window, different presentation)

Repeat Test A with a file on the Desktop.
Desktop drags come from a Finder instance — should behave identically to Test A.

### Test D — Browser (local file)

1. Download any file so it sits on disk.
2. In Finder, drag that file (not a browser tab).
3. Repeat Test A steps.
Expected: same as Test A. Browser *tab* drags are NOT tested here — they yield
URLs or promises, not local file paths, and are out of scope for Phase 0.

### Test E — Shift released mid-drag

1. Start dragging, tap Shift → panel appears.
2. Release Shift while still holding the mouse button.
3. Expected: log shows "Wheel hidden: Shift released". Panel stays open (diagnostic mode).

### Test F — Mouse released outside drop zone

1. Start drag, tap Shift → panel appears.
2. Drop the file somewhere other than the drop zone (e.g. the Desktop).
3. Expected: log shows "Wheel hidden: mouse released". Source drag completes normally.

### Test G — Escape key

1. Start dragging from Finder, tap Shift.
2. While wheel is shown, press Escape.
3. Expected: log records "Escape pressed — source app should cancel drag".
   Finder will cancel the drag; the file is not moved/copied.
   Document exactly what you see.

## What to report

After running the tests, note for each:
- Pass / Fail / Unexpected behavior
- The exact source app (e.g. "Finder 26.0", "Safari 26.0")
- Any log output that differs from the expected description

Known limitations to watch for:
- Multi-monitor: coordinate conversion uses the primary screen; on a secondary screen
  the panel may appear at the wrong position. Document if observed.
- Promised files (e.g. iCloud items not downloaded): `draggingEntered` will log
  "No file URLs found". Out of scope for Phase 0.
- App sandbox or Hardened Runtime on the *source* app may restrict what it puts on
  the drag pasteboard. Log whatever types appear.
