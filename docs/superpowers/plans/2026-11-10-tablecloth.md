# Tablecloth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Sunlight fork 改造成 Tablecloth：快照地图式无限画布，RTS 游戏相机与单位式窗口选择，点击聚焦充满屏幕，零 SIP 改动、零常驻捕获流、三低资源。

**Architecture:** 复用上游捕获渲染器（强制 `.capture`、零流纯快照），画布改不透明全屏窗口让 WindowServer 遮挡停绘后方应用；聚焦/返回复用上游 handoff + van Wijk 相机弧线，目标矩形改为主屏 visibleFrame；游戏化反馈（悬停上浮、兵牌、脉冲环、书签、提示条）全部是事件驱动 CA 动画。持久化复用上游 `Layouts`（bundleID+标题+windowID 匹配、跨启动记忆），书签作为 `Layout` 新可选字段——不另建 spec 部件 2 的 `Layout.json`，上游存储已覆盖其职责（实现者对 spec 的一处偏离，在此声明）。

**Tech Stack:** Swift（language mode 5）、SwiftPM、AppKit、Core Animation、ScreenCaptureKit（仅一次性截图）、XCTest（`@testable import Canvas`）。

**Spec:** `docs/superpowers/specs/2026-11-10-tablecloth-design.md`（含「游戏化交互与视效」追加章节，执行者两个文件都要读）

## Global Constraints

- 不关闭 SIP，不做任何 SIP 相关改动；不注入系统进程；不改任何系统偏好（无 takeover）。
- 无常驻捕获流：SCK stream / CGDisplayStream 一律不用；`maxStreams` 必须为 0。私有 API 仅作可选加速且必须有公开兜底（上游 SkyLight→SCK 降级链保持）。
- 只需两个权限：辅助功能、屏幕录制。
- macOS 15+，Apple Silicon；目标机器 MacBook Air M2，macOS 27.2。
- 资源目标：地图静止 CPU ≈ 0；典型内存 < 100MB；聚焦模式开销 ≈ 0；快照纹理最长边 ≤ 1024px。
- 每秒轮换刷新默认关闭；锁屏/睡眠/地图隐藏时完全不捕获。
- 绝不用 AX resize 模拟缩放；resize 只发生在真实聚焦时；应用钳制 resize 时接受实际落点，不重试死循环。
- 许可证：只改编 MIT（Sunlight/orcv）代码并保留上游署名；不复制 canvasWM/minfwm 代码。
- 开发经 GitHub：`cyancloudyang/sunlight`，`tablecloth` 分支；只 push origin（用户的 fork），绝不 push upstream。
- 菜单栏与 Dock 保持可见可用；地图失焦自动隐藏，热键召回。
- 测试：XCTest，`swift test --filter <Suite>`；纯逻辑必须单元测试，手势与 handoff 动画真机验证。

## Review Focus

1. **权限被拒/事后撤销** → 引导页而非黑屏崩溃；捕获失败留旧纹理/占位，不崩溃不空转（Task 1 引导门控测试；Task 3 隐藏/停捕获测试）。
2. **聚焦飞行途中窗口关闭/最小化** → handoff 中止，不激活死窗、不残留快照（Task 4 `Handoff.outcome` 测试 + 真机验证）。
3. **应用钳制 AX resize（最小尺寸/固定比例）** → 交叉淡入对齐实际 frame 而非请求 frame，无黑边、不重试（Task 4 `Handoff.seamRect` 测试）。
4. **同 app 同标题多窗口重启后匹配** → 确定性消歧，布局不串位（Task 8 匹配测试）。
5. **锁屏/睡眠/地图隐藏时** → 捕获与刷新计时器全停，唤醒/召回后恢复，无后台 CPU（Task 3 `RefreshPolicy` 测试 + Task 9 Activity Monitor 实测）。

---

## 背景：执行者必须知道的现状

- 仓库：`/Users/cycloudyang/Documents/Qoder/2026-11-10/4aceb90d/sunlight`，当前在 `main`，`docs/superpowers/` 未跟踪。origin = 用户 fork，upstream = 上游（只 fetch 不 push）。
- `Sources/Canvas/CanvasController.swift` 约 8000 行，是核心控制器；`CanvasView.swift` 约 3100 行，是画布视图。改动前先读目标函数的上下文。
- 上游已有可复用系统（spec「游戏化交互与视效」末尾清单）：MinimapPanel、hudZoom、hovered 边框、label/pill、canvas toast、CameraPath、GestureGuide、Layouts、NewWindowSpot、onSettle、handingOff。**优先扩展，不另造。**
- 测试基线：Task 1 第一步先跑 `swift test` 全绿基线；若有先于本计划的失败，记录并跳过相关套件，不修无关代码。

### Task 1: Tablecloth 默认值——纯快照、零流、引导只问两个权限

**Files:**
- Modify: `Sources/Canvas/Settings.swift:12-21`（renderer）、`:589`（capturesStream）
- Modify: `Sources/Canvas/Setup/SetupStatus.swift`（items 的 required 标志）
- Modify: `Sources/Canvas/Setup/SetupFlow.swift`（rail 去掉 live windows 入口）
- Modify: `Sources/Canvas/CanvasController.swift:833`（updatePreviewBadge）及 PreviewBadge 引用点
- Delete: `Sources/Canvas/Setup/PreviewBadge.swift`（若无其他引用）
- Test: `Tests/CanvasTests/SettingsTests.swift`、`SetupStatusTests.swift`、`SetupFlowTests.swift`、`PreviewModeTests.swift`、`StreamLimitTests.swift`

**Interfaces:**
- Consumes: 上游 `Settings.renderer` / `.capturesStream` / `.previewMode`、`SetupStatus.items/missing/isComplete`、`SetupFlow.rail/opensAtLaunch`、`CanvasController.maxStreams`（`:5701`）。
- Produces: `Settings.renderer` 恒 `.capture`；`Settings.capturesStream` 恒 `false`；`SetupStatus.isComplete == accessibility && screenRecording`；rail 无 live windows 页面；无 preview badge。后续所有任务依赖"renderer 恒 capture、零流"这一事实。

- [ ] **Step 1: 建分支并提交文档**

```bash
git checkout -b tablecloth
git add docs/superpowers/specs/2026-11-10-tablecloth-design.md docs/superpowers/plans/2026-11-10-tablecloth.md
git commit -m "docs: Tablecloth design spec and implementation plan"
```

- [ ] **Step 2: 跑测试基线**

Run: `swift test`
Expected: 全绿（或记录先于本计划的失败套件并跳过）。

- [ ] **Step 3: 写失败测试**

SettingsTests 增加：

```swift
func testRendererIsAlwaysCapture() {
    XCTAssertEqual(Settings.renderer, .capture)
}
func testNeverStreams() {
    XCTAssertFalse(Settings.capturesStream)
    XCTAssertEqual(CanvasController.maxStreams, 0)
}
```

SetupStatusTests 增加（构造：SIP 全开、无 helper、bootArgument false、liveWindowsLoaded false）：

```swift
func testCompleteWithTwoPermissionsOnly() {
    var status = SetupStatus()  // 按现有测试的构造方式初始化
    status.accessibility = true
    status.screenRecording = true
    XCTAssertTrue(status.isComplete)
    XCTAssertTrue(status.missing.isEmpty)
}
func testScreenRecordingIsRequired() {
    var status = SetupStatus()
    status.accessibility = true
    status.screenRecording = false
    XCTAssertFalse(status.isComplete)
    XCTAssertEqual(status.missing.map(\.step), [.screenRecording])
}
```

SetupFlowTests 增加：rail 的任何 entry 都不含 live-windows 页面（`.helper/.systemIntegrity/.bootArgument/.liveWindows` 对应的 Page，按现有枚举名断言）；`opensAtLaunch` 在 record 完成且两权限授予时为 false。
PreviewModeTests/StreamLimitTests：把断言"preview/screenCapture 会流式"的旧用例改为断言零流。

- [ ] **Step 4: 跑测试确认失败**

Run: `swift test --filter SettingsTests && swift test --filter SetupStatusTests && swift test --filter SetupFlowTests`
Expected: 新用例 FAIL（renderer 默认值、required 标志尚为旧行为）。

- [ ] **Step 5: 实现默认值**

- `Settings.renderer` getter 改为恒 `return .capture`；删除 setter 与 `CanvasRenderer` 存取，编译错误引导到设置 UI 的渲染器选择器——一并移除该选择器（grep `Settings.renderer =` 与 `CanvasRenderer`）。`Renderer` 枚举本身保留（代码仍按它分支）。
- `Settings.capturesStream` 改为恒 `false`（注释一句：Tablecloth 是快照地图，永不流式）。`previewMode` 保持原样——它仍驱动首启引导流程，但不再意味流式。
- `SetupStatus.items`：`screenRecording` 改 `required: true`；helper/systemIntegrity/bootArgument/liveWindows 四步改 `required: false`。
- `SetupFlow.rail`：去掉 live windows 折叠入口及其页面（grep `startedLive` 在 rail 里的分支）。
- 删除 preview badge：`updatePreviewBadge` 及其调用点、`PreviewBadge.swift`（确认无其他引用后删文件）；菜单/demo 卡里"升级 live windows"入口一并移除（grep `show(startingLive:` 调用点）。

- [ ] **Step 6: 跑测试确认通过**

Run: `swift test`
Expected: 全绿（基线中记录的既有失败除外）。

- [ ] **Step 7: Commit**

```bash
git add -A Sources/Canvas Tests/CanvasTests
git commit -m "feat: Tablecloth defaults — snapshot-only renderer, zero streams, two-permission setup"
```

### Task 2: 不透明画布 + 召唤式隐现

**Files:**
- Create: `Sources/Canvas/SummonPolicy.swift`
- Modify: `Sources/Canvas/CanvasController.swift:347-348`（isOpaque/backgroundColor）、`:500-527`（didResignActive）
- Modify: `Sources/Canvas/CanvasView.swift:669`（背景 alpha）
- Modify: 应用 Info.plist（grep `LSUIElement` / `Info.plist` 定位；无 Dock 图标）
- Test: `Tests/CanvasTests/SummonPolicyTests.swift`（新建）

**Interfaces:**
- Consumes: 上游 `handingOff` 标志（CanvasController:144）、`toggle()`（:1547）、`showCanvas(fitAll:)`（:1381）、F3/Mission Control 键处理（:7326 附近）。
- Produces: `SummonPolicy.hidesOnResign(frontIsSelf:handoffInFlight:) -> Bool`（`= !frontIsSelf && !handoffInFlight`）；画布不透明；地图失焦自动 orderOut、热键召回。Task 3 的计时器停止、Task 4 的飞行中不隐藏依赖此行为。

- [ ] **Step 1: 写失败测试**

```swift
final class SummonPolicyTests: XCTestCase {
    func testHidesOnlyWhenForeignFrontAndNoHandoff() {
        XCTAssertTrue(SummonPolicy.hidesOnResign(frontIsSelf: false, handoffInFlight: false))
        XCTAssertFalse(SummonPolicy.hidesOnResign(frontIsSelf: true, handoffInFlight: false))
        XCTAssertFalse(SummonPolicy.hidesOnResign(frontIsSelf: false, handoffInFlight: true))
        XCTAssertFalse(SummonPolicy.hidesOnResign(frontIsSelf: true, handoffInFlight: true))
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --filter SummonPolicyTests`
Expected: FAIL，`SummonPolicy` 不存在（编译错误）。

- [ ] **Step 3: 实现**

- 新建 `SummonPolicy.swift`，如上签名。
- CanvasController:347-348：`window.isOpaque = true`；`window.backgroundColor` 设为画布当前背景色（与 CanvasView:669 使用的 `background` 同源，避免浅色模式白闪）。
- CanvasView:669：`showsRealWindows` 分支已不可达（renderer 恒 capture），简化为背景色 alpha 恒 1.0。
- didResignActive 处理器：取 frontmostApplication 后，若 `SummonPolicy.hidesOnResign(frontIsSelf: front?.processIdentifier == myPID, handoffInFlight: handingOff)` 为真 → 画布 orderOut（走现有隐藏/收起路径，保持状态一致），并停止刷新计时器（Task 3 接入 `ensureRefreshTimer` 的停止分支；本任务先留 TODO 钩子函数 `mapDidHide()`）。
- 确认 F3/Mission Control 键与菜单开关在画布 orderOut 后仍能召回（上游 toggle 路径，真机验证）。
- Info.plist 设 `LSUIElement = true`（spec：无 Dock 图标）；真机确认聚焦激活其他应用、地图召回均不受影响（accessory app 仍可激活窗口）。

- [ ] **Step 4: 跑测试确认通过**

Run: `swift test --filter SummonPolicyTests && swift build`
Expected: PASS + 构建成功。

- [ ] **Step 5: 真机验证遮挡红利**

跑起应用，开地图盖住一个活动窗口（如播放中的浏览器视频页），Activity Monitor 观察该应用 CPU 应明显下降（WindowServer 遮挡停绘）；点击其他应用，地图自动隐藏；F3 召回。

- [ ] **Step 6: Commit**

```bash
git add Sources/Canvas/SummonPolicy.swift Sources/Canvas/CanvasController.swift Sources/Canvas/CanvasView.swift Tests/CanvasTests/SummonPolicyTests.swift
git commit -m "feat: opaque canvas for occlusion throttling, summon-style hide on focus loss"
```

### Task 3: 零后台捕获的刷新策略

**Files:**
- Create: `Sources/Canvas/RefreshPolicy.swift`
- Modify: `Sources/Canvas/Settings.swift`（新开关）、`Sources/Canvas/CanvasController.swift:2854-2868`（refreshTick）、`:410`（onSettle）、`:1381`（showCanvas）、`:5604` 附近（returnedToCanvas）
- Test: `Tests/CanvasTests/RefreshPolicyTests.swift`（新建）、`Tests/CanvasTests/SettingsTests.swift`

**Interfaces:**
- Consumes: Task 2 的 `mapDidHide()`；上游 `ensureRefreshTimer()`、`WindowProxy.refresh(seam:)`、`view.onSettle`（相机停稳回调，现接 snapToWindow）、`handoffTarget`。
- Produces:

```swift
enum RefreshPolicy {
    enum Event { case mapShown, cameraSettled, focusReturned, tick }
    enum Action { case refreshVisible, refreshPrimary, rotateOne }
    static func actions(for event: Event, mapVisible: Bool, rotationEnabled: Bool,
                        handoffInFlight: Bool) -> [Action]
}
```

规则：`!mapVisible` → `[]`；`.mapShown`/`.cameraSettled` → `[.refreshVisible]`；`.focusReturned` → `[.refreshPrimary]`；`.tick` → handoffInFlight 时 `[.refreshPrimary]`（seam 帧），否则 rotationEnabled 时 `[.rotateOne]`，否则 `[]`。
`Settings.snapshotRotation: Bool`（UserDefaults key `TableclothSnapshotRotation`，默认 **false**）。

- [ ] **Step 1: 写失败测试**

```swift
final class RefreshPolicyTests: XCTestCase {
    func testHiddenMapNeverCaptures() {
        for event in [RefreshPolicy.Event.mapShown, .cameraSettled, .focusReturned, .tick] {
            XCTAssertTrue(RefreshPolicy.actions(for: event, mapVisible: false,
                                                rotationEnabled: true, handoffInFlight: true).isEmpty)
        }
    }
    func testEntryAndSettleRefreshVisible() {
        XCTAssertEqual(RefreshPolicy.actions(for: .mapShown, mapVisible: true,
                                             rotationEnabled: false, handoffInFlight: false), [.refreshVisible])
        XCTAssertEqual(RefreshPolicy.actions(for: .cameraSettled, mapVisible: true,
                                             rotationEnabled: false, handoffInFlight: false), [.refreshVisible])
    }
    func testReturnRefreshesPrimary() {
        XCTAssertEqual(RefreshPolicy.actions(for: .focusReturned, mapVisible: true,
                                             rotationEnabled: false, handoffInFlight: false), [.refreshPrimary])
    }
    func testIdleTickWithRotationOffDoesNothing() {
        XCTAssertTrue(RefreshPolicy.actions(for: .tick, mapVisible: true,
                                            rotationEnabled: false, handoffInFlight: false).isEmpty)
    }
    func testRotationAndHandoffTicks() {
        XCTAssertEqual(RefreshPolicy.actions(for: .tick, mapVisible: true,
                                             rotationEnabled: true, handoffInFlight: false), [.rotateOne])
        XCTAssertEqual(RefreshPolicy.actions(for: .tick, mapVisible: true,
                                             rotationEnabled: false, handoffInFlight: true), [.refreshPrimary])
    }
    func testRotationDefaultsOff() {
        UserDefaults.standard.removeObject(forKey: "TableclothSnapshotRotation")
        XCTAssertFalse(Settings.snapshotRotation)
    }
}
```

（Action 需 `Equatable`；Event 数组字面量若编译受限就逐个断言。）

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --filter RefreshPolicyTests`
Expected: FAIL，类型不存在。

- [ ] **Step 3: 实现并接线**

- 新建 `RefreshPolicy.swift` 按上述规则；`Settings.snapshotRotation` 读写 UserDefaults，默认 false。
- `refreshTick()` 改为：`RefreshPolicy.actions(for: .tick, ...)` 驱动——`.refreshPrimary` 走现有 primary/seam 刷新（保留 handoffTarget 的 seam 逻辑），`.rotateOne` 走现有 %4 轮换，空数组直接 return。计时器由 `ensureRefreshTimer()` 保证只在地图可见时运行；Task 2 的 `mapDidHide()` 里停表，showCanvas 里重启。
- `showCanvas(fitAll:)` → 执行 `.mapShown` 动作（刷新所有 inView 代理各一次）；`view.onSettle` 在现有 snapToWindow 之后追加 `.cameraSettled` 动作；`returnedToCanvas()` → `.focusReturned`（立即刷新刚回来的窗）。
- 菜单栏加"每秒轮换快照"开关（grep 菜单构建处，绑定 `Settings.snapshotRotation`）。
- 锁屏/睡眠接线：`NSWorkspace.sessionDidResignActiveNotification` / `screensDidSleepNotification` → 停表（同 `mapDidHide()`）；`sessionDidBecomeActive` / `screensDidWake` → 地图仍可见则重启计时器并补一次 `.mapShown` 刷新。决策侧已由 `mapVisible == false → []` 的测试钉死，接线真机验证。
- 捕获失败处理确认：一次性捕获失败时保留旧纹理/占位（上游 OneShotCapture 失败路径），不重试空转。

- [ ] **Step 4: 跑测试确认通过**

Run: `swift test --filter RefreshPolicyTests && swift test --filter SettingsTests && swift build`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add Sources/Canvas/RefreshPolicy.swift Sources/Canvas/Settings.swift Sources/Canvas/CanvasController.swift Tests/CanvasTests
git commit -m "feat: event-driven snapshot refresh, rotation off by default, zero capture when hidden"
```

### Task 4: 聚焦=俯冲充满屏幕，返回=拉升回原位

**Files:**
- Modify: `Sources/Canvas/Positioning/Handoff.swift`（Placement、plan、新纯函数）
- Modify: `Sources/Canvas/CanvasController.swift:4673`（handoff(to:)）、`:5438`（enter）、`:5604`（returnedToCanvas）
- Test: `Tests/CanvasTests/HandoffTests.swift`

**Interfaces:**
- Consumes: 上游 `Placement`/`Plan`/`Handoff.plan(_:rect:camera:visible:scale:tiledArea:)`、`pixelAligned`、`cameraAligning`、`view.animateCamera(to:duration:completion:)`（CanvasView:1224）、`CameraPath`（van Wijk 弧线）、Task 2 的 `handingOff` 联动。
- Produces: `Placement.fillScreen`；`Handoff.outcome(windowAlive:) -> HandoffOutcome`（`.completed`/`.abortedWindowGone`）；`Handoff.seamRect(actualFrame:requested:) -> CGRect`（恒返回 actualFrame——交叉淡入对齐应用实际落点）；控制器内 `focusSavedFrame: CGRect?`（聚焦前真实 frame，返回时恢复）。Task 5 的返回脉冲环挂在 returnedToCanvas 同一钩子。

- [ ] **Step 1: 写失败测试**

HandoffTests 增加（沿用现有测试的 plan 调用构造）：

```swift
func testFillScreenPlanUsesVisibleFrame() {
    let visible = CGRect(x: 0, y: 25, width: 1440, height: 875)
    let rect = CGRect(x: 2000, y: -1500, width: 900, height: 600)
    let plan = Handoff.plan(.fillScreen, rect: rect, camera: Camera(), visible: visible,
                            scale: 1, tiledArea: visible)
    XCTAssertEqual(plan.origin, visible.origin)  // pixelAligned 后仍重合
    // 相机把 worldRect 中心对准屏幕中心
    XCTAssertEqual(plan.camera.center(viewSize: visible.size).x, rect.midX, accuracy: 1)
    XCTAssertEqual(plan.camera.center(viewSize: visible.size).y, rect.midY, accuracy: 1)
}
func testOutcomeAbortsWhenWindowGone() {
    XCTAssertEqual(Handoff.outcome(windowAlive: false), .abortedWindowGone)
    XCTAssertEqual(Handoff.outcome(windowAlive: true), .completed)
}
func testSeamUsesActualFrameNotRequested() {
    let requested = CGRect(x: 0, y: 25, width: 1440, height: 875)
    let clamped = CGRect(x: 0, y: 25, width: 1024, height: 640)
    XCTAssertEqual(Handoff.seamRect(actualFrame: clamped, requested: requested), clamped)
}
```

（`HandoffOutcome` 需 Equatable；plan 的确切参数标签以现有签名/现有测试为准。）

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --filter HandoffTests`
Expected: FAIL，`fillScreen`/`outcome`/`seamRect` 不存在。

- [ ] **Step 3: 实现**

- `Placement` 加 `case fillScreen`；`plan` 对应分支：真实目标 frame = visible（pixelAligned），相机 = cameraAligning(rect 中心 → visible 中心, zoom 1)。
- `Handoff.outcome`/`Handoff.seamRect` 按 Produces 实现。
- `handoff(to:)`：placement 改 `.fillScreen`；开始时保存该窗当前真实 frame 到 `focusSavedFrame`；飞行完成回调里先查 `Handoff.outcome(windowAlive:)`——窗口已 gone 则中止（清理快照层、复位 handingOff、不激活）；存活则 AX move/resize 到 visible，**读回实际 frame**，快照末态/交叉淡入用 `seamRect(actualFrame:requested:)` 对齐，再走现有 enter/激活路径。飞行用现有相机动画（van Wijk 弧线），时长沿用 `CanvasView.cameraDuration`。
- `returnedToCanvas()`：若 `focusSavedFrame` 有值，AX 恢复该 frame（在地图飞行背后完成），清空；随后走 Task 3 的 `.focusReturned` 刷新。
- 全程 `handingOff = true`，Task 2 保证飞行中地图不自动隐藏。

- [ ] **Step 4: 跑测试确认通过**

Run: `swift test --filter HandoffTests && swift build`
Expected: PASS。

- [ ] **Step 5: 真机验证**

点击地图窗口：快照平滑俯冲放大至全屏、交叉淡入真窗口，无黑帧/闪烁/露出桌面；对一个有最小尺寸限制的窗口（如系统设置）聚焦：接受实际尺寸，无黑边无重试；F3 返回：窗口飞回地图原位，真实窗口恢复聚焦前 frame；飞行途中 ⌘W 关掉目标窗：无崩溃、无幽灵快照。

- [ ] **Step 6: Commit**

```bash
git add Sources/Canvas/Positioning/Handoff.swift Sources/Canvas/CanvasController.swift Tests/CanvasTests/HandoffTests.swift
git commit -m "feat: fill-screen focus handoff with swoop flight, frame restore on return"
```

### Task 5: 单位式选择反馈——悬停上浮、兵牌、脉冲环、光标

**Files:**
- Create: `Sources/Canvas/SelectionFeedback.swift`
- Modify: `Sources/Canvas/WindowProxy.swift:308-315`（hovered didSet）、`Sources/Canvas/CanvasView.swift:2248`（mouseMoved）、`Sources/Canvas/CanvasController.swift:5958`（noteArrived）、returnedToCanvas（Task 4 钩子）
- Modify: 上游 label 渲染处（grep `LabelTests` 对应的源文件，接入 LabelPolicy）
- Test: `Tests/CanvasTests/LabelPolicyTests.swift`（新建）、`Tests/CanvasTests/SelectionFeedbackTests.swift`（新建）

**Interfaces:**
- Consumes: 上游 `WindowProxy.hovered/outlined`、label/pill 渲染、`noteArrived(_:)`、`Chrome` 样式、Task 4 的 returnedToCanvas 钩子。
- Produces:

```swift
enum LabelPolicy {
    enum Mode { case hidden, compact, banner }
    static func mode(zoom: CGFloat, hovered: Bool) -> Mode
}
// 规则：hovered → .compact；zoom < 0.35 → .banner（app 图标+标题横幅）；
// zoom < 0.8 → .compact（小标题）；否则 .hidden。
enum SelectionFeedback {
    static func ringRect(for frame: CGRect) -> CGRect  // frame.insetBy(dx: -6, dy: -6)
    @MainActor static func pulse(on proxy: WindowProxy)  // CAShapeLayer 圆角环：scale 1→1.12、opacity 0.9→0、0.6s、完毕移除
}
```

- [ ] **Step 1: 写失败测试**

```swift
final class LabelPolicyTests: XCTestCase {
    func testModes() {
        XCTAssertEqual(LabelPolicy.mode(zoom: 1.0, hovered: false), .hidden)
        XCTAssertEqual(LabelPolicy.mode(zoom: 0.5, hovered: false), .compact)
        XCTAssertEqual(LabelPolicy.mode(zoom: 0.2, hovered: false), .banner)
        XCTAssertEqual(LabelPolicy.mode(zoom: 1.0, hovered: true), .compact)
        XCTAssertEqual(LabelPolicy.mode(zoom: 0.35, hovered: false), .compact)  // 边界归 compact
        XCTAssertEqual(LabelPolicy.mode(zoom: 0.8, hovered: false), .hidden)   // 边界归 hidden
    }
}
final class SelectionFeedbackTests: XCTestCase {
    func testRingRectInsetsOutward() {
        let r = CGRect(x: 10, y: 20, width: 100, height: 50)
        XCTAssertEqual(SelectionFeedback.ringRect(for: r), CGRect(x: 4, y: 14, width: 112, height: 62))
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --filter LabelPolicyTests && swift test --filter SelectionFeedbackTests`
Expected: FAIL，类型不存在。

- [ ] **Step 3: 实现**

- 新建 `SelectionFeedback.swift`：LabelPolicy、ringRect、pulse（纯 CA 关键帧动画，事件驱动，无计时器）。
- `WindowProxy.hovered` didSet：加阴影上浮动画（shadowOpacity/shadowRadius 提升，0.12s）与发光边框色（accent）；保持现有 border 宽度逻辑（hoverBorderWidth 已补偿 zoom）。不做 scale——避免与 drag/effect 变换冲突（上浮感由阴影承担）。
- label 渲染接入 `LabelPolicy.mode(zoom:hovered:)`：banner 模式在快照中央叠 app 图标+标题（纯层）；compact 为现有小标题；hidden 全隐。相机 zoom 变化时重算（挂现有相机更新路径）。
- `noteArrived`：新代理弹入（现有入场动画若有则保留）+ `SelectionFeedback.pulse`。
- `returnedToCanvas`：对 `wasIn` 代理 `SelectionFeedback.pulse`（"你在这"选中环）。
- 拖拽举起：窗口拖拽开始时复用 hover 阴影加深（同机制），松手恢复；网格吸附开启时拖动中显示网格点（上游对齐引导已有，确认拖动中可见即可，不另造）。
- `CanvasView.mouseMoved`/拖拽路径：光标三态——窗口上 `.pointingHand`、空白 `.openHand`、平移拖拽中 `.closedHand`。

- [ ] **Step 4: 跑测试确认通过**

Run: `swift test --filter LabelPolicyTests && swift test --filter SelectionFeedbackTests && swift build`
Expected: PASS。

- [ ] **Step 5: 真机验证**

悬停窗口：发光边框+上浮+名称牌；拉远到 zoom<0.35：兵牌（图标+标题）可读；新窗口弹入带脉冲环；F3 返回原窗口有渐隐选中环；光标三态正确。

- [ ] **Step 6: Commit**

```bash
git add Sources/Canvas/SelectionFeedback.swift Sources/Canvas/WindowProxy.swift Sources/Canvas/CanvasView.swift Sources/Canvas/CanvasController.swift Tests/CanvasTests
git commit -m "feat: unit-style selection — hover lift, distance banners, pulse rings, cursor states"
```

### Task 6: RTS 书签与键盘相机

**Files:**
- Create: `Sources/Canvas/Bookmarks.swift`
- Modify: `Sources/Canvas/Camera.swift`（Codable）、`Sources/Canvas/Layouts.swift`（bookmarks 字段）、`Sources/Canvas/CanvasView.swift:3091`（keyDown）、`Sources/Canvas/CanvasController.swift`（接线、toast、持久化）
- Test: `Tests/CanvasTests/BookmarkKeyTests.swift`（新建）、`Tests/CanvasTests/LayoutCamerasTests.swift`、`Tests/CanvasTests/CameraTests.swift`

**Interfaces:**
- Consumes: 上游 `Layout.DisplayCamera`（center+zoom，Codable 已有）、布局记忆保存路径（Layouts.swift 里 remembered layout 的读写）、canvas toast（Chrome.swift:25 提到的现有机制）、`view.animateCamera`、`trackpadPan(by:)`（CanvasView:1106）、`showCanvas(fitAll:)`。
- Produces:

```swift
enum BookmarkKey {
    enum Action: Equatable { case jump(Int), save(Int) }
    static func action(keyCode: Int, modifiers: NSEvent.ModifierFlags) -> Action?
}
// 无修饰键的 1–9 → .jump(n)；仅 ⌃ → .save(n)；其余（⌘/⌥/⇧ 参与或非数字键）→ nil。
// 键码用 kVK_ANSI_1...kVK_ANSI_9 常量映射（物理键码非连续，不做算术）。
extension Camera: Codable {}
// Layout 增加：var bookmarks: [String: Layout.DisplayCamera]?  （key "1"..."9"，可选 → 旧文件兼容）
```

- [ ] **Step 1: 写失败测试**

```swift
final class BookmarkKeyTests: XCTestCase {
    func testPlainDigitsJump() {
        XCTAssertEqual(BookmarkKey.action(keyCode: kVK_ANSI_5, modifiers: []), .jump(5))
        XCTAssertEqual(BookmarkKey.action(keyCode: kVK_ANSI_1, modifiers: []), .jump(1))
        XCTAssertEqual(BookmarkKey.action(keyCode: kVK_ANSI_9, modifiers: []), .jump(9))
    }
    func testControlDigitsSave() {
        XCTAssertEqual(BookmarkKey.action(keyCode: kVK_ANSI_5, modifiers: [.control]), .save(5))
    }
    func testOtherKeysAndModifiersAreNil() {
        XCTAssertNil(BookmarkKey.action(keyCode: kVK_ANSI_A, modifiers: []))
        XCTAssertNil(BookmarkKey.action(keyCode: kVK_ANSI_5, modifiers: [.command]))
        XCTAssertNil(BookmarkKey.action(keyCode: kVK_ANSI_5, modifiers: [.option]))
        XCTAssertNil(BookmarkKey.action(keyCode: kVK_ANSI_5, modifiers: [.control, .shift]))
    }
}
```

LayoutCamerasTests 增加：带 bookmarks 的 Layout 编码→解码 round-trip 相等；不含 bookmarks  key 的旧 JSON 解码后 bookmarks 为 nil。CameraTests 增加：Camera Codable round-trip（origin/zoom 保持）。

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --filter BookmarkKeyTests && swift test --filter LayoutCamerasTests && swift test --filter CameraTests`
Expected: FAIL，类型/字段不存在。

- [ ] **Step 3: 实现并接线**

- 新建 `Bookmarks.swift`（BookmarkKey）；`extension Camera: Codable {}`；`Layout.bookmarks` 可选字段。
- `CanvasView.keyDown`：先试 `BookmarkKey.action`——`.save` → `onBookmarkSave?(n)`，`.jump` → `onBookmarkJump?(n)`（新回调，控制器接线）；WASD/方向键 → 以 `trackpadPan(by:)` 步进（约 120pt/次，动画沿用现有 pan 平滑）；Space → 现有 fitAll/seeAll 路径。注意别抢现有 floor/Return/P 键分支。
- 控制器：save → 当前相机存为 DisplayCamera 写入 remembered layout 的 bookmarks + 现有 toast"书签 N 已保存"；jump → 有书签则 `animateCamera`（van Wijk 弧线），无则 toast"书签 N 为空"。持久化走现有布局记忆保存，不另建文件。

- [ ] **Step 4: 跑测试确认通过**

Run: `swift test --filter BookmarkKeyTests && swift test --filter LayoutCamerasTests && swift test --filter CameraTests && swift build`
Expected: PASS。

- [ ] **Step 5: 真机验证**

⌃1 保存（toast），平移缩放后按 1 弧线飞回；⌃2 存另一视角，1/2 互跳；WASD/方向键平移、Space 全景；重启应用书签仍在。

- [ ] **Step 6: Commit**

```bash
git add Sources/Canvas/Bookmarks.swift Sources/Canvas/Camera.swift Sources/Canvas/Layouts.swift Sources/Canvas/CanvasView.swift Sources/Canvas/CanvasController.swift Tests/CanvasTests
git commit -m "feat: RTS camera bookmarks (1-9 jump, Ctrl+1-9 save) and keyboard camera"
```

### Task 7: 小地图/缩放读数默认开 + 操作提示条

**Files:**
- Create: `Sources/Canvas/HintBar.swift`
- Modify: `Sources/Canvas/Settings.swift`（minimap/zoomReadout 默认值、新计数 key）、`Sources/Canvas/CanvasController.swift`（showCanvas 计数、提示条装配）、菜单构建处（"显示操作提示"项）
- Test: `Tests/CanvasTests/HintPolicyTests.swift`（新建）、`Tests/CanvasTests/MinimapVisibilityTests.swift`、`Tests/CanvasTests/ZoomReadoutTests.swift`、`Tests/CanvasTests/SettingsTests.swift`

**Interfaces:**
- Consumes: 上游 `MinimapPanel`（Minimap.swift，mouseDown/dragged 跳视角 :423-429、Fit）、`Settings.showZoomReadout`、minimap 可见性设置（grep `isMinimapShown`）、`Chrome` pill 样式、Task 3 的 showCanvas 钩子。
- Produces: `HintPolicy.shows(mapEntriesSeen:) -> Bool`（`< 5`）；`Settings.tableclothMapEntries: Int`（key `TableclothMapEntries`，showCanvas 时 +1）；提示条视图（底部中央 pill："滚轮缩放 · 拖拽平移 · 点击聚焦 · F3 返回 · 1–9 书签"，Chrome 样式，policy 为 false 时淡出隐藏）；minimap 与 zoomReadout 默认开。

- [ ] **Step 1: 写失败测试**

```swift
final class HintPolicyTests: XCTestCase {
    func testShowsForFirstFiveEntries() {
        for n in 0..<5 { XCTAssertTrue(HintPolicy.shows(mapEntriesSeen: n)) }
        XCTAssertFalse(HintPolicy.shows(mapEntriesSeen: 5))
        XCTAssertFalse(HintPolicy.shows(mapEntriesSeen: 50))
    }
}
```

SettingsTests/MinimapVisibilityTests/ZoomReadoutTests：清除相关 UserDefaults key 后断言 minimap 默认显示、showZoomReadout 默认 true、tableclothMapEntries 默认 0。

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --filter HintPolicyTests && swift test --filter SettingsTests`
Expected: FAIL。

- [ ] **Step 3: 实现**

- 新建 `HintBar.swift`（HintPolicy + Chrome 风格 pill 视图，CA 淡入淡出）；`Settings.tableclothMapEntries`。
- 默认值翻转：minimap 默认显示、zoomReadout 默认 true（找到各自 getter 的默认分支改默认；旧用例按新默认更新）。
- showCanvas：计数 +1，按 policy 显示/淡出提示条；菜单加"显示操作提示"（计数清零）。
- 确认小地图点击/拖动跳视角与 Fit 在 Tablecloth 下工作（上游已实现，真机验证项）。

- [ ] **Step 4: 跑测试确认通过**

Run: `swift test --filter HintPolicyTests && swift test --filter SettingsTests && swift test --filter MinimapVisibilityTests && swift test --filter ZoomReadoutTests && swift build`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add Sources/Canvas/HintBar.swift Sources/Canvas/Settings.swift Sources/Canvas/CanvasController.swift Tests/CanvasTests
git commit -m "feat: minimap and zoom readout on by default, fading control hints"
```

### Task 8: 布局匹配与新窗口落点——确定性测试补强

**Files:**
- Modify: `Sources/Canvas/Layouts.swift`（restore 匹配处，若发现非确定性）
- Test: `Tests/CanvasTests/LayoutCamerasTests.swift`（或上游匹配测试所在文件）、`Tests/CanvasTests/NewWindowSpotTests.swift`、`Tests/CanvasTests/WindowSyncTests.swift`

**Interfaces:**
- Consumes: 上游 Layout restore 的 bundleID+标题+windowID 匹配（Layouts.swift）、`NewWindowSpot.spot(size:avoiding:view:gap:target:)`、WindowProxy 初始 frame（应为物理 frame 1:1 镜像）。
- Produces: 同 app 同标题多窗口的确定性消歧——存活期按 windowID 精确匹配；重启后 saved entries 顺序 ↔ 当前窗口按 windowID 排序后一一配对。新窗口初始 worldRect = 物理 frame、落在当前视野中心（既有行为，测试钉死）。

- [ ] **Step 1: 写失败测试**

LayoutCamerasTests（或匹配测试文件）增加：
- 两个 saved entry 同 bundleID 同标题、不同 windowID，当前两窗 windowID 与 saved 相同 → 各归各位（frame 不串）。
- 重启场景（当前 windowID 全变了）：saved 两窗与当前两窗按 windowID 排序配对，结果确定（跑两遍相同输入相同输出）。
- 一个新窗口（无 saved entry）→ 初始 worldRect 等于其物理 frame（读 WindowProxy 注册路径断言；若现有行为不符，修注册路径）。
NewWindowSpotTests：补"spot 落在当前 view 可见区内"的用例（若已有则跳过）。

- [ ] **Step 2: 跑测试确认失败或确认既有行为**

Run: `swift test --filter LayoutCamerasTests && swift test --filter NewWindowSpotTests`
Expected: 新用例 FAIL（若匹配非确定性），或 PASS（既有行为已正确——则本任务只新增测试，Step 3 无需改代码）。

- [ ] **Step 3: 实现（仅当测试失败）**

restore 匹配改为确定性配对：先 windowID 精确匹配，剩余同 app+标题的 saved/当前两边各按稳定顺序（saved 数组序 ↔ windowID 升序）zip。不做模糊标题匹配。

- [ ] **Step 4: 跑测试确认通过**

Run: `swift test`
Expected: 全绿。

- [ ] **Step 5: Commit**

```bash
git add Sources/Canvas/Layouts.swift Tests/CanvasTests
git commit -m "test: deterministic same-title window matching and physical-frame initial placement"
```

### Task 9: 真机验证、资源实测、推送 GitHub

**Files:**
- 无新代码；验证与推送。

**Interfaces:**
- Consumes: Task 1–8 全部。
- Produces: `tablecloth` 分支推送到 origin（cyancloudyang/sunlight）；向用户报告的实测资源读数。

- [ ] **Step 1: 全量测试与构建**

Run: `swift test && swift build -c release`
Expected: 全绿 + release 构建成功。

- [ ] **Step 2: 真机清单（spec「验证」节逐项过）**

捏合/平移/WASD/Space；小地图点击跳视角；书签保存 toast/跳转弧线；悬停发光+上浮+名称牌；远距兵牌；新窗口弹入脉冲；点击聚焦俯冲全屏+交叉淡入无黑帧；F3 返回飞回原位+选中环；重启后布局与书签恢复；提示条第 6 次进入时不再显示；权限未授予时引导页正常。

- [ ] **Step 3: Activity Monitor 资源实测并记录**

地图静止 5 分钟：CPU ≈ 0%、内存 < 100MB；聚焦模式：画布进程 CPU ≈ 0%；地图遮挡的视频页应用 CPU 对比（遮挡红利）。读数记入给用户的报告与 PR 描述。

- [ ] **Step 4: 推送并开 PR（到用户自己的 fork）**

```bash
git push -u origin tablecloth
gh pr create --repo cyancloudyang/sunlight --base main --head tablecloth \
  --title "Tablecloth: snapshot-map canvas with RTS camera" \
  --body "按 docs/superpowers/specs/2026-11-10-tablecloth-design.md 实施。含实测资源读数与真机清单结果。"
```

Expected: PR URL 返回给用户。绝不 push upstream。