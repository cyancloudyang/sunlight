# Spatial Camera Part A — Gesture-Driven Entry + Per-Card Fly Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make entering the Tablecloth canvas follow the hand (four-finger swipe-up drives the pull-back 1:1, release springs to overview) and fly each visible window card from its real stacked screen position to its stored canvas place, removing the stacked→tiled "分裂感".

**Architecture:** The recognizer turns the upward swipe into continuous entry progress instead of a discrete `.seeAll`. A pure `EntryFlight` model maps one progress `t` to the camera (existing `CameraPath`) and to each card's origin (clamped lerp). The controller orchestrates: show canvas at the current camera, drive `t` from the finger via `view.set(camera:)` + `proxy.place(at:)`, and on release re-base the cards and ride the existing retargetable `fly(step:)` spring to overview (commit) or back to start (cancel). Non-gesture triggers (tap/hotkey/menu) use `fly` directly. Zero streams, single CA transform, all motion reuses `Spring`/`CameraPath`/`fly`/`flightRect`/`interruptMotion`.

**Tech Stack:** Swift 5 (production module `Canvas`), Swift 6 strict (test target `CanvasTests`), XCTest, AppKit + Core Animation, CADisplayLink. macOS 15+, Apple Silicon.

**Spec:** `docs/superpowers/specs/2026-11-12-spatial-camera-design.md` (§7 A1/A2, §7.3 settled builder-check calls Q1–Q7). Read it before starting; §7.3 records the grounded calls and their costs.

## Global Constraints

- 不关闭 SIP、不做任何 SIP 相关改动；不注入系统进程。
- CPU/GPU/内存尽量低；常驻捕获流（SCK stream / CGDisplayStream）一律不用；零重渲染（卡片是 ≤1024px 长边静态快照，放大只是 CA 缩放）。
- 任何「必须」的私有 API 不接受；MultitouchSupport 为既有可选私有件，沿用，不新增私有 API。
- 不改 Dock/Finder/系统手势等任何系统偏好、不做登录项。
- 许可证边界：Sunlight/orcv MIT 可改编署名；canvasWM/minfwm 无许可证只借鉴思路不复制代码。
- 只 push origin（cyancloudyang/sunlight）tablecloth，绝不 push upstream（spacefarm-digital）。PR #1 保持 draft 直到用户验收。
- 生产模块 Swift 5；测试 target Swift 6 严格模式。TDD：每项 RED→GREEN→全套件 `swift test`；编译警告不新增（既有基线除外）。
- 复用现有动画件（`Spring`/`CameraPath`/`fly`/`animateCamera`/`flightRect`/`interruptMotion`），不新造引擎。
- 不擅自改用户已保存布局/手动状态；新行为可逆、可一键关（`Settings.gestureEntry`，默认开）。
- 控制器/视图胶水不单元测试（沿用约定）；纯几何/策略/识别器单测。原生视觉顺滑度需真机确认，不代为宣称达标；不虚构 CPU/GPU/内存数字。
- Bash 工具须 `dir_path=/Users/cycloudyang/Documents/Qoder/2026-11-10/4aceb90d/sunlight`；用 Grep 工具而非 shell grep。

## Review Focus

The spec implies these inputs/failure modes; the most likely to bite a person, most likely first. Each gets a test in the owning task (pure where possible; glue ones are build + real-device verified and named here so the reviewer checks them deliberately):

1. **First-ever entry, no proxies / `overviewCamera == nil`** — a brand-new canvas with no windows must not crash or fly; entry degrades to a no-op/plain show. (Task 2 tests `EntryFlight.cards` empty; Task 3 guards nil overview.)
2. **A window closes or minimizes mid-flight** — its proxy may be gone or off-screen when a step runs; card driving must skip dead proxies, not crash. (Task 4 uses weak/guarded proxy refs; real-device check.)
3. **Cancel after a partial swipe** — camera AND cards return to their start; if the canvas was hidden before entry, it hides again. (Task 2 tests commit policy below threshold; Task 3 cancel path.)
4. **Interrupt mid-entry (click/pan/zoom another window)** — entry finalizes to overview, no card stuck mid-air, the new action proceeds. (Task 4 interrupt finalize; real-device check.)
5. **Reduce Motion enabled** — entry settles instantly, no spring overshoot (matches existing `snap` convention). (Task 3 honors `accessibilityDisplayShouldReduceMotion`.)

Also covered by routing/tests: multi-display swipe routes to the panning canvas (Task 3 Desk routing); swipe-up when already at overview is idempotent, no card fly (Task 3).

---

## File Structure

- `Sources/Canvas/TrackpadPan.swift` (modify) — `TrackpadPan.Phase` gains entry cases; `TrackpadRecognizer` emits continuous entry progress in swipeUp mode. One responsibility: turn trackpad frames into gesture phases.
- `Sources/Canvas/EntryFlight.swift` (create) — pure entry model: flight-set selection (on-screen windows → from/to origins), clamped origin lerp, commit policy, release velocity. No AppKit/CA; depends only on `Camera`, `CameraPath`, `FrameSnapshot`, CoreGraphics. One responsibility: the geometry/policy of one entry flight.
- `Sources/Canvas/Settings.swift` (modify) — `gestureEntry` bool (default true), key `CanvasGestureEntry`, change notification. Reversible gate for the new entry path.
- `Sources/Canvas/CanvasController.swift` (modify) — `trackpadPan` handles entry phases; entry orchestration (show, flight set, drive, release, cancel, interrupt, non-gesture fly). The glue, mirroring the existing `handoff` orchestration.
- `Sources/Canvas/Desk.swift` (modify) — route the new entry phases to the panning canvas (like `.seeAll`).
- `Tests/CanvasTests/TrackpadRecognizerTests.swift` (modify) — swipe-up tests assert entry phases; new progress/clamp/cancel tests.
- `Tests/CanvasTests/EntryFlightTests.swift` (create) — flight-set selection, origin lerp clamp, commit policy, velocity.
- `Tests/CanvasTests/SettingsTests.swift` (modify) — `gestureEntry` default + round-trip.

No new view code: A1/A2 reuse `CanvasView.set(camera:)`, `fly(to:rho:step:completion:)`, `overviewCamera`, `interruptMotion`, and `WindowProxy.place(at:)` (whose `worldRect.didSet` already carries attached children — Q7 attached-fly is automatic).

---

### Task 1: Recognizer entry-progress phases

**Files:**
- Modify: `Sources/Canvas/TrackpadPan.swift` (`Phase` enum :22-32; `TrackpadRecognizer` state :262-298, `update` :301-371, `reset` :373-386)
- Test: `Tests/CanvasTests/TrackpadRecognizerTests.swift`

**Interfaces:**
- Consumes: existing `TrackpadRecognizer.update(device:fingers:centroid:spread:now:) -> [TrackpadPan.Phase]`, `swipeUpSeesAll`, `dragOrigin`, `landedTogether`, constants `swipeDistance` (0.12), `axisLock`.
- Produces: `TrackpadPan.Phase.entryBegan`, `.entryProgress(CGFloat)`, `.entryEnded` (Sendable, Equatable). In swipeUp mode an upward swipe emits `.entryBegan` once, then `.entryProgress(t)` per frame (`t∈[0,1]`), then `.entryEnded` on lift. Tap mode `.seeAll` and horizontal/diagonal/down pan unchanged. New constant `TrackpadPan.entryDistance: CGFloat = 0.30` (tunable). New recognizer state `entryActive: Bool`.

- [ ] **Step 1: Write the failing tests**

In `TrackpadRecognizerTests.swift`, replace the three swipe-up `.seeAll` assertions (tests at :92, :100, :109) and add new ones. Keep the `touch(_:interval:swipeUp:)` helper. The swipe-up tests become:

```swift
func testWithSwipeUpChosenAQuickStrokeUpBeginsEntryAndEndsIt() {
    let phases = touch(line(from: CGPoint(x: 0.5, y: 0.2), to: CGPoint(x: 0.51, y: 0.5)), swipeUp: true)
    XCTAssertEqual(phases.first, .began)
    XCTAssertEqual(phases.last, .entryEnded)
    XCTAssertEqual(phases.filter { $0 == .entryBegan }.count, 1)
    XCTAssertFalse(phases.contains(.seeAll))
    XCTAssertFalse(phases.contains(.ended))
    XCTAssertTrue(phases.contains { if case .entryProgress = $0 { true } else { false } })
}

func testWithSwipeUpChosenASlowSwipeUpStillBeginsEntry() {
    let phases = touch(line(from: CGPoint(x: 0.5, y: 0.1), to: CGPoint(x: 0.5, y: 0.8), steps: 30), interval: 0.1, swipeUp: true)
    XCTAssertEqual(phases.filter { $0 == .entryBegan }.count, 1)
    XCTAssertEqual(phases.last, .entryEnded)
}

func testEntryProgressRisesFromZeroToOneAndClamps() {
    // dragOrigin y=0.2; recognition at rise 0.12 (t=0); full at rise 0.30 (t=1); past stays 1.
    let phases = touch(line(from: CGPoint(x: 0.5, y: 0.2), to: CGPoint(x: 0.5, y: 0.6), steps: 20), swipeUp: true)
    let ts = phases.compactMap { if case .entryProgress(let t) = $0 { t } else { nil } }
    XCTAssertEqual(ts.first, 0, accuracy: 0.001)
    XCTAssertEqual(ts.last, 1, accuracy: 0.001)
    XCTAssertTrue(zip(ts, ts.dropFirst()).allSatisfy { $0 <= $1 + 0.001 })  // monotonic up
    XCTAssertTrue(ts.allSatisfy { $0 >= 0 && $0 <= 1 })
}

func testEntryProgressScrubsBackWhenTheFingerReturns() {
    let up = line(from: CGPoint(x: 0.5, y: 0.2), to: CGPoint(x: 0.5, y: 0.45), steps: 10)
    let down = line(from: CGPoint(x: 0.5, y: 0.45), to: CGPoint(x: 0.5, y: 0.25), steps: 10)
    let ts = touch(up + down, swipeUp: true).compactMap { if case .entryProgress(let t) = $0 { t } else { nil } }
    XCTAssertGreaterThan(ts.max() ?? 0, ts.last ?? 1)  // came back down
}
```

Keep `testWithSwipeUpChosenATapDoesNothing`, `...HorizontalDragStillPans`, `...DiagonalDragStillPans` but change their `XCTAssertFalse(phases.contains(.seeAll))` to also assert `!phases.contains(.entryBegan)`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter TrackpadRecognizerTests 2>&1 | tail -30`
Expected: FAIL — `type 'TrackpadPan.Phase' has no member 'entryBegan'` (compile error), so the new tests cannot pass.

- [ ] **Step 3: Add the entry phases and recognizer logic**

In `TrackpadPan.Phase` add (keep `.seeAll` for tap mode):
```swift
/// Swipe-up entry recognized: the canvas comes up and the pull-back follows the finger.
case entryBegan
/// Swipe-up entry progress t∈[0,1], each frame after entryBegan until the fingers lift.
case entryProgress(CGFloat)
/// The entry swipe's fingers lifted; the controller commits or cancels from the last progress.
case entryEnded
```
Add constant `fileprivate static let entryDistance: CGFloat = 0.30` near `swipeDistance` (:47). Add `var entryActive = false` to `TrackpadRecognizer` state.

Replace the swipe-up block (:352-361) with: once recognized, stay in entry until lift, emitting progress measured from the recognition threshold so the canvas starts at the current camera (no jump):
```swift
if swipeUpSeesAll, let origin = dragOrigin, landedTogether {
    let rise = centroid.y - origin.y
    let run = abs(centroid.x - origin.x)
    let recognized = rise >= TrackpadPan.swipeDistance && atan2(rise, run) >= .pi / 2 - TrackpadPan.axisLock
    if recognized || entryActive {
        let span = TrackpadPan.entryDistance - TrackpadPan.swipeDistance
        let t = min(max((rise - TrackpadPan.swipeDistance) / span, 0), 1)
        let first = !entryActive
        entryActive = true
        last = centroid
        return phases + (first ? [.entryBegan, .entryProgress(t)] : [.entryProgress(t)])
    }
}
```
In `reset()` (:373) emit `.entryEnded` when entry was active, and clear `entryActive`:
```swift
let phases: [TrackpadPan.Phase] = entryActive ? [.entryEnded] : (last == nil ? [] : [.ended])
// ... existing clears ...
entryActive = false
```
The lift guard (:310-314) already calls `reset()`; in swipeUp mode its `tap` is false, so lift yields `[.entryEnded]`. Do not change tap mode or the pan path.

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter TrackpadRecognizerTests 2>&1 | tail -30`
Expected: PASS, all TrackpadRecognizerTests green.

- [ ] **Step 5: Commit**

```bash
git add Sources/Canvas/TrackpadPan.swift Tests/CanvasTests/TrackpadRecognizerTests.swift
git commit -m "feat: swipe-up emits continuous entry progress instead of discrete See All"
```

---

### Task 2: EntryFlight pure model

**Files:**
- Create: `Sources/Canvas/EntryFlight.swift`
- Test: `Tests/CanvasTests/EntryFlightTests.swift`

**Interfaces:**
- Consumes: `Camera` (`toWorld`), `CameraPath(from:to:viewSize:rho:)` + `.camera(at:)`, `FrameSnapshot` (`subscript(id)`, `hasSize`), `Handoff.flightRect` clamp convention.
- Produces:
  - `struct EntryFlight.Card { let from: CGPoint; let to: CGPoint }`
  - `static func cards(snapshot: FrameSnapshot, stored: [CGWindowID: CGRect], insets: [CGWindowID: CGFloat], camera: Camera) -> [CGWindowID: EntryFlight.Card]`
  - `static func origin(_ card: EntryFlight.Card, at t: CGFloat) -> CGPoint`
  - `static func committed(progress: CGFloat, threshold: CGFloat) -> Bool`
  - `static func velocity(_ samples: [(progress: CGFloat, time: CFTimeInterval)]) -> CGFloat`
  - `static let commitThreshold: CGFloat = 0.5` (tunable)

- [ ] **Step 1: Write the failing tests**

Create `EntryFlightTests.swift` (`import XCTest`, `@testable import Canvas`, `import CoreGraphics`). Build a `FrameSnapshot(frames:camera:)` with a 1:1 camera (`Camera(origin: .zero, zoom: 1)`) so world==screen.

```swift
func testCardsSelectsOnlyOnScreenWindowsWithAStoredPlace() {
    let snap = FrameSnapshot(frames: [1: CGRect(x: 100, y: 100, width: 400, height: 300),
                                      2: CGRect(x: 50, y: 50, width: 200, height: 200)],
                             camera: Camera(origin: .zero, zoom: 1))
    let stored: [CGWindowID: CGRect] = [1: CGRect(x: 1000, y: 1000, width: 400, height: 300),
                                        3: CGRect(x: 0, y: 0, width: 100, height: 100)]  // 3 off-screen
    let cards = EntryFlight.cards(snapshot: snap, stored: stored, insets: [1: 0, 2: 0], camera: Camera(origin: .zero, zoom: 1))
    XCTAssertEqual(cards.count, 1)                     // only 1: on-screen AND stored
    XCTAssertEqual(cards[1]?.from, CGPoint(x: 100, y: 100))
    XCTAssertEqual(cards[1]?.to, CGPoint(x: 1000, y: 1000))
}

func testCardsFromOriginUsesTheCameraAndInset() {
    let snap = FrameSnapshot(frames: [1: CGRect(x: 100, y: 100, width: 400, height: 300)],
                             camera: Camera(origin: CGPoint(x: 20, y: 30), zoom: 1))
    let stored: [CGWindowID: CGRect] = [1: CGRect(x: 1000, y: 1000, width: 400, height: 300)]
    let cam = Camera(origin: CGPoint(x: 20, y: 30), zoom: 1)
    let cards = EntryFlight.cards(snapshot: snap, stored: stored, insets: [1: 10], camera: cam)
    // content origin = (110,110); through camera = (90,80)
    XCTAssertEqual(cards[1]?.from, CGPoint(x: 90, y: 80))
}

func testCardsEmptyWhenNoWindowsOnScreen() {
    let snap = FrameSnapshot(frames: [:], camera: Camera(origin: .zero, zoom: 1))
    XCTAssertTrue(EntryFlight.cards(snapshot: snap, stored: [1: CGRect(x: 0, y: 0, width: 10, height: 10)], insets: [:], camera: Camera(origin: .zero, zoom: 1)).isEmpty)
}

func testOriginLerpsAndClampsPastTheEnds() {
    let card = EntryFlight.Card(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 100, y: 200))
    XCTAssertEqual(EntryFlight.origin(card, at: 0), CGPoint(x: 0, y: 0))
    XCTAssertEqual(EntryFlight.origin(card, at: 0.5), CGPoint(x: 50, y: 100))
    XCTAssertEqual(EntryFlight.origin(card, at: 1), CGPoint(x: 100, y: 200))
    XCTAssertEqual(EntryFlight.origin(card, at: 1.2), CGPoint(x: 100, y: 200))   // spring overshoot clamped
    XCTAssertEqual(EntryFlight.origin(card, at: -0.3), CGPoint(x: 0, y: 0))
}

func testCommittedAtOrAboveThreshold() {
    XCTAssertFalse(EntryFlight.committed(progress: 0.49, threshold: 0.5))
    XCTAssertTrue(EntryFlight.committed(progress: 0.5, threshold: 0.5))
    XCTAssertTrue(EntryFlight.committed(progress: 0.9, threshold: 0.5))
}

func testVelocityIsProgressPerSecondFromTheLastSamples() {
    let v = EntryFlight.velocity([(0.2, 0.0), (0.4, 0.1), (0.6, 0.2)])
    XCTAssertEqual(v, 2.0, accuracy: 0.001)   // ~0.4 progress over 0.2 s
    XCTAssertEqual(EntryFlight.velocity([]), 0)
    XCTAssertEqual(EntryFlight.velocity([(0.5, 0.0)]), 0)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter EntryFlightTests 2>&1 | tail -30`
Expected: FAIL — `cannot find 'EntryFlight' in scope`.

- [ ] **Step 3: Implement EntryFlight**

Create `Sources/Canvas/EntryFlight.swift` (`import CoreGraphics`). A pure enum/struct namespace; no AppKit. Signatures exactly as in Interfaces. Bodies:
- `cards`: for each `id` where `snapshot[id]` exists, `FrameSnapshot.hasSize(frame)`, and `stored[id]` exists: `let inset = insets[id] ?? 0; let content = frame.insetBy(dx: inset, dy: inset); from = camera.toWorld(content.origin); to = stored[id]!.origin`. Skip ids missing either side. (Mirrors `WindowProxy.worldRect(forReal:inset:camera:)` origin math; size is constant so only origins are carried.)
- `origin`: `let s = min(max(t, 0), 1); return CGPoint(x: from.x + (to.x - from.x) * s, y: from.y + (to.y - from.y) * s)`.
- `committed`: `progress >= threshold`.
- `velocity`: guard ≥2 samples; take the last up-to-3, `(last.progress - first.progress) / max(last.time - first.time, 1e-3)`; empty/single → 0.
- `commitThreshold = 0.5`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter EntryFlightTests 2>&1 | tail -30`
Expected: PASS, all EntryFlightTests green.

- [ ] **Step 5: Commit**

```bash
git add Sources/Canvas/EntryFlight.swift Tests/CanvasTests/EntryFlightTests.swift
git commit -m "feat: pure EntryFlight model (flight set, clamped origin lerp, commit policy, velocity)"
```

---

### Task 3: Gesture-driven entry camera (A1) + routing + reversible gate

**Files:**
- Modify: `Sources/Canvas/Settings.swift` (add `gestureEntry`), `Sources/Canvas/Desk.swift:207-231` (route entry phases), `Sources/Canvas/CanvasController.swift` (`trackpadPan` :1654-1696 + new entry orchestration; reuse `showCanvas`/`show`/`snapshot(at:)`/`view.overviewCamera`/`view.set(camera:)`/`view.fly`)
- Test: `Tests/CanvasTests/SettingsTests.swift` (gestureEntry default + round-trip)

**Interfaces:**
- Consumes: Task 1 `.entryBegan/.entryProgress/.entryEnded`; Task 2 `EntryFlight.commitThreshold`/`committed`/`velocity`; existing `CameraPath(from:to:viewSize:)`, `view.set(camera:)`, `view.fly(to:rho:step:completion:)`, `view.overviewCamera`, `snapshot(at:)`, `view.camera`, `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`.
- Produces: `Settings.gestureEntry: Bool` (get/set, key `CanvasGestureEntry`, default true, notification `gestureEntryDidChange`). Controller entry state: `entryPath: CameraPath?`, `entryStart: Camera`, `entryOverview: Camera`, `entrySamples: [(progress: CGFloat, time: CFTimeInterval)]`, `entryCameFromHidden: Bool`. New private methods `beginEntry()`, `driveEntry(_ t: CGFloat)`, `endEntry()`, `cancelEntry()`, `clearEntry()`.

- [ ] **Step 1: Write the failing test (Settings gate)**

In `SettingsTests.swift` add (mirror the existing `testSeeAllGestureDefaultsToSwipeUpAndRoundTrips` save/restore pattern):
```swift
func testGestureEntryDefaultsOnAndRoundTrips() async {
    await MainActor.run {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: "CanvasGestureEntry")
        defer { defaults.set(saved, forKey: "CanvasGestureEntry") }
        defaults.removeObject(forKey: "CanvasGestureEntry")
        XCTAssertTrue(Settings.gestureEntry)
        Settings.gestureEntry = false
        XCTAssertFalse(Settings.gestureEntry)
        Settings.gestureEntry = true
        XCTAssertTrue(Settings.gestureEntry)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SettingsTests 2>&1 | tail -20`
Expected: FAIL — `type 'Settings' has no member 'gestureEntry'`.

- [ ] **Step 3: Implement the Settings gate**

In `Settings.swift` add `static let gestureEntryKey = "CanvasGestureEntry"`, `static let gestureEntryDidChange = Notification.Name("CanvasGestureEntryDidChange")`, and a `static var gestureEntry: Bool` get/set mirroring `seeAllGesture` (:266) but defaulting `true` (`defaults.object(forKey:) == nil ? true : defaults.bool(forKey:)`), posting the notification on set. Doc comment: "Swipe-up drives the pull-back and cards fly from their real places; off, entry is the plain See All flight."

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter SettingsTests 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Route the entry phases (Desk)**

In `Desk.trackpadPan` (:207) add cases routing like `.seeAll` to the panning canvas (the swipe began on it), clearing `panning` on end:
```swift
case .entryBegan, .entryProgress:
    (panning ?? pointed).trackpadPan(phase)
case .entryEnded:
    (panning ?? pointed).trackpadPan(phase)
    panning = nil
```

- [ ] **Step 6: Wire the controller entry orchestration (A1 camera)**

In `CanvasController.trackpadPan` add cases (gate on `Settings.gestureEntry`; when off, fall through to the existing `.seeAll`-style `showCanvas(fitAll:true, seeAll:true)` so the gate is a true fallback):
- `.entryBegan`: if `!Settings.gestureEntry` → `showCanvas(fitAll:true, seeAll:true)`; return. Else record `entryCameFromHidden = !NSApp.isActive`; bring the canvas forward if hidden (`show()`); `beginEntry()`.
- `.entryProgress(let t)`: `driveEntry(t)`.
- `.entryEnded`: `endEntry()`.

`beginEntry()`: `entryStart = view.camera`; guard `let overview = view.overviewCamera` else `clearEntry()` + plain show (Review Focus 1); `entryOverview = overview`; `entryPath = CameraPath(from: entryStart, to: overview, viewSize: view.bounds.size)`; `entrySamples = []`; `view.set(camera: entryStart)`. (Card flight set is added in Task 4.)

`driveEntry(t)`: guard `let path = entryPath`; `view.set(camera: path.camera(at: t))`; append `(t, CACurrentMediaTime())` to `entrySamples` (keep last ~5).

`endEntry()`: guard path; `let t = entrySamples.last?.progress ?? 0`; `let commit = EntryFlight.committed(progress: t, threshold: EntryFlight.commitThreshold)`; `let v = EntryFlight.velocity(entrySamples)`; if Reduce Motion → `view.set(camera: commit ? entryOverview : entryStart)` + `clearEntry()` (Review Focus 5); else `view.fly(to: commit ? entryOverview : entryStart, step: { [weak self] p in self?.driveEntryFlight(p) }, completion: { [weak self] in self?.finishEntry(committed: commit) })`. `driveEntryFlight` is the card step (Task 4); for Task 3 it is a no-op stub to be filled. `finishEntry(committed:)`: if `!committed && entryCameFromHidden` → hide the canvas again (`mapDidHide`/orderOut path used by the existing return); `clearEntry()`.

`cancelEntry()`/`clearEntry()`: nil out `entryPath`/samples. Any manual pan/zoom/click while `entryPath != nil` calls `clearEntry()` after committing the camera to overview (Review Focus 4 — wire into the existing pan/zoom/click entry points; the flight's `onAnimationCancelled` also clears).

Idempotent (Q4): in `.entryBegan`, if `view.camera.isClose(to: view.overviewCamera ?? view.camera)` and canvas already active → `view.fitAll(animated: true)` (re-fit, no entry state) instead of `beginEntry()`.

Non-gesture entry (A1.4): the existing `.seeAll` (tap) and hotkey/menu `showCanvas(fitAll:true)` path — change `view.fitAll(animated:true)`'s call site for See All to `view.fly(to: overview)` when `Settings.gestureEntry` (retargetable spring), keeping `animateCamera` when the gate is off. (Locate the `fitAll(animated:true)` See All call in `showCanvas` :1468 and the first-sync hooks; route through `fly`.)

- [ ] **Step 7: Build + full suite**

Run: `swift build 2>&1 | tail -20` then `swift test 2>&1 | tail -25`
Expected: build succeeds, no new warnings; full suite green (TrackpadRecognizerTests + EntryFlightTests + SettingsTests + all existing). The gesture-driven camera feel is glue — verified on real device, not unit-tested (convention).

- [ ] **Step 8: Commit**

```bash
git add Sources/Canvas/Settings.swift Sources/Canvas/Desk.swift Sources/Canvas/CanvasController.swift Tests/CanvasTests/SettingsTests.swift
git commit -m "feat: gesture-driven entry camera with reversible gate and spring release (A1)"
```

---

### Task 4: Per-card fly from real positions (A2)

**Files:**
- Modify: `Sources/Canvas/CanvasController.swift` (entry orchestration from Task 3: add flight set + card driving + off-screen fade + interrupt finalize)
- Test: pure geometry already covered by `EntryFlightTests` (Task 2); card orchestration is glue (build + real-device verified).

**Interfaces:**
- Consumes: Task 2 `EntryFlight.cards(snapshot:stored:insets:camera:)` / `.origin(_:at:)`; Task 3 entry state + `beginEntry`/`driveEntry`/`endEntry`; `snapshot(at:)`, `proxies` (`worldRect`, `inset`, `windowID`, `kind`, `pip`, `standsAlone`), `WindowProxy.place(at:)`, `view.setArrival(of:context:neighbour:)`, `Handoff.flightRect`.
- Produces: controller `entryCards: [(proxy: WindowProxy, card: EntryFlight.Card)]`; filled `driveEntryFlight(_ p: CGFloat)`; flight-set capture in `beginEntry`; off-screen fade; interrupt finalize.

- [ ] **Step 1: Capture the flight set in beginEntry**

After `entryPath` is set in `beginEntry()`: `let snap = snapshot(at: entryStart)` (fresh real frames, Q1); build `stored = Dictionary(uniqueKeysWithValues: proxies.values.filter { $0.kind == .window }.map { ($0.windowID, $0.worldRect) })` and `insets = ...map { ($0.windowID, $0.inset) }`; `let cards = EntryFlight.cards(snapshot: snap, stored: stored, insets: insets, camera: entryStart)`; `entryCards = cards.compactMap { (id, card) in proxies[id].map { (proxy: $0, card: card) } }`. For each flying card, place it at its `from` origin now (`proxy.place(at: card.from)`) so t=0 shows the real stacked position (Q3). PiP (`pip != nil`) and widgets are excluded by `kind == .window` + the snapshot intersection; attached children ride automatically via `worldRect.didSet` (Q7).

- [ ] **Step 2: Drive the cards during the gesture**

In `driveEntry(t)` (Task 3), after setting the camera: `for (proxy, card) in entryCards { proxy.place(at: EntryFlight.origin(card, at: t)) }`. Cards whose proxy is gone are skipped (entryCards holds strong refs; if a window closed, its proxy may be removed from `proxies` — guard `proxies[proxy.windowID] != nil` before placing, Review Focus 2).

- [ ] **Step 3: Off-screen cards fade in at their stored place**

For windows with a stored place but NOT in the flight set (off-screen/minimized at entry): `view.setArrival(of: proxy, context: WindowEffect.Context(source: nil))` so they fade in at their stored place rather than fly (Q3, reuse the existing opening effect). Do this once in `beginEntry` for `proxies.values.filter { $0.kind == .window && $0.pip == nil && cards[$0.windowID] == nil }`.

- [ ] **Step 4: Re-base cards on release and ride the spring**

Fill `driveEntryFlight(_ p: CGFloat)` (the `fly` step stub from Task 3): the cards' `from` was re-based at release to their current origin and `to` is stored (commit) or the original real `from` (cancel). Implement by storing `entryReleaseCards: [(proxy, from: CGPoint, to: CGPoint)]` computed in `endEntry()` before calling `fly`: for each entryCard, `from = proxy.worldRect.origin`, `to = commit ? card.to : card.from`. Then `driveEntryFlight(p)` places each at `EntryFlight.origin(Card(from:to:), at: p)` (clamped, so the camera's ~4% overshoot never breathes a card past its end — Q6). `finishEntry(committed:)` places each card exactly at its `to` and clears `entryCards`/`entryReleaseCards`.

- [ ] **Step 5: Interrupt finalize**

Ensure any interrupt during entry (manual pan/zoom/click, or `view.onAnimationCancelled`) places every entryCard at its committed target (`card.to`) and clears entry state, so no card is stuck mid-air (Review Focus 4). Reuse `interruptMotion()` for the camera; the card finalize is the controller's `clearEntry()` extended to place cards at `card.to` first.

- [ ] **Step 6: Build + full suite**

Run: `swift build 2>&1 | tail -20` then `swift test 2>&1 | tail -25`
Expected: build succeeds, no new warnings; full suite green. Per-card fly feel (no 分裂感, minimal motion, cards land with the camera) is glue — real-device verified, not unit-tested.

- [ ] **Step 7: Commit**

```bash
git add Sources/Canvas/CanvasController.swift
git commit -m "feat: cards fly from real stacked positions to stored places on entry (A2)"
```

---

## Notes for the executor

- After Task 1 lands and before Task 3, swipe-up entry is temporarily inert in the app (recognizer emits entry phases the controller doesn't yet handle). This is expected mid-plan on a feature branch; the app is not released until the whole plan is done and real-device accepted. Tap mode and pan are unaffected throughout.
- Tunables (real-device, do not fabricate feel claims): `TrackpadPan.entryDistance` (0.30), `EntryFlight.commitThreshold` (0.5), release velocity sample window (~5), spring `response`/`damping` (reuse 0.45/0.72). Adjust only against real-device observation, ledger each change.
- Each task: RED→GREEN→full `swift test`; ledger the result + any Ruling in `docs/superpowers/2026-11-11-tablecloth-ledger.md`; commit + push origin only. Solidify a handoff node at A-complete (ledger + this plan's checkboxes + push) so another agent can resume.
- Real-device acceptance (user): swipe-up follows the hand with no fixed-timer lag; visible windows fly from their real places (no 分裂感); release springs smoothly; cancel returns; low usage via PerfLog (no fabricated numbers). ad-hoc rebuild requires re-granting Accessibility + Screen Recording.