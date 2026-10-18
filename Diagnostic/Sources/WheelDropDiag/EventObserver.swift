import AppKit
import CoreGraphics

// Drag state snapshot — passed to UI callbacks from the main thread.
struct DragState {
    var isButtonDown: Bool = false
    var isDragging: Bool = false
    var shiftHeldAtMouseDown: Bool = false
    var isWheelShown: Bool = false
    var lastPointer: CGPoint = .zero
}

// Global C-compatible callback for CGEventTap.
// Cannot capture context — passes EventObserver via userInfo.
private func tapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let ptr = userInfo else { return Unmanaged.passUnretained(event) }
    let observer = Unmanaged<EventObserver>.fromOpaque(ptr).takeUnretainedValue()
    observer.handleEvent(type: type, event: event)
    return Unmanaged.passUnretained(event) // listenOnly: always return the original
}

final class EventObserver {
    // Callbacks — all invoked on the main thread.
    private let onStateChange: (DragState) -> Void
    private let onShowWheel: (CGPoint) -> Void
    private let onHideWheel: (String) -> Void

    // Drag state — accessed only on main thread (tap runs on main run loop).
    private var state = DragState()

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(
        onStateChange: @escaping (DragState) -> Void,
        onShowWheel: @escaping (CGPoint) -> Void,
        onHideWheel: @escaping (String) -> Void
    ) {
        self.onStateChange = onStateChange
        self.onShowWheel = onShowWheel
        self.onHideWheel = onHideWheel
    }

    // Returns true if the event tap was created successfully.
    @discardableResult
    func start() -> Bool {
        let mask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue)

        // Pass unretained self — AppDelegate keeps us alive.
        let ptr = Unmanaged.passUnretained(self).toOpaque()

        guard let t = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,  // Never modify or swallow events
            eventsOfInterest: mask,
            callback: tapCallback,
            userInfo: ptr
        ) else {
            return false
        }

        tap = t
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        runLoopSource = source
        // Add to main run loop — callback fires on main thread.
        CFRunLoopAddSource(CFRunLoopGetMain(), source, CFRunLoopMode.commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        return true
    }

    // Called from the CGEventTap callback — on main thread.
    func handleEvent(type: CGEventType, event: CGEvent) {
        switch type {
        case .leftMouseDown:
            state.isButtonDown = true
            state.isDragging = false
            state.isWheelShown = false
            state.lastPointer = event.location
            state.shiftHeldAtMouseDown = event.flags.contains(.maskShift)
            onStateChange(state)

        case .leftMouseDragged:
            state.lastPointer = event.location
            if !state.isDragging {
                state.isDragging = true
                onStateChange(state)
            }

        case .leftMouseUp:
            state.lastPointer = event.location
            if state.isWheelShown {
                state.isWheelShown = false
                onStateChange(state)
                onHideWheel("mouse released")
            }
            state.isButtonDown = false
            state.isDragging = false
            onStateChange(state)

        case .flagsChanged:
            let shiftNow = event.flags.contains(.maskShift)

            if shiftNow
                && state.isDragging
                && !state.shiftHeldAtMouseDown  // Shift was tapped after drag started
                && !state.isWheelShown
            {
                state.isWheelShown = true
                onStateChange(state)
                onShowWheel(event.location)

            } else if !shiftNow && state.isWheelShown {
                state.isWheelShown = false
                onStateChange(state)
                onHideWheel("Shift released")
            }

        case .keyDown:
            // Detect Escape during a drag — documents actual behavior.
            if event.getIntegerValueField(.keyboardEventKeycode) == 53 /* kVK_Escape */
                && state.isDragging
            {
                // Esc pressed mid-drag: the source app cancels the drag.
                // We'll see a leftMouseUp shortly (or not — source-dependent).
                // Log this but take no action; document in test results.
                onHideWheel("Escape pressed — source app should cancel drag")
                state.isWheelShown = false
                state.isDragging = false
                state.isButtonDown = false
                onStateChange(state)
            }

        default:
            break
        }
    }

    deinit {
        if let t = tap { CGEvent.tapEnable(tap: t, enable: false) }
        if let s = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), s, CFRunLoopMode.commonModes) }
    }
}
