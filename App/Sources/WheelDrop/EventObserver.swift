import AppKit
import CoreGraphics

// C-compatible CGEventTap callback — userInfo carries the EventObserver.
private func tapCallback(
    proxy: CGEventTapProxy, type: CGEventType,
    event: CGEvent, userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let ptr = userInfo else { return Unmanaged.passUnretained(event) }
    Unmanaged<EventObserver>.fromOpaque(ptr).takeUnretainedValue()
        .handle(type: type, event: event)
    return Unmanaged.passUnretained(event) // .listenOnly — never swallow events
}

final class EventObserver {
    private let onShow: (CGPoint) -> Void
    private let onHide: (String) -> Void

    // State — accessed only on the main run loop thread.
    private var btnDown        = false
    private var isDragging     = false
    private var shiftAtDown    = false
    private var wheelShown     = false

    private var tap: CFMachPort?
    private var src: CFRunLoopSource?

    init(onShow: @escaping (CGPoint) -> Void, onHide: @escaping (String) -> Void) {
        self.onShow = onShow
        self.onHide = onHide
    }

    @discardableResult
    func start() -> Bool {
        let mask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue)    |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue)      |
            (1 << CGEventType.flagsChanged.rawValue)     |
            (1 << CGEventType.keyDown.rawValue)

        let ptr = Unmanaged.passUnretained(self).toOpaque()
        guard let t = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .listenOnly, eventsOfInterest: mask,
            callback: tapCallback, userInfo: ptr
        ) else { return false }

        tap = t
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        src = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, CFRunLoopMode.commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        return true
    }

    func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .leftMouseDown:
            btnDown     = true
            isDragging  = false
            wheelShown  = false
            shiftAtDown = event.flags.contains(.maskShift)

        case .leftMouseDragged:
            isDragging = true

        case .leftMouseUp:
            if wheelShown { onHide("mouse released") }
            btnDown    = false
            isDragging = false
            wheelShown = false

        case .flagsChanged:
            let shiftNow = event.flags.contains(.maskShift)
            let optNow   = event.flags.contains(.maskAlternate)

            if shiftNow && isDragging && !shiftAtDown && !wheelShown {
                wheelShown = true
                onShow(event.location)
            } else if !shiftNow && wheelShown {
                wheelShown = false
                onHide("Shift released")
            }
            _ = optNow // Shift+Option (advanced wheel) — Phase 2 feature

        case .keyDown:
            // Escape cancels many drags in the source app; reset our state.
            if event.getIntegerValueField(.keyboardEventKeycode) == 53 && isDragging {
                if wheelShown { onHide("Escape") }
                isDragging = false
                wheelShown = false
            }

        default: break
        }
    }

    deinit {
        if let t = tap { CGEvent.tapEnable(tap: t, enable: false) }
        if let s = src  { CFRunLoopRemoveSource(CFRunLoopGetMain(), s, CFRunLoopMode.commonModes) }
    }
}
