import AppKit
import os

/// Four-finger drag pans the canvas from anywhere: on the canvas, over windows too (where a one-finger
/// drag would move them), and from inside an entered window, which brings the canvas back first. No
/// modifier, no key first, and every direction pans, up included. A four-finger *tap* (four fingers
/// down and up again without moving) shows everything, as Mission Control's swipe does; or, by
/// Settings › How to use, a four-finger *swipe up* does — any upward stroke, however slow, told from a
/// pan by its direction (horizontal and diagonal drags still pan; up opens the whole canvas). An upward
/// drag pans nothing while it is still on its way up: the canvas holds still until the stroke is far
/// enough to be the swipe, so the pull-back starts where the hand does, not after a pan (A1). Thumb and
/// three fingers spreading apart is Show Desktop, as on the Mac.
///
/// The touches come straight from the trackpad through MultitouchSupport, the private framework Mac
/// gesture tools read (MiddleClick, BetterTouchTool). There's no public route: AppKit only hands touches
/// to a view under the pointer, and the gesture events an event tap sees carry none. It needs no
/// permission.
///
/// The system reads the same four fingers as a Mission Control or Spaces swipe and drives the Dock with
/// Dock-control events. A session event tap (Accessibility, on its own thread like `KeyTap`) drops those
/// while four fingers are down, so the drag pans and does nothing else. That takes the four-finger pinch
/// (Launchpad) with it; five fingers are left alone.
final class TrackpadPan: @unchecked Sendable {
    enum Phase: Sendable, Equatable {
        case began
        /// Finger travel since the last update, in trackpad widths, y down. The content follows it.
        case changed(CGVector)
        case ended
        /// A four-finger tap, as the fingers lift: See All, in tap mode only.
        case seeAll
        /// Swipe-up entry recognized: the canvas comes up and the pull-back follows the finger.
        case entryBegan
        /// Swipe-up entry progress t∈[0,1], each frame after entryBegan until the fingers lift.
        case entryProgress(CGFloat)
        /// The entry swipe's fingers lifted; the controller commits or cancels from the last progress.
        case entryEnded
        /// The four fingers spread apart (Show Desktop), once per touch. No pan comes with it.
        case spread
    }

    /// Centroid travel, in trackpad widths, before four fingers on the trackpad count as a drag. Keeps
    /// a four-finger tap or pinch from moving anything.
    fileprivate static let slop: CGFloat = 0.02
    /// A drag that starts within this angle of horizontal stays level until the fingers lift. No
    /// four-finger drag is ever quite level, and sweeping along a row of windows shouldn't creep up or
    /// down (a window's top under the menu bar can't be entered where it is). One within this angle of
    /// vertical stays plumb the same way.
    fileprivate static let axisLock: CGFloat = 22.5 * .pi / 180
    /// A tap's four fingers land together: the fourth within this long of the first. A finger that joins
    /// a three-finger tap (Look Up) later never makes one. (`entryLanding` is the swipe up's, wider.)
    fileprivate static let tapLanding: CFAbsoluteTime = 0.15
    /// Centroid rise, in trackpad widths, that makes an upward drag a swipe up and starts the entry (t=0).
    /// About half a centimetre on a built-in trackpad: just past `slop`, enough to know the hand is going
    /// up, so the pull-back starts with the hand instead of a pan doing it first.
    /// Provisional (2026-11-16): a hand's swipes up measured 0.047–0.10 widths of rise, so 0.10 (the
    /// distance the old tests' five-centimetre strokes made) meant most swipes up never began an entry;
    /// and every frame before it panned the canvas up, unscaled — the "up first, then pull back" report.
    fileprivate static let swipeDistance: CGFloat = 0.035
    /// Further centroid rise, in trackpad widths, that takes the entry from just begun (t=0) to all the
    /// way in (t=1). About a centimetre and a half on a built-in trackpad: a hand's usual swipe-up
    /// stroke, so the pull-back follows the hand over the whole of it and the release commits at
    /// 0.065 (halfway). Provisional, to be confirmed on the device. (0.19 put the commit at 0.145: a
    /// hand's rise of 0.07–0.10 released under it and always went back out.)
    fileprivate static let entryDistance: CGFloat = 0.095
    /// How far off vertical a swipe up may lean and still be one. A hand swipes up 20–30° off vertical; a
    /// deliberate diagonal is 45°. Provisional, to be confirmed on the device. (`axisLock`'s 22.5° held
    /// the entry to within 22.5° of vertical, so a hand's naturally leaning swipe was read as a diagonal
    /// pan and only moved the canvas — the A1/A2 failure.)
    fileprivate static let entryAngle: CGFloat = 35 * .pi / 180
    /// A hand's four fingers land over a longer spread than a tap's: the fourth within this long of the
    /// first still makes a swipe up. Wider than `tapLanding` because the entry needs a centimetre and a
    /// half of upward travel on top, which no three-finger gesture (Look Up, back, forward) makes.
    /// Provisional, to be confirmed on the device.
    fileprivate static let entryLanding: CFAbsoluteTime = 0.4
    /// A frame or two of the four contacts reading as three, this long or shorter, is the trackpad (a
    /// lifting finger is reported a frame before it goes), not a new touch: the swipe under way goes on.
    /// Longer than this is the hand. About two frames at 60 Hz.
    fileprivate static let contactGrace: CFAbsoluteTime = 0.05
    /// `defaults write com.spacefarm.sunlight TrackpadDiagnostics -bool YES` logs every frame of a swipe
    /// up — rise, run, angle, landing, entry and t — for measuring a hand on the device. Off by default:
    /// each frame is a line in the log file.
    fileprivate static let diagnosticsKey = "TrackpadDiagnostics"
    /// A tap is over, the first finger lifting, within this long of the first one landing. A hand
    /// that rests on the trackpad longer is resting.
    fileprivate static let tapDuration: CFAbsoluteTime = 0.3
    /// Growth of the fingers' mean distance from their centroid, in trackpad widths, that makes a spread.
    /// About a centimetre on a built-in trackpad: the thumb and the fingers part by twice that. (0.12
    /// before 2026-10-28 asked for a spread wider than a hand makes, so Show Desktop never fired.)
    fileprivate static let spreadDistance: CGFloat = 0.07
    /// Dock-control events are still dropped this long after the fingers lift: the system's swipe ends
    /// a beat later.
    fileprivate static let dockTail: CFAbsoluteTime = 0.3
    /// The CGS event type of Dock control (Mission Control, Spaces and Launchpad gestures). Not in
    /// `CGEventType`.
    private static let dockControl: UInt32 = 30

    /// MultitouchSupport's frame callback is a C function with no context pointer.
    private nonisolated(unsafe) static weak var shared: TrackpadPan?

    private let handler: @MainActor @Sendable (Phase) -> Void
    private let state = OSAllocatedUnfairLock(initialState: TrackpadRecognizer())

    // Main thread.
    private let mt = MultitouchSupport()
    /// Owns the devices; they're released with it.
    private var deviceList: CFArray?
    private var wakeToken: NSObjectProtocol?
    private var settingToken: NSObjectProtocol?

    // Tap thread.
    private var thread: Thread?
    private var port: CFMachPort?

    init(handler: @escaping @MainActor @Sendable (Phase) -> Void) {
        self.handler = handler
    }

    @MainActor func start() {
        guard thread == nil else { return }
        TrackpadPan.shared = self
        // Settings is the main actor's; the recognizer keeps its own copy of the one choice it needs.
        followSetting()
        settingToken = NotificationCenter.default.addObserver(
            forName: Settings.seeAllGestureDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.followSetting() }
        }
        startDevices()
        // The trackpad stops reporting across sleep; start over with whatever is attached on wake.
        wakeToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self?.restartDevices() }
        }

        let t = Thread { [weak self] in self?.threadMain() }
        t.name = "canvas.trackpadpan"
        t.qualityOfService = .userInteractive
        thread = t
        t.start()
    }

    @MainActor private func followSetting() {
        let swipeUp = Settings.seeAllGesture == .swipeUp
        // Temporary: a frame-by-frame log of a swipe up, for measuring a hand on the device.
        let diagnose = UserDefaults.standard.bool(forKey: TrackpadPan.diagnosticsKey)
        state.withLock {
            $0.swipeUpSeesAll = swipeUp
            $0.diagnose = diagnose
        }
    }

    /// Sunlight on or off (the menu bar switch). Off, the four fingers are the Mac's own again: the
    /// Dock-control events that make Mission Control's and Spaces' swipes pass. (They were dropped
    /// whenever four fingers were down, on or off, so with Sunlight off a four-finger swipe did nothing
    /// at all: not a pan, and not Mission Control either.)
    @MainActor func setActive(_ active: Bool) {
        state.withLock { $0.active = active }
    }

    // MARK: Touches

    private func startDevices() {
        guard let mt else {
            Log.note("TrackpadPan: MultitouchSupport unavailable, four-finger pan is off")
            return
        }
        guard let list = mt.createList()?.takeRetainedValue() else {
            Log.note("TrackpadPan: no multitouch devices")
            return
        }
        deviceList = list
        var heightPerWidth: [UInt: CGFloat] = [:]
        for device in devices {
            var w: Int32 = 0, h: Int32 = 0
            _ = mt.surfaceSize?(device, &w, &h)
            heightPerWidth[UInt(bitPattern: device)] = w > 0 && h > 0 ? CGFloat(h) / CGFloat(w) : 0.62
            mt.register(device, TrackpadPan.contactFrame)
            _ = mt.start(device, 0)
        }
        state.withLock { [heightPerWidth] in $0.heightPerWidth = heightPerWidth }
        Log.note("TrackpadPan: following \(devices.count) multitouch device(s)")
    }

    private func restartDevices() {
        if let mt {
            for device in devices {
                mt.unregister(device, TrackpadPan.contactFrame)
                _ = mt.stop(device)
            }
        }
        deviceList = nil
        let phases = state.withLock { $0.reset() }
        phases.forEach(send)
        startDevices()
    }

    private var devices: [MultitouchSupport.Device] {
        guard let deviceList else { return [] }
        return (0..<CFArrayGetCount(deviceList)).compactMap { i in
            CFArrayGetValueAtIndex(deviceList, i).map { UnsafeMutableRawPointer(mutating: $0) }
        }
    }

    private static let contactFrame: MultitouchSupport.FrameCallback = { device, contacts, count, _, _ in
        if let device, let pan = TrackpadPan.shared {
            pan.frame(device: device, contacts: contacts, count: Int(count))
        }
        return 0
    }

    /// On MultitouchSupport's thread (one per device).
    private func frame(device: MultitouchSupport.Device, contacts: UnsafeRawPointer?, count: Int) {
        var fingers = Set<Int32>()
        var points: [CGPoint] = []
        if let contacts {
            for i in 0..<count {
                let c = contacts + i * Contact.size
                guard Contact.onSurface.contains(c.load(fromByteOffset: Contact.state, as: Int32.self)) else { continue }
                fingers.insert(c.load(fromByteOffset: Contact.pathIndex, as: Int32.self))
                points.append(CGPoint(x: CGFloat(c.load(fromByteOffset: Contact.x, as: Float.self)),
                                      y: CGFloat(c.load(fromByteOffset: Contact.y, as: Float.self))))
            }
        }
        let now = CFAbsoluteTimeGetCurrent()
        let key = UInt(bitPattern: device)
        let phases = state.withLock { [fingers, points] s -> [Phase] in
            // In trackpad widths on both axes, so a diagonal moves diagonally on any trackpad. y is up here.
            let k = s.heightPerWidth[key] ?? 0.62
            let scaled = points.map { CGPoint(x: $0.x, y: $0.y * k) }
            let n = CGFloat(max(scaled.count, 1))
            let centroid = CGPoint(x: scaled.reduce(0) { $0 + $1.x } / n, y: scaled.reduce(0) { $0 + $1.y } / n)
            let spread = scaled.reduce(0) { $0 + hypot($1.x - centroid.x, $1.y - centroid.y) } / n
            return s.update(device: key, fingers: fingers, centroid: centroid, spread: spread, now: now)
        }
        phases.forEach(send)
    }

    private func send(_ phase: Phase) {
        let handler = self.handler
        DispatchQueue.main.async {
            MainActor.assumeIsolated { handler(phase) }
        }
    }

    // MARK: Tap thread

    private func threadMain() {
        installTap()
        let watchdog = Timer(timeInterval: 5, repeats: true) { [weak self] _ in self?.checkTap() }
        RunLoop.current.add(watchdog, forMode: .common)
        CFRunLoopRun()
        watchdog.invalidate()
    }

    private func installTap() {
        let info = Unmanaged.passUnretained(self).toOpaque()
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                           options: .defaultTap,
                                           eventsOfInterest: CGEventMask(1) << TrackpadPan.dockControl,
                                           callback: TrackpadPan.callback, userInfo: info) else {
            Log.note("TrackpadPan: tapCreate failed — Accessibility granted? Retrying in 3 s")
            let retry = Timer(timeInterval: 3, repeats: false) { [weak self] _ in self?.installTap() }
            RunLoop.current.add(retry, forMode: .common)
            return
        }
        self.port = port
        let source = CFMachPortCreateRunLoopSource(nil, port, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        Log.note("TrackpadPan: Dock-control tap installed")
    }

    private func checkTap() {
        guard let port else { return }
        if !CFMachPortIsValid(port) {
            Log.note("TrackpadPan: port invalidated, reinstalling")
            self.port = nil
            installTap()
        } else if !CGEvent.tapIsEnabled(tap: port) {
            CGEvent.tapEnable(tap: port, enable: true)
        }
    }

    private static let callback: CGEventTapCallBack = { _, type, event, info in
        guard let info else { return Unmanaged.passUnretained(event) }
        return Unmanaged<TrackpadPan>.fromOpaque(info).takeUnretainedValue().filter(type: type, event: event)
    }

    private func filter(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let port { CGEvent.tapEnable(tap: port, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type.rawValue == TrackpadPan.dockControl else { return Unmanaged.passUnretained(event) }
        let drop = state.withLock { CFAbsoluteTimeGetCurrent() < $0.dropDockControlUntil }
        return drop ? nil : Unmanaged.passUnretained(event)
    }
}

/// The four-finger drag, tap and spread, fed one trackpad frame at a time.
struct TrackpadRecognizer {
    /// Height over width of each device's surface, keyed by device.
    var heightPerWidth: [UInt: CGFloat] = [:]
    /// The device being followed (a Magic Mouse reports through the same framework).
    var device: UInt?
    /// The four contacts being followed.
    var fingers: Set<Int32> = []
    /// Where their centroid was when the fourth one landed; nil once the drag has begun.
    var anchor: CGPoint?
    /// Their mean distance from the centroid when the fourth one landed: a spread grows it.
    var anchorSpread: CGFloat = 0
    /// The centroid at the previous frame while dragging.
    var last: CGPoint?
    /// The drag is held level (dy = 0) or plumb (dx = 0), decided as it begins; nil for a free
    /// (diagonal) drag.
    var lock: Lock?
    /// Settings › How to use: an upward swipe is See All, instead of a tap.
    var swipeUpSeesAll = false
    /// Sunlight is on: the four fingers are the canvas's, and the system's own swipes are held off.
    var active = true
    /// The fingers moved or spread while no drag was under way: not a tap any more.
    var stirred = false
    /// Where the centroid was as the drag began; an upward swipe is measured from there.
    var dragOrigin: CGPoint?
    /// The spread has fired; the rest of the touch does nothing.
    var swiped = false
    /// A swipe up has opened the canvas's entry: progress is under way until the fingers lift.
    var entryActive = false
    /// When the four contacts first read as fewer mid-swipe: the trackpad's own frame or two, or the
    /// hand leaving. Held for `contactGrace` before the swipe is given up.
    var contactsMissing: CFAbsoluteTime?
    /// Every frame of a swipe up in the log, for measuring a hand (see `TrackpadPan.diagnosticsKey`).
    var diagnose = false
    /// What the swipe up of this touch has done, for the log (see `Trace`).
    var trace = Trace()

    enum Lock { case level, plumb }
    /// When the first finger of this touch landed; nil with no finger down.
    var touchBegan: CFAbsoluteTime?
    /// How long after the touch's first finger the fourth landed; nil with fewer than four anchored. The
    /// tap wants `tapLanding` (the four together); the swipe up tolerates `entryLanding` (a hand rolls
    /// its fingers on over a longer spread, and the stroke it then makes is what tells it from a tap).
    var landingDelay: CFAbsoluteTime?
    /// The four landed together (`tapLanding`), so lifting them again soon may be a tap.
    var landedTogether: Bool { (landingDelay ?? .infinity) <= TrackpadPan.tapLanding }
    /// From four fingers landing until the last one lifts: the system's swipe lasts that long, however
    /// many fingers stay down.
    var fourFingerTouch = false
    /// Read by the event tap.
    var dropDockControlUntil: CFAbsoluteTime = 0

    /// One swipe up, as the log needs it: how long the hand took to land its fingers, how far up it came
    /// and how upright, whether the entry began and where it got to. Temporary: it exists to measure a
    /// hand on the device (`TrackpadPan.diagnosticsKey`), and drives nothing.
    struct Trace {
        var landing: CFAbsoluteTime = 0
        var peakRise: CGFloat = 0
        var peakAngle: CGFloat = 0
        var began = false
        var t: CGFloat = 0
        /// Frames where the trackpad read three contacts and the swipe went on regardless.
        var drops = 0

        /// `angle` is from horizontal, in radians; `off` is how far from vertical, which is how a swipe
        /// up is thought of.
        static func offVertical(_ angle: CGFloat) -> Int {
            Int((90 - angle * 180 / .pi).rounded())
        }

        mutating func frame(landing: CFAbsoluteTime, rise: CGFloat, angle: CGFloat) {
            self.landing = landing
            if rise > peakRise {
                peakRise = rise
                peakAngle = angle
            }
        }

        /// "swipe up — landing +0.03s, peak rise 0.152 (25° off vertical) — no entry: rise 0.152 < 0.19",
        /// or with the entry under way, "… entry to t 0.58 (committed)".
        var summary: String {
            let degrees = Trace.offVertical(peakAngle)
            var line = "swipe up — landing +\(String(format: "%.2f", landing))s, "
                + "peak rise \(String(format: "%.3f", peakRise)) (\(degrees)° off vertical)"
            if drops > 0 { line += ", \(drops) three-contact frame(s) kept" }
            if began {
                let verdict = t >= EntryFlight.commitThreshold ? "committed" : "back out"
                return line + ", entry to t \(String(format: "%.2f", t)) (\(verdict))"
            }
            if peakRise < TrackpadPan.swipeDistance {
                return line + " — no entry: rise \(String(format: "%.3f", peakRise)) < "
                    + "\(String(format: "%.3f", TrackpadPan.swipeDistance))"
            }
            let upright = .pi / 2 - TrackpadPan.entryAngle
            if peakAngle < upright {
                return line + " — no entry: \(degrees)° off vertical, over "
                    + "\(Int((TrackpadPan.entryAngle * 180 / .pi).rounded()))°"
            }
            if landing > TrackpadPan.entryLanding {
                return line + " — no entry: landed over \(String(format: "%.2f", landing))s > "
                    + "\(String(format: "%.2f", TrackpadPan.entryLanding))s"
            }
            return line + " — no entry"
        }
    }

    /// `spread` is the fingers' mean distance from `centroid`, in trackpad widths.
    mutating func update(device: UInt, fingers ids: Set<Int32>, centroid: CGPoint, spread: CGFloat = 0,
                         now: CFAbsoluteTime) -> [TrackpadPan.Phase] {
        if let followed = self.device, followed != device { return [] }
        if ids.count == 4 { fourFingerTouch = true } else if ids.isEmpty { fourFingerTouch = false }
        if fourFingerTouch, active { dropDockControlUntil = now + TrackpadPan.dockTail }
        let began = touchBegan ?? now
        if ids.isEmpty { touchBegan = nil } else if touchBegan == nil { touchBegan = now }
        // A finger lifted, or one landed: what was under way is over. Four fingers that landed together,
        // never moved and lift again at once were a tap.
        guard ids.count == 4 else {
            // Except a frame or two of three contacts with four fingers still on the trackpad: a lifting
            // finger is reported a frame before it goes, and the touch is the same touch. Giving up here
            // would lose the drag's origin and its entry — which a hand's swipe, unlike the tests' four
            // even fingers, trips constantly — and the swipe could never begin again (A1/A2).
            let underWay = last != nil || entryActive || dragOrigin != nil
            if underWay, !ids.isEmpty {
                guard let since = contactsMissing else {
                    contactsMissing = now
                    return []
                }
                let missing = now - since
                guard missing > TrackpadPan.contactGrace else { return [] }
                if swipeUpSeesAll {
                    Log.note("Entry diag: \(ids.count) contacts for \(milliseconds(missing)) — "
                             + "past the grace, the swipe ends here")
                }
            }
            let tap = !swipeUpSeesAll && ids.count < 4 && fingers.count == 4 && last == nil && !swiped
                && !stirred && landedTogether && now - began <= TrackpadPan.tapDuration
            return end() + (tap ? [.seeAll] : [])
        }
        if let since = contactsMissing {   // the fourth is back: the same touch, still
            contactsMissing = nil
            trace.drops += 1
            if swipeUpSeesAll {
                Log.note("Entry diag: four contacts again after \(milliseconds(now - since)) — kept, "
                         + (entryActive ? "the entry goes on" : "no entry yet"))
            }
        }
        if ids == fingers, swiped { return [] }
        guard ids == fingers, let from = last ?? anchor else {
            let phases = end()
            self.device = device
            fingers = ids
            anchor = centroid
            anchorSpread = spread
            landingDelay = now - (touchBegan ?? now)
            return phases
        }
        var travel = CGVector(dx: centroid.x - from.x, dy: from.y - centroid.y)
        var phases: [TrackpadPan.Phase] = []
        if last == nil {
            // Before a drag begins, fingers moving apart (or together) more than the hand moves is a
            // spread (or Launchpad's pinch), not a pan.
            let grown = spread - anchorSpread
            if grown >= TrackpadPan.spreadDistance {
                swiped = true
                return [.spread]
            }
            if abs(grown) >= TrackpadPan.slop || hypot(travel.dx, travel.dy) >= TrackpadPan.slop { stirred = true }
            // Spreading fingers shift the centroid too (the thumb moves furthest); while the spread keeps
            // up with the shift, the touch is still undecided.
            guard abs(grown) <= hypot(travel.dx, travel.dy) / 2 else { return [] }
            guard hypot(travel.dx, travel.dy) >= TrackpadPan.slop else { return [] }
            anchor = nil
            dragOrigin = from
            let angle = atan2(abs(travel.dy), abs(travel.dx))
            if angle <= TrackpadPan.axisLock {
                lock = .level
            } else if angle >= .pi / 2 - TrackpadPan.axisLock {
                lock = .plumb
            } else {
                lock = nil
            }
            phases.append(.began)
        }
        if swipeUpSeesAll, let origin = dragOrigin, let landing = landingDelay,
           landing <= TrackpadPan.entryLanding {
            // Any upward swipe opens the canvas, however slow: the whole travel so far, straight up and
            // far enough, begins the entry. Progress is measured from the recognition threshold, so the
            // canvas starts at the camera it was on (no jump) and the rest of the stroke drives the
            // pull-back; the finger coming back down scrubs it out again. Until the swipe is far enough
            // to be one, an upward drag pans nothing: the canvas waits under the hand (A1).
            let rise = centroid.y - origin.y   // the centroid's y goes up the trackpad
            let run = abs(centroid.x - origin.x)
            let angle = atan2(rise, run)
            let upright = rise > 0 && angle >= .pi / 2 - TrackpadPan.entryAngle
            let recognized = rise >= TrackpadPan.swipeDistance && upright
            trace.frame(landing: landing, rise: rise, angle: angle)
            if diagnose {
                Log.note("Entry diag frame: rise \(String(format: "%.3f", rise)) "
                         + "run \(String(format: "%.3f", run)) "
                         + "\(Trace.offVertical(angle))° off vertical "
                         + "landing +\(String(format: "%.2f", landing))s "
                         + "\(entryActive ? "entry" : (upright ? "up" : "pan")) → "
                         + "\(recognized || entryActive ? "entry" : "no")")
            }
            if recognized || entryActive {
                let span = TrackpadPan.entryDistance - TrackpadPan.swipeDistance
                let t = min(max((rise - TrackpadPan.swipeDistance) / span, 0), 1)
                let first = !entryActive
                entryActive = true
                last = centroid   // the pan is over here; lifting the fingers won't `end` it again
                trace.began = true
                trace.t = t
                if first, diagnose {
                    Log.note("Entry diag: the entry begins — rise \(String(format: "%.3f", rise)) "
                             + "at \(Trace.offVertical(angle))° off vertical, "
                             + "landing +\(String(format: "%.2f", landing))s")
                }
                return phases + (first ? [.entryBegan, .entryProgress(t)] : [.entryProgress(t)])
            }
            if upright {
                // Up, but not yet far enough to be a swipe up: hold the canvas still. Panning here is
                // what the hand saw as the window sliding up unscaled before the pull-back, and it also
                // handed the entry a camera already moved. The frames that aren't upright (a diagonal,
                // a downward drag) fall through and pan as they always have.
                last = centroid
                return phases
            }
        }
        switch lock {
        case .level: travel.dy = 0
        case .plumb: travel.dx = 0
        case nil: break
        }
        phases.append(.changed(travel))
        last = centroid
        return phases
    }

    /// The touch is over: log what the swipe up made of it (one line a swipe, `Trace`), then reset.
    private mutating func end() -> [TrackpadPan.Phase] {
        if swipeUpSeesAll, trace.peakRise > 0 { Log.note("Entry diag: \(trace.summary)") }
        return reset()
    }

    /// `0.017s` as `17ms`, for the log.
    private func milliseconds(_ seconds: CFAbsoluteTime) -> String {
        String(format: "%.0fms", seconds * 1000)
    }

    mutating func reset() -> [TrackpadPan.Phase] {
        // An entry's fingers lifting ends the entry, not a pan (entryActive implies last != nil).
        let phases: [TrackpadPan.Phase] = entryActive ? [.entryEnded] : (last == nil ? [] : [.ended])
        device = nil
        fingers = []
        anchor = nil
        last = nil
        lock = nil
        stirred = false
        dragOrigin = nil
        swiped = false
        entryActive = false
        landingDelay = nil
        contactsMissing = nil
        trace = Trace()
        anchorSpread = 0
        return phases
    }
}

/// A contact in a MultitouchSupport frame: its 96-byte `MTTouch`, of which only these fields are read.
private enum Contact {
    static let size = 96
    static let pathIndex = 16    // Int32, stable while the finger stays down
    static let state = 20        // Int32
    static let x = 32            // Float, 0…1 left to right
    static let y = 36            // Float, 0…1 bottom to top
    /// `state` while the finger is on the surface (make-touch, touching). Hovering, lifting and
    /// lingering don't count.
    static let onSurface: ClosedRange<Int32> = 3...4
}

/// The few MultitouchSupport calls used here, looked up at runtime (private framework, no headers).
private struct MultitouchSupport {
    typealias Device = UnsafeMutableRawPointer
    /// (device, contacts, contact count, timestamp, frame number).
    typealias FrameCallback = @convention(c) (Device?, UnsafeRawPointer?, Int32, Double, Int32) -> Int32

    let createList: @convention(c) () -> Unmanaged<CFArray>?
    let register: @convention(c) (Device, FrameCallback) -> Void
    let unregister: @convention(c) (Device, FrameCallback) -> Void
    let start: @convention(c) (Device, Int32) -> Int32
    let stop: @convention(c) (Device) -> Int32
    /// In hundredths of a millimetre.
    let surfaceSize: (@convention(c) (Device, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Int32)?

    init?() {
        guard let lib = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW) else {
            return nil
        }
        func fn<T>(_ name: String) -> T? { dlsym(lib, name).map { unsafeBitCast($0, to: T.self) } }
        guard let createList: @convention(c) () -> Unmanaged<CFArray>? = fn("MTDeviceCreateList"),
              let register: @convention(c) (Device, FrameCallback) -> Void = fn("MTRegisterContactFrameCallback"),
              let unregister: @convention(c) (Device, FrameCallback) -> Void = fn("MTUnregisterContactFrameCallback"),
              let start: @convention(c) (Device, Int32) -> Int32 = fn("MTDeviceStart"),
              let stop: @convention(c) (Device) -> Int32 = fn("MTDeviceStop") else {
            return nil
        }
        self.createList = createList
        self.register = register
        self.unregister = unregister
        self.start = start
        self.stop = stop
        surfaceSize = fn("MTDeviceGetSensorSurfaceDimensions")
    }
}
