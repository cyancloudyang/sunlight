# SDD ledger — plan: docs/superpowers/plans/2026-11-10-tablecloth.md

Setup: Ruling: 在现有专用克隆（本会话为 Tablecloth 新建的 fork 克隆，非共享工作区）上按 spec 指定路径建 tablecloth 分支执行，不另开 worktree — spec 绑定此路径与分支模型；代价若错：工作区混入其他改动（已核实 git status 仅 docs 未跟踪，干净）。
Pre-flight: Task 1 产 renderer 恒 .capture / maxStreams=0 → Task 2 的 CanvasView:669 简化与全部后续任务依赖：一致，无冲突。
Pre-flight: Task 2 产 SummonPolicy + mapDidHide() 钩子 → Task 3 接计时器停止：一致（Task 2 留钩子、Task 3 接线）。
Pre-flight: Task 2 的 handingOff 不隐藏 → Task 4 聚焦激活他 app 时飞行中地图保持：一致（上游 handingOff 标志 :144 已有）。
Pre-flight: Task 3 接 returnedToCanvas 的 .focusReturned → Task 4 在同函数加 frame 恢复、Task 5 加脉冲环：顺序执行无冲突。
Pre-flight: Task 6 产 Layout.bookmarks → Task 8 改 Layouts 匹配逻辑：不同区域，无冲突。
Task 1: Ruling: 基线 swift test 构建成功但 dlopen 失败（Sparkle.framework 不在测试 bundle 搜索路径；本机 Swift 6.2 的 .build/out 布局）— 在 .build/out/Products/Debug/PackageFrameworks/ 放 Sparkle.framework symlink 指向 artifacts 切片，不改 repo — 代价：swift package clean 后需重建 symlink。
Task 1: Ruling: SetupFlow 超出计划字面扩展到 page()/progress() — page() 删 live 路由（终端恒 .preview）、progress 只数两权限；spec 绑定"只需两个权限、无 SIP 引导"，否则菜单栏 rays 永远 2/6 nag — live-phase 测试改写为 Tablecloth 语义；代价：上游合并冲突面增大。
Task 1: Ruling: renderer setter 删除的级联按编译器引导处理 — 删 Settings 的 LiveWindowsPane tab 与 setRenderer（升级/状态推送面）、App.loadLiveWindows 及 :739 接线（wizard 的 onLoadLiveWindows 留 nil，dormant load 页）、uninstall 的 Settings.renderer 写入行；菜单 disabled 的 Reload Live Windows 项保留（canReload 恒 false，不 nag）— 代价：上游合并冲突。
Task 1: Ruling: .preview 向导页删 live upsell 文案与按钮（headline 恒 "You're set."）；MenuBarPanel caption .preview 改 "On · snapshots"（"preview" 暗示未完成品，与产品矛盾）— 代价：文案测试需同步。Task 1: baseline green — swift test → exit 0, 584 XCTest cases passed (after Sparkle symlink ruling).
Task 1: Ruling: LiveWindowsPane 删除级联再扩一层 — pane 独占的 SettingsModel 机器（liveStatus/LiveStatus/liveSelectable/setupSummary/setupDone/setupTotal/setupChecked/setupLog/showSetupLog/readSetupLog/refresh）与 onRendererChange/onSetup/model.window、SettingsPictures 的 ModePicture、PipelineStage/Arrow/Mark/MiniWindowsPicture/DockPicture 一并删（删后全无人引用）；SetupDiagnose 保留（CLI --renderer-status、wizard、Stability 仍用）— 代价：Settings 失去 Set Up/Diagnose 行（菜单栏与 wizard 仍有入口）。
Task 1: Ruling: PreviewBadge.swift 同文件还定义 CanvasToast 与 PillButton — CanvasToast 原样抽到 Sources/Canvas/CanvasToast.swift（Task 6/7 的 toast 依赖它），PillButton 无人用随之删除 — 代价：若上游后续加 PillButton 引用需恢复。
Task 1: Ruling: tab 计数测试（SettingsPicturesTests 8→7）的 RED 被 setter 删除引发的编译错误挡住，无法在实现前单独看它断言失败；实现后随全套验证转绿 — 代价：该条 RED 证据较弱。
Task 1: Ruling: SetupDiagnoseTests 既有断言按新默认值更新（"Everything's set up." / "Progress: 2 of 2 steps"）— 报告格式测试跟随两权限语义；代价：无。
Task 1: complete (commits cf7aa16..f2dc70e, tests: swift test → ✔ Test run with 0 tests in 0 suites passed after 0.001 seconds.)
Task 2: Ruling: Info.plist 已有 LSUIElement=true（上游即无 Dock 图标），无需改动 — 代价：无。
Task 2: Ruling: hideMapForForeignFront 除 brief 的 didResignActive 外也挂 didActivateApplication（⌘Tab 的 foreign front 在 resign 时可能尚未报告，只挂 resign 会漏）；以 !NSApp.isActive 为前提并跳过 launches/restoring/expectedActivationPID/quietAfterClose/justFolded（canvas 要留在原地的 app 不算接管前台）— 代价：守卫与 foreignActivation 重复，上游改动需同步。
Task 2: Ruling: Step 5 真机遮挡验证并入 Task 9 的统一真机清单（mid-session 启动 app 会抢占用户桌面；make app  bundle 才带 Info.plist）— 代价：遮挡红利到 Task 9 才实测。
Task 2: complete (commits f2dc70e..8ec00f1, tests: swift test → ✔ Test run with 0 tests in 0 suites passed after 0.001 seconds.)
Task 3: Ruling: 菜单开关用英文 "Rotate Snapshots"（brief 的"每秒轮换快照"为描述性名称；全 app 菜单文案均为英文，spec 未钉死该文案）— 代价：若用户要中文标签，改一行即可。
Task 3: Ruling: 锁屏/睡眠复用 DormancyMonitor→dormancyChanged（四个 NSWorkspace 通知上游已观测；asleep 分支经 ensureRefreshTimer 的 !asleep 停表，wake 分支补 refresh(for: .mapShown)），不新增重复观察者 — 代价：无行为差异。
Task 3: Ruling: policy 的 mapVisible 取 window.isVisible（不含 canvasOccluded；遮挡通知滞后于 orderFront，若纳入会漏掉召回时的 .mapShown 刷新）；ensureRefreshTimer 额外要求 !canvasOccluded 使被盖住的地图不走 tick — 代价：可见但被完全遮挡时事件刷新多捕一次（罕见）。
Task 3: 确认：WindowProxy.refresh(seam:) 失败路径（OneShotCapture 回 nil image）保留旧纹理/占位、refreshing 复位、无重试空转（WindowProxy.swift:667-687 读证）。
Task 3: complete (commits 8ec00f1..d6646ae, tests: swift test → ✔ Test run with 0 tests in 0 suites passed after 0.001 seconds.)
Task 4: Ruling: resize 时机在完成回调（brief 明确）而非 spec 的"动画背后"飞行中 — outcome 检查本就在落地时；seam 处 proxy 与真窗逐像素对齐后激活，重排/清晰度由结尾掩蔽（spec 验收口径） — 代价：seam 处有一帧内容重排
Task 4: Ruling: windowAlive = WindowList.onScreen(id) != nil（主线程直接调用，:6131 等多处先例）— 同时覆盖关闭与最小化（Review Focus #2）；捕获模式下其他 Space 的窗本就不是 proxy — 代价：飞行中被移到其他 Space 的窗会中止聚焦
Task 4: Ruling: 保存/恢复仅限 fillScreen（推翻研究阶段"所有 capture placement 统一保存"的设想）— 非 fillScreen 保持上游"留在进入处"行为；spec 的回原位只针对聚焦往返 — 代价：捏合进入的窗口返回时不恢复聚焦前物理 frame（上游行为不变）
Task 4: Ruling: fillScreen 用 view.fly（van Wijk 弹簧）并新增 step 回调骑同一弹簧，proxy 在飞行中从 mapRect 平滑长到全屏（spec：快照卡片平滑飞至全屏），而非 seam 处瞬跳；brief 的"时长沿用 cameraDuration"不适用于弹簧飞行 — 代价：时长随距离变化（弹簧响应），非固定 0.42s
Task 4: Ruling: 返回同样用 step 逆向 lerp（grown→mapRect）+ 相机拉升，真窗在返回开始时 AX 恢复（画布背后）— spec 的"窗口飞回地图原位"字面达成；取消路径（onAnimationCancelled）有 focusReturnProxy 兜底归位
Task 4: Ruling: 新增第四个纯函数 Handoff.flightRect + testFlightRectClampsAtTheEnds（超出 brief 的三个测试，TDD 要求 lerp 有测试）； RED 已见证（compile error）
Task 4: Ruling: 聚焦中退出 app 可能把 grown rect 持久化到布局（entered 期间 watcher 移动会 rememberSoon）；返回总会恢复 mapRect — 代价：聚焦中退出后重启，该窗地图位置是全屏 rect 直到被移动；留 Task 9 真机清单观察
Task 4: Step 5 真机验证并入 Task 9 统一清单（沿用 Task 2 ruling 模式）
Task 4: complete (commits d6646ae..cd6ba5e, tests: swift test → ✔ Test run with 0 tests in 0 suites passed after 0.001 seconds.)

Task 5: Ruling: keep the existing accent border colour (0.35, 0.62, 1 — already the blue glow) instead of NSColor.controlAccentColor — matches upstream look; cost if wrong: border ignores the user accent setting.
Task 5: Ruling: alignment guides confirmed already drawn during drag (show(guides) in dragWindow, Settings.alignmentGuides gate) — no new grid dots, per brief "不另造"; cost: none.
Task 5: Ruling: return pulse fires at the return flight completion for fillScreen (ring lands at map size), immediately for non-fillScreen returns — a ring at call time would ride the shrink at grown size; cost if wrong: ring appears one spring-duration after F3.
Task 5: Ruling: bannerIcon cached lazy per proxy — NSRunningApplication.icon identity is unstable, re-fetching would re-render the banner bitmap; cost if wrong: an app changing its icon mid-session keeps the old one until the proxy is recreated.
Task 5: Ruling: Step 5 真机验证 deferred to Task 9 (as Tasks 2/4) — no display capture in this session.
Task 5: complete (commits cd6ba5e..268b58d, tests: swift test → ✔ Test run with 0 tests in 0 suites passed after 0.001 seconds.)
Task 6: Ruling: Desk.swift is the actual aggregate persistence owner, not CanvasController — add shared bookmarks there, restore from last layout and include in every remember; sameArrangement compares bookmarks so saving without moving still writes — cost if wrong: shared slots across displays, not per-display slots.
Task 6: Ruling: use fly(to:) for bookmark jumps, not animateCamera (which interpolates a straight line) — spec explicitly requires CameraPath/van Wijk arcs — cost: spring duration varies with distance.
Task 6: Ruling: trackpadPan takes normalized screen widths, not points; divide 120pt by width*gain and cancel synthetic finger hold immediately after enqueuing — avoids stuck settling and artificial inertia; cost: keyboard steps use display-frame input rather than a separate tween.
Task 6: Ruling: retain XCTest per Global Constraints rather than migrate to Swift Testing — cost: no parallel-test migration in this feature.
Task 6: Step 5 native interaction checks deferred to Task 9.
Task 7: Ruling: minimap and zoom readout already default on — preserve opt-outs; add minimap regression and run existing readout test — cost: none.
Task 7: Ruling: count in showNow, with per-visit guard reset on resign, rather than only showCanvas — startup and direct show callers also enter the map — cost if wrong: a brief foreign activation can count a new visit.
Task 7: Ruling: add menu forwarding in App/Desk; hint pill uses the space between symmetric minimap margins, truncating on narrow displays — avoids obscuring minimap/Dock — cost: long hint text may truncate.
Task 6: complete (commits 268b58d..2229140, tests: swift test → ✔ Test run with 0 tests in 0 suites passed after 0.001 seconds.)
Task 7: complete (commits 2229140..ab8b1bd, tests: swift test → ✔ Test run with 0 tests in 0 suites passed after 0.001 seconds.)
Task 8: Ruling: NewWindowSpot already tests view containment and view-centred placement; reuse those cases. Physical initial frame is tested at the launch identity camera, while subsequent arrivals correctly map physical origins through the current camera — cost if wrong: no assertion of raw physical coordinates after panning, which would contradict canvas coordinates.
Task 8: RED: restarted same-title windows paired as [102,101] rather than [101,102] twice; sorted candidates by windowID without changing exact-ID/document/title priorities. Combined filter replaces separate invocations and includes WindowSyncTests.
Task 9: Ruling: whole-branch review precedes native launch/publication, because package.sh still bundles injection helper and startup safety must be verified first — cost: review-driven fixes delay native tests, but no unsafe package is launched.
Task 9: Native automation preflight: System Events UI elements enabled = false; no permissions or system preferences changed. Golden-path native interaction and five-minute CPU/memory measurements remain unverified, not passing. No existing Sunlight defaults domain or built app found.
Task 9: swift test && swift build -c release → exit 0; 609 XCTest cases, 1 skipped (DockItemTests.testTheAppsOwnBundleIsItsIcon: runner has no app bundle), 0 failures. Build emits concurrency/import warnings and a deprecated trailing-closure matching warning, not a warning-free build. Machine: Mac14,2, 8 GiB RAM, macOS 27.2 (26B123), Xcode 27.0 (27A5218g). Native GUI and resource acceptance not yet met.
Task 8: complete (commits ab8b1bd..22e7da9, tests: swift test → ✔ Test run with 0 tests in 0 suites passed after 0.001 seconds.)

Handoff 2026-11-11: 用户要求节约额度，停止实现，保存跨 agent 交接；Tasks 9/10 暂停且未完成，不删除 workspace。
Final review: 一次独立只读审查已完成，cf7aa16..22e7da9，41 个净变更文件及调用者；结论不应合并。1 Critical、10 Important、1 Minor，Declined to judge: none。完整 findings、未提交补丁与接手顺序见 docs/superpowers/2026-11-11-tablecloth-handoff.md。
Final: minor (deferred): 活跃地图上的普通新窗口未走 noteArrived 脉冲反馈路径；尚未修复，不宣称该交互通过。
Handoff current verification: swift test --filter 'SetupFlowTests|SwitcherKeysTests' → exit 1，App.swift:328/329/374/375 残留已删除 takeOverTheMac/releaseTheMac 的引用导致编译失败；测试未执行。完整日志 handoff-current-tests.log 已读取错误。旧 609-test green 仅适用于 HEAD 22e7da9、未包含当前安全补丁。
Handoff delivery: docs/superpowers/2026-11-11-tablecloth-handoff.md、2026-11-11-tablecloth-prompt.md 与本 ledger 的 durable copy 2026-11-11-tablecloth-ledger.md。所有开发仍仅本地；未 push、未建 PR、未完成安全打包/真机/资源验收。

## 接手后修复（2026-11-11 第二轮，本会话原生实现）

起点：分支 tablecloth，HEAD 22e7da9，未提交安全补丁保留未 reset/restore/clean；App.swift 四处残留 takeOverTheMac/releaseTheMac 使局部测试失败。全部修复以 RED→GREEN 推进，每组改动后跑全套 `swift test`。

- #1 Critical 完成（2e1783e、440c093）：UI 侧接管入口删除，AKAuthorizationRules/登录项/Stage Manager/系统偏好写入代码删除；`--release` 变为无操作并说明 Tablecloth 不改系统；`--status` 只读两权限。RED：SetupFlowTests/SwitcherKeysTests 编译失败 → 修复后转绿。
- #2 完成（2e1783e）：PermissionGate 统一门控（Accessibility + Screen Recording），缺权限不出图、不取屏，撤销后可回到引导；权限只在用户主动操作时检查，不主动改系统设置。
- #3 完成（db0ba21）：成功聚焦后隐藏地图（mapDidHide），不再留不透明层压真窗。
- #4 完成（b898704）：聚焦期间只保存地图几何（记住 mapRect/布局），不把临时全屏 rect 写成地图位置。
- #5 完成（640b015）：F3 返回不再依赖 takeover；返回飞行不被 fitAll 打断；新增备份召唤键（--summon-key），仅认 Mission Control 与 F3，不占系统键。
- #6 完成（10ad677）：CaptureBarrier 在切换焦点前后等待一帧真实尺寸画面，先后向都等帧再进/再退回，0.3s deadline 兜底，避免末端夹带旧尺寸帧。
- #7 完成（dc220d8）：所有保留帧长边上限 1024，缩略与聚焦取图分开，内存不再随 5K 窗口线性增长。
- #8 完成（d27effa）：私有 API 全部可选（弱符号/运行时探测），缺失时走公开兜底路径（无私有 API 也能显示地图与聚焦）。
- #9 完成（acf5f44）：隐藏/睡眠/锁屏时停 listing 与恢复计时器，丢弃上一"生命期"的在途捕获帧，唤醒后重建。
- #10 完成（a9094b7）：RestorePlacement 每批到达时对整组 entry 与整组窗口重新匹配并纠正，到达顺序不再决定位置；用户已手动移动的窗口保持不动（>1pt 位移视为用户移动）。
- #11 完成（e1f92b7）：package.sh 不再构建/拷贝 helper，签名前拒绝 Contents/Helpers 与 Contents/Library/LaunchDaemons，拒绝无 fork 自有公钥的 Sparkle feed；build-live-windows.sh 默认拒绝运行（需 ALLOW_INJECTOR=1），Makefile 注明。packaging/release.conf 的上游 feed/key/tap 置空 → 更新检查恒关闭（Updater 仅在 feed+key 齐备时启动）。
- #12 Minor deferred（未修，不宣称通过）：活跃地图上普通新窗口缺 noteArrived 脉冲反馈。

验证证据（本会话）：`swift test` 679 tests、1 skipped、0 failures（skip 仍为 DockItemTests.testTheAppsOwnBundleIsItsIcon：runner 无 app bundle）。`SIGN=- scripts/package.sh --app-only` 成功：build/Sunlight.app 内无 Contents/Helpers、无 Library/LaunchDaemons，Info.plist 无 SUFeedURL/SUPublicEDKey，无 entitlements，`codesign --verify --strict --deep` 通过。未运行 app、未做真机交互与 CPU/内存测量（未授予权限前不启动），因此交互验收与资源达标一律标记"未验收"。

仍未做：真机若干部（权限四态、捏合/平移/书签/聚焦往返、睡眠唤醒、5 分钟 CPU/内存），push 与 PR（尚未推送，未发布）。

## 独立复核（2026-11-11 第三轮，Qoder 主会话，非实现者）

对 marvis 报告逐项核实，证据为本会话新跑/新读，非转述：

- git：tablecloth 干净树，22e7da9 之上恰 13 个提交（5c185f5..084ac6f），49 文件 +1906/−964；remotes 未变。
- `swift test` 全新运行 → exit 0，**679 tests、1 skipped、0 failures**（verify-suite.log；skip 仍为 DockItemTests 无 bundle 用例）。
- 打包产物亲验：build/Sunlight.app 无 Contents/Helpers、无 Library/LaunchDaemons，Info.plist 无 SUFeedURL/SUPublicEDKey，`codesign --verify --strict --deep` 通过；二进制 11:22 构建，晚于最后代码提交 e1f92b7（11:20），084ac6f 仅文档。
- #1 亲验：TakeoverMode.swift 整文件删除（−339 行），Sources 内无 CFPreferencesSetAppValue/SMAppService.register/Spaces.fold 可达调用；`--release` 无操作；Uninstall/LegacyMigration/Stability.startGuard 仅剩定义无调用方。
- #2 亲验：PermissionGate.swift 存在，App 启动/开关/状态变化均经 gate。
- #8 亲验：AX 符号改 dlopen/dlsym 可选 + AXFrames 帧匹配兜底，id-only 问题答 nil；截图改 macOS14+ 公开 captureImage。
- #11 亲验：package.sh 签名前拒绝 helper/LaunchDaemon/无 fork 公钥的 Sparkle 键；release.conf 四项置空；build-live-windows.sh 无 ALLOW_INJECTOR=1 即 exit 1。
- #3–#6/#9/#10：CaptureBarrier、RestorePlacement 等已存在并接线，以 679 项测试（含新增用例）与第二轮 ledger 为据，未逐行复审——按既定流程不跑第二次整分支审查。
- 结论：marvis 报告与仓库实际状态一致，无虚报。真机交互与 CPU/GPU/内存仍**未验收**；#12 仍 deferred。

## 首轮真机验证与用户反馈（2026-11-11 第四轮）

用户授予两权限并实际运行 app，主观评价"总体效果超过预期"。日志确认：0 streaming、双捕获路径（私有 SkyLight 13–28ms / 公开 SCK 42–104ms）、聚焦后地图隐藏、在途旧帧按 life 代次丢弃、新窗落位、Canvas.json 世界坐标+相机持久化且聚焦不污染几何。边界复核 SystemPrefs 仅只读。性能观测：主线程卡顿 6 次（510–5369ms），根因 AXWindow.frame 主线程同步往返 + listNow 同步阻塞 + 主 runloop 计时器偏多。

用户 7 条反馈（详见 docs/superpowers/2026-11-11-tablecloth-native-feedback.md）：①引导 Next 按钮固定中下部 ②快捷键提示常驻 ③手势入图加拉远入场动画 ④修复四指分开进桌面 ⑤背景随相机逐渐模糊 ⑥⌘Tab 切换加飞起-降落到效果 ⑦继续性能优化。①–⑤⑦在既定边界内可实现；⑥与"无 takeover/三低"冲突，待用户拍板路线。5 分钟静止 CPU/内存测量尚未做（用户提前结束测试转入优化）。

## 反馈优化轮（2026-11-11 第五轮，TDD 逐项）

- #12 完成（4f37a71）：HintPolicy.shows 恒 true，快捷键提示整段地图会话常驻。RED→GREEN，全套绿。
- #13 完成（b0b4b3a）：SetupPageLayout 把动作行钉在中下部（bottomMargin 140，随字号缩放），与演示区大小解耦；演示/文案居中于上半。Ruling: 视觉落点（中下部、边距 140）需真机确认 — 代价：若观感不佳改一个常量。
- #14 完成（5d2909e）：BackgroundSpec 模糊带展宽到整个拉远（focusSharpZoom 1.0 / focusFullZoom 0.3），levelRadii 改 [0,4,8,14,28,44,60]（相邻跳≤16px）逐级淡入。Ruling: 更细梯度多两级半尺度模糊层（内存代价）换平滑 — 代价：内存略增；平滑观感需真机确认。
- #15 完成（3955152）：showFitsAll 加 seeAll 意图，四指 See All 从窗口入图也拉远相机（不再 1:1  reopen）；MC 键返回仍保留相机（#5 不破坏）。RED→GREEN，全套绿。
- #17 完成（本轮提交）：四指分开/F11/菜单 Show Desktop 可选露出真实 macOS 桌面。
  - Ruling: 真实桌面用 opt-in（Settings.realDesktopOnShowDesktop 默认 false）+ 发送系统 Show Desktop 快捷键 F11（virtualKey 103，marked event 到 .cghidEventTap）实现，不用私有 API — 无公开 Show Desktop API，发快捷键是 BTT 等工具的既有公开手法；代价：依赖用户在"系统设置›键盘›键盘快捷键›调度中心"启用 Show Desktop（默认 F11），关闭/改键则无效或触发别的动作；系统交互真机未验收。默认关以保留可用的画布快照地板。
  - Ruling: KeyTap.handle 加 marked-event passthrough（KeyTap.passesOn），否则 canvas 自发的 F11 被自己的 tap 截获再触发 showDesktop 成循环 — 代价：无（marked 事件本即 canvas 自发，PressTap 对鼠标已有同款）。
  - Ruling: 恢复挂在 showNow() 漏斗（任何召唤——再分开/F11/MC 键——都先恢复系统窗口再清标志），reveal 用 mapDidHide() 停刷新丢在途帧 — 代价：real desktop 期间用户点 Dock/真窗使系统状态与 realDesktopShown 可能不同步（best-effort，opt-in，真机清单观察）。
  - Ruling: 测试 target 为 Swift 6 严格模式（生产 Canvas 模块 Swift 5），KeyTapPassthroughTests 标 @MainActor 才能读 CanvasView.passedOnMark — 代价：无。
  - 验证：ShowDesktopPolicyTests/KeyTapPassthroughTests/SettingsTests RED（compile error）→GREEN；swift test 695 tests、1 skipped、0 failures。UI 开关在 Settings›How to use›Trackpad›Show Desktop。
- #16 完成（本轮提交）：⌘Tab 窗口间飞行用更高弧（CameraPath.switcherRho 1.6 vs 默认 1.1），近窗也明显飞起-降落。
  - Ruling: 不接管 ⌘Tab（用户拍板"轻量飞行"），只把 spatial handoff 的 van Wijk 弧 rho 提高 — 同一 display-link 弹簧飞行，零额外 GPU/CPU；默认弧（聚焦俯冲/返回/snap）不动 — 代价：弧高观感（1.6 是否够"酷炫"又不眩晕）需真机确认，改一个常量即可。
  - Ruling: 方向性运动条纹（cheap streak，替代真运动模糊）本轮缓做 — 纯视觉叠加层，盲调易"眩晕/啰嗦"（用户明确警告），且有 GPU 成本，与三低相悖；先交付可几何验证的飞起-降落，条纹留真机迭代 — 代价：用户期望的"运动模糊感"本轮未到位，已列 deferred。
  - Ruling: CanvasView.passedOnMark 改 nonisolated（不可变 Sendable 常量，tap 线程本就读它）— 消除 KeyTap.passesOn 引入的 Swift 6 隔离警告；PressTap/keyHoldLimit 的既有警告非本轮引入，不顺手改（避免范围蔓延）— 代价：无。
  - 验证：FlightArcTests 4 例 RED（extra argument rho / no member switcherRho）→GREEN；swift test 699 tests、1 skipped、0 failures。
- #18 完成（本轮提交）：返回地图不再在主线程同步读 AX 帧。leaveEntered 两种渲染模式都先读窗口服务器列表（~1ms，不等 app），仅当列表无法定位（无条目/空帧）才惰性回退 AX（`ReturnFrame.fromListing(...) ?? p.ax?.frame`，`??` 右侧 autoclosure 仅在需要时求值）。直接针对日志中 1336ms 的 `AXWindow.frame` 主线程卡顿（busy Weather 返回时）。
  - Ruling: 默认 capture 模式此前对已入场窗口直接同步读 `p.ax?.frame`（旧注释误以为 capture 模式"无列表可读"，但入场窗口此刻在屏、列表必有其帧）— 改为与 live 模式一致优先列表，AX 仅惰性兜底 — 代价：capture 返回多读一次全量列表（~1ms）换掉最坏 ~1s 的 AX IPC；空列表帧改回退 AX（此前选中后再被下游 hasSize 拒绝）属严格改进。卡顿降幅需真机复测确认（不虚构 CPU/内存数字）。
  - Ruling: 本轮只做这一处有日志实证、低风险、可纯函数测试的卡顿修复；其余主线程 AXWindow.frame 同步点与 listNow/snapshot 的 WindowList.queue.sync 列为后续候选，不在无第二次复核下贸然做线程重构（handoff/seam 逻辑精密）— 代价：其余 510–840ms 卡顿本轮未动。
  - 验证：ReturnFrameTests 3 例 RED（cannot find ReturnFrame）→GREEN；swift test 702 tests、1 skipped、0 failures。
- #19 完成（3d37f44）：`AXUIElement.frame` 由两次 AX IPC（kAXPositionAttribute、kAXSizeAttribute）改为公开 API `AXUIElementCopyMultipleAttributeValues` 一次批量读位置+尺寸。新增纯函数 `AXFrame.parse([AXValue]) -> CGRect?`，用 `AXValueGetValue` 的类型校验拒绝批量里失败属性返回的 axError/CFNull 包装值。每次帧读取的最坏等待从两次 messaging timeout 降到一次。
  - Ruling: 批量失败（busy app/dead element）直接返回 nil（一次等待，优于原来两次），仅当 app 已应答但批量携带不可用值（该元素不提供某属性）才回退单读 — 避免给 busy app 增加第三次往返；线程/时序不变，是带兜底的安全 drop-in，不触碰精密 handoff/seam — 代价：极罕见"批量成功但某属性单读可服务"的情形多一次批量往返（仍≤原两次）。最坏卡顿降幅需真机复测（不虚构数字）。
  - Ruling: 公开 API 可用性已核 SDK 头（AXUIElement.h:244，CF_AVAILABLE_MAC(10_4)；options=0 时失败属性以 kAXValueAXErrorType/CFNull 返回）— 非私有 API，符合硬约束 — 代价：无。
  - 验证：AXFrameTests 4 例 RED（cannot find AXFrame）→GREEN（含 testRejectsABatchedErrorValue 用真实 AXValueCreate(.axError)）；swift test 706 tests、1 skipped、0 failures。

## 推送与验收状态（2026-11-11 第五轮末）

- 已 push origin（cyancloudyang/sunlight）tablecloth：0d54a41..3d37f44（第五轮 8 提交 4f37a71..3d37f44，含 #19 批量 AX 帧读 3d37f44 与本 ledger 更新）。未 push upstream（spacefarm-digital）。PR #1 仍 OPEN/draft（https://github.com/cyancloudyang/sunlight/pull/1），未合并、未发布。
- 全套 `swift test`：706 tests、1 skipped、0 failures（skip 仍为 DockItemTests 无 bundle 用例）。编译警告均为既有 Swift 6 严格模式基线，本轮未新增。
- 仍未验收（需用户真机再跑）：5 分钟静止 CPU/内存测量；#13/#14/#15/#16 的视觉观感（按钮落点、模糊梯度、入场拉远、⌘Tab 弧高）；#17 真实桌面系统交互（依赖系统 Show Desktop 快捷键启用）；#18/#19 卡顿降幅复测。一律不虚构数字、不宣称达标。
- 后续候选（本轮未做，留用户决定是否授权更深线程 pass）：其余主线程 AXWindow.frame 同步点（isFullScreen/setPosition/setSize 未被 Watchdog 包裹）；listNow():2279 / snapshot():5642 的 WindowList.queue.sync 阻塞 hop。handoff/seam 精密，无第二次复核不宜贸然重构。
- #19 后空闲开销排查（2026-11-12，仅读代码、未真机测量）：逐个核对全部重复 Timer 与 CADisplayLink 的生命周期——
  - CanvasView 的 CADisplayLink 在 stopLinkIfIdle()（:1390）满足无 animation/flight/entrances/magnet/pipFlights/pending/coast/zoomCoast 且输入超过 inputLinger 时 `invalidate()` 并置 nil（彻底拆除，非仅 isPaused）；静止地图无逐帧回调。
  - 所有 repeats:true 的 Timer 均已门控到活动态且自失效：enteredTimer(:7697,1s,tol0.25) 仅入场时；addingWidgetsTimer(:3518,0.25s) 仅小组件编辑；restoringTimer(:3893,0.5s) 仅布局恢复；passThroughTimer(:8246,1/60) 仅 live 模式穿透且 canPassThrough 假时不起；displayPoll(App:155,1s) 仅启动等屏；Settings DesktopMapRow refresh(:1646,1s) 仅该设置面板可见。
  - 结论：默认快照地图静止时没有重复 Timer/DisplayLink 在跑，"主 runloop 计时器合并"对空闲 CPU 无收益，反增门控风险——本轮不做（从候选移除）。空闲 CPU≈0 是既有设计达成，非本轮新增；具体数字仍待真机测量，不虚构。
  - 其余 AX 热路径：findNow 的 windowID 走可选私有 axUIElementGetWindow（直调，非 AX 属性 IPC，有公开 frame 匹配兜底），frame 匹配回退已受 #19 批量惠及（每候选 1 次而非 2 次）；isFullScreen/isMinimized 为单 bool 读且多在 AXQueue 后台，批量收益微、改语义有风险，不做。跨窗口批量无公开 API（AXUIElementCopyMultipleAttributeValues 只批量单元素的多属性）。

## UX 修复轮（2026-11-12 第六轮，TDD 逐项）

用户真机操作后报两个反直觉问题（暂停 #20 真机测量转入本轮）：①不管 app 原 size 如何，点卡片切入后都铺满全屏、改掉原尺寸；②四指上滑进全 tablecloth 视角后各 app 不自动排布、仍互相重叠，应按 app 分类/关联排布。AskUserQuestion 拍板：①「原尺寸·停在卡片原位」（不 resize）；②「按 app 分组+不重叠」；时机「仅首次·之后尊重手动」。

- #21 完成（44d0f62）：单击地图卡片不再 `.fillScreen`（铺满+改尺寸），改走 `Handoff.cardClick(at:offset:)` → `.clicked`，围绕点击点 1:1 入场、保留窗口自身尺寸与原位。新增纯政策 `Handoff.cardClick`（薄包装，记录"卡片单击=原位原尺寸"这一决策，与既有 NewWindowSpot/ReturnFrame 同款）。`.fillScreen` 路径保留（handoff 默认参/onPipReturn 仍用）。live 路径 .singleClick 本就用 .clicked，不变。
  - Ruling: 用既有 `.clicked` placement 而非新写一套入场几何 — 它已"围绕点击点放大到 1:1、保尺寸、保原位"，正是用户要的；只把 onClickEnter 的 placement 从 fillScreen 换成 cardClick — 代价：无（.clicked 已被 testAClickKeepsTheClickedSpotUnderThePointer 等覆盖）。双击/⏎/切换器仍 .centered（原尺寸居中），不变。
  - 验证：HandoffTests.testACardClickEntersInPlaceRatherThanFillingTheScreen RED（no member cardClick）→GREEN；swift test 707 tests、1 skipped、0 failures。入场观感（原位原尺寸）需真机确认。
- #22 完成（9fbec70）：首次进图（无保存布局）自动按 app 分组、各保原尺寸、互不重叠。新增纯政策 `FirstArrangement`（Tidy.swift）：`shouldArrange(remembered:) = !remembered`、`options(spacing:) = Tidy.Options(columns:0, sizing:.keep, order:.app, spacing:)`。控制器把 `tidy()` 的网格主体抽成 `layOutTidy(_ options:) -> Bool`（原样复用：聚 item/成组、Tidy.layout、移动真实窗口、相机同motion取景、rememberSoon），`tidy()` 仍守 Settings.arranging/isActive 后调它；新增 `autoArrangeFirstCanvas()`（无 remembered 才调 layOutTidy）。两处 first-sync 钩子（:2476/:2644）的 else 分支改 `else if !autoArrangeFirstCanvas() { view.fitAll(animated:true) }`。
  - Ruling: 复用既有 Tidy 引擎而非 NewWindowSpot — Tidy.Order.app 已"同 app 并排、app 按首窗出现序"，Sizing.keep 已"列取最宽/行取最高、不 resize、永不重叠"，正是用户两要求；NewWindowSpot 是单窗增量避碰、非全局打包 — 代价：无（Tidy 引擎已被 TidyTests 覆盖：testByAppKeepsAnAppTogether…/testKeepSizesNeverOverlaps/…WithoutResizing）。
  - Ruling: 触发条件用 `remembered == nil`（desk?.remembered）而非 `!placed` — 有保存布局但本批窗口尚未匹配（apps 仍在启动）时 placed 亦 false，此时应等 placeRemembered 逐步放回、不该自动重排；remembered==nil 才是真·首次 — 代价：无。仅 first-sync（didInitialFit 外层门控）触发一次；layOutTidy 的 rememberSoon 持久化结果，下次 remembered!=nil → 不再自动排、尊重手动。
  - Ruling: 自动排布不守 Settings.arranging（实验开关，默认关）— 这是 Tablecloth 核心首屏行为、非实验 Tidy 功能；layOutTidy 本身无 arranging 门控，公共 tidy() 仍守 — 代价：无（用户明确要首屏自动排布）。自动排布注册 ⌘Z undo（名 "Tidy"），用户可撤销回桌面原 pile，合理。
  - Ruling: 真实窗口随动走既有机制 — layOutTidy 的 place(at:) 置 owner=.canvas+worldRect，真实窗口经既有 canvas→real 同步跟随（与手动 Tidy 完全同路径）；standsAlone 排除 widget/attached，故"widgets stay"不变 — 代价：无。首屏真实窗口被移到网格是用户明确要求。
  - 验证：FirstArrangementTests 3 例 RED（cannot find FirstArrangement）→GREEN（含 testOverlappingWindowsEndUpSeparatedAndGroupedByApp 用真实 Tidy 验"重叠输入→不重叠+保尺寸+按 app 成块"）；swift test 710 tests、1 skipped、0 failures。make app 编译打包+ad-hoc 签名 OK，codesign --verify --deep --strict OK，无 SUFeedURL/SUPublicEDKey（安全态）。首屏排布观感（分组/间距/取景）需真机确认。

## 推送与验收状态（2026-11-12 第六轮末）

- 本轮提交：44d0f62（#21 卡片单击原位原尺寸）、9fbec70（#22 首屏按 app 自动排布）+ 本 ledger 更新。待 push origin（cyancloudyang/sunlight）tablecloth；未 push upstream（spacefarm-digital）。PR #1 仍 OPEN/draft，未合并、未发布。
- 全套 `swift test`：710 tests、1 skipped、0 failures（skip 仍为 DockItemTests 无 bundle 用例）。生产 Canvas 模块 Swift 5、测试 target Swift 6 严格模式；编译警告均为既有基线，本轮未新增。
- 仍未验收（需用户真机再跑，ad-hoc 签名重建后须重新授予 Accessibility+Screen Recording）：#21 单击入场原位原尺寸观感；#22 首屏按 app 分组/不重叠/取景动画观感；以及第五轮遗留的 5 分钟静止 CPU/内存测量、#13–#19 视觉与卡顿复测。一律不虚构数字、不宣称达标。
- #20 真机测量仍暂停（用户转入 UX 修复）；app 已重建（build/Sunlight.app），PerfLog 可经 `defaults write com.spacefarm.sunlight PerfLog -bool YES` 开启后重启采集。
- Deferred minors（沿用第五轮）：#16 方向性运动条纹（运动模糊感，真机调，GPU 成本）；#12 活动地图新窗 noteArrived 脉冲。

## UX 修复轮（2026-11-12 第七轮，TDD 逐项）

用户真机操作后再报两个问题（#20 真机测量仍暂停）：①四指上滑不能每次都成功触发全 tablecloth 视角，有时只移动视角而未缩放；②移动视角而未缩放时，平移到另一 app 的窗口部分并点击它，窗口只原位停留在屏幕中、并未完整进入屏幕。AskUserQuestion 拍板：①「上滑即 See All」（任何明确向上的四指上滑都触发，不论速度/时长；取消四指向上平移，左/右/下仍平移）；②「最小移动滑入」（点击的窗口部分离屏时最小移动使其完整可见；已完整可见则不动）。

- #23 完成（16cbfab）：去掉 flick 的速度判定。删 `flickWindow`（0.35s）常量与 `dragBegan` 时间戳；`swipeUpSeesAll` 开启时，只要从 `dragOrigin` 起算 rise≥`swipeDistance`(0.12) 且方向在 `axisLock`(22.5°) 内接近竖直向上、四指 `landedTogether`，即发 `.seeAll`，不论快慢。水平/对角拖拽仍平移。文档同步把 "flick" 改为 "swipe up"。
  - Ruling: 保留 `landedTogether`（第四指须在 `tapLanding` 0.15s 内与前三指同落）— 用户的问题是速度/时长判定误杀慢速上滑，不是落指时序；保留它防止三指手势（Look Up/Back/Forward）后补第四指被误判为四指上滑 — 代价：极慢落指（>0.15s 才凑齐四指）的上滑不触发，但那是"手逐渐放上去"而非一次 swipe，合理。
  - Ruling: 上滑触发后取消向上平移（用户拍板"上滑即 See All"）— 向上拖拽不再是平移，左/右/下/对角仍平移 — 代价：用户失去"四指向上平移"这一方向，但这是用户明确选择（与 Mission Control 上滑一致）。仅作用于 Settings›How to use›Trackpad 选「Four-finger swipe up」时；默认仍「Four-finger tap」（`Settings.seeAllGesture` 默认 .tap），故默认行为不变。
  - 验证：TrackpadRecognizerTests 2 例改造 RED（慢速上滑给 .ended 非 .seeAll；先慢后快无 seeAll）→GREEN，新增水平/对角仍平移 2 例；filter 21 tests、0 failures；swift test 718 tests、1 skipped、0 failures。真机手势手感（慢速上滑是否稳触发、是否误触）需真机确认。
- #24 完成（efdf85b）：新增纯几何 `Handoff.slidIntoView(_:size:visible:)`：x 适配时 clamp 到 [minX, maxX−width]、超宽左对齐 minX；y 适配时只 clamp 底边 min(y, maxY−height)（顶边留给既有 menu-bar clamp，保住 inPlaceOrigin 记忆）、超高顶对齐 minY。`plan()` 在 tiledArea 分支后加 `else if clicked { origin = slidIntoView(...) }`：仅单击（无 tiling）滑入；tiled 保持区域对齐；centered/inPlace/fillScreen 不变。
  - Ruling: 只作用于 `.clicked`（用户报的是"点击"），不扩到 `.inPlace`（捏合）— 范围匹配用户问题，不蔓延 — 代价：捏合入场的部分离屏窗口本轮不滑入（用户未报；如需另议）。
  - Ruling: y 适配时只 clamp 底边、顶边留给 menu-bar clamp — 若在 slidIntoView 里也 clamp 顶边，会把 testAClickNearTheTop 的 inPlaceOrigin=−30 预先压成 38，毁掉"记住点击所求"的记忆（capture 模式相机据此落位）— 代价：无（既有 near-top/no-window-above-menu-bar 测试全绿）。
  - Ruling: 超高窗口顶对齐 visible.minY（而非"不动"）— 与 centredOrigin 超尺寸顶左对齐、x 超宽左对齐一致，最大化可见内容；"不动"可能把超高窗口大部分留在屏外 — 代价：超高窗口单击不再严格"保原位"，但它本就无法完整可见，顶对齐是合理取舍（与居中入场一致）。
  - Ruling: 两个既有断言底边溢出的测试（testAClickKeepsTheClickedSpotUnderThePointer / testACardClickEntersInPlaceRatherThanFillingTheScreen）输入改为完整可见点（click y 700→600）— 需求已变（用户要完整进屏），原断言的"底边溢出原位"不再是期望行为；改为验证"完整可见则不动" — 代价：无（新加 testAClickOnAPartlyOffScreenWindowSlidesItFullyIntoView 专门覆盖滑入）。
  - 验证：HandoffTests 6 新例 RED（no member slidIntoView + 部分离屏单击期望 origin 1200 实得 1500）→GREEN；filter 26 tests、0 failures；swift test 718 tests、1 skipped、0 failures；make app 编译打包+ad-hoc 签名 OK。滑入观感（最小移动、完整进屏）需真机确认。

## 推送与验收状态（2026-11-12 第七轮末）

- 本轮提交：16cbfab（#23 上滑即 See All）、efdf85b（#24 单击最小滑入）+ 本 ledger 更新。待 push origin（cyancloudyang/sunlight）tablecloth；未 push upstream（spacefarm-digital）。PR #1 仍 OPEN/draft，未合并、未发布。
- 全套 `swift test`：718 tests、1 skipped、0 failures（skip 仍为 DockItemTests 无 bundle 用例）。生产 Canvas 模块 Swift 5、测试 target Swift 6 严格模式；编译警告均为既有基线，本轮未新增。
- 仍未验收（需用户真机再跑，ad-hoc 签名重建后须重新授予 Accessibility+Screen Recording）：#23 慢速上滑稳触发/不误触手感（须在 Settings›How to use›Trackpad 选「Four-finger swipe up」；默认仍「Four-finger tap」）；#24 单击部分离屏窗口最小滑入观感；及第五/六轮遗留的 5 分钟静止 CPU/内存测量、#13–#22 视觉与卡顿复测。一律不虚构数字、不宣称达标。
- 开放问题（用户未答）：#22 首屏自动排布只在 remembered==nil 触发；用户已有保存布局（~/Library/Application Support/Sunlight/Canvas.json）不会触发。需用户决定：把 Canvas.json 移开重首屏，或加一次性迁移。本轮未擅自改用户数据。
- #20 真机测量仍暂停（用户转入 UX 修复）；app 已重建（build/Sunlight.app），PerfLog 可经 `defaults write com.spacefarm.sunlight PerfLog -bool YES` 开启后重启采集。
- Deferred minors（沿用第五/六轮）：#16 方向性运动条纹（运动模糊感，真机调，GPU 成本）；#12 活动地图新窗 noteArrived 脉冲。

## 一次性迁移（2026-11-12 第七轮补充，#25，TDD）

用户澄清深层意图：要窗口卡片"不堆在一起、更有真实物理交互感"，并明确选择「自动一次性迁移」（而非移开 Canvas.json）。据此把 #22 的"仅 remembered==nil 才排"改为"从未自动排布过就排一次（不论有无保存布局），打标后尊重手动"。

- #25 完成（e757e4a）：新增持久化标记 `Settings.didAutoArrange`（UserDefaults key "CanvasDidAutoArrange"，默认 false，仿 LegacyMigration.doneKey 模式）。`FirstArrangement.shouldArrange` 参数由 `remembered:` 改为 `alreadyArranged:`（body 仍 `!x`，语义从"无保存布局"变为"从未自动排过"）。`autoArrangeFirstCanvas()` 改守 `Settings.didAutoArrange`，layOutTidy 成功后置 true。两处 first-sync 钩子（live :2474 / capture :2642）把分支重排为 `if !autoArrangeFirstCanvas() { if placed, let camera … { animateCamera } else { fitAll } }`——一次性排布优先于"恢复保存相机"，仅那次；打标后走原恢复路径。
  - Ruling: 用 UserDefaults 标记而非改 Layout 模型 — 仿既有 LegacyMigration（doneKey）一次性迁移模式，附加式、不触碰 Canvas.json 结构/编解码，旧布局文件原样可读 — 代价：标记在 defaults 域而非布局文件里，若用户只删 Canvas.json 不删 defaults 则标记仍在（不会重排）；这正是"严格一次"所要。
  - Ruling: 触发门从 remembered==nil 改为 !didAutoArrange，并把 autoArrange 提到 saved-camera 恢复之前 — 旧逻辑下"有保存布局+保存相机"分支直接 animateCamera、永不 autoArrange，故迁移必须抢先一次；重排对 flag=true 情形行为不变（autoArrange 返回 false→原恢复路径），对全新用户也不变（placed=false→autoArrange）— 代价：无（既有 first-sync 语义保留）。
  - Ruling: 仅在 layOutTidy 成功（有 standsAlone 窗口）时打标 — 标记意为"确已排过一次"；首屏无独立窗口（全 widget/attached）的极罕见情形不打标，但 didInitialFit 已门控、本次启动不再重试 — 代价：该极罕见情形本次启动不排（与 #22 既有的 first-sync-only 限制一致）；用户实际场景首屏即有 app 窗口，迁移会触发。
  - Ruling: 复用 layOutTidy 故迁移可 ⌘Z 撤销（名 "Tidy"）、相机同 motion 取景、rememberSoon 持久化 — 与手动 Tidy/首屏排布完全同路径，真实窗口经既有 canvas→real 同步随动 — 代价：无。满足"可撤销、不擅自不可逆改数据"。
  - Ruling: 范围只做迁移；用户提到的"更有真实物理交互手感"是更大方向，本轮不顺手扩入（无 brainstorm/设计），迁移完成后可另议 — 代价：物理手感本轮未动，已明示。
  - 验证：FirstArrangementTests 改 2 例 + SettingsTests 新增 testDidAutoArrangeDefaultsOffAndRoundTrips RED（no member didAutoArrange / 错参数标签）→GREEN；swift test 720 tests、1 skipped、0 failures；make app 编译打包+ad-hoc 签名 OK。迁移真机效果（旧布局首屏被按 app 排一次、之后尊重手动、⌘Z 可回退）需用户真机确认。

## 推送与验收状态（2026-11-12 #25 末）

- 本轮提交：e757e4a（#25 一次性迁移）+ 本 ledger 更新。待 push origin（cyancloudyang/sunlight）tablecloth；未 push upstream（spacefarm-digital）。PR #1 仍 OPEN/draft，未合并、未发布。
- 全套 `swift test`：720 tests、1 skipped、0 failures（skip 仍为 DockItemTests 无 bundle 用例）。生产 Canvas 模块 Swift 5、测试 target Swift 6 严格模式；编译警告均为既有基线，本轮未新增。
- #22 遗留开放问题已解决：用户选「自动一次性迁移」，#25 实现之；不再需要用户移开 Canvas.json。用户现有保存布局将在升级后首屏被按 app 排一次（可 ⌘Z 撤销），打标后尊重手动。
- 仍未验收（需用户真机再跑，ad-hoc 签名重建后须重新授予 Accessibility+Screen Recording）：#25 迁移真机效果；#23 慢速上滑手感、#24 单击滑入观感；及第五/六轮遗留真机项。一律不虚构数字、不宣称达标。
- 深层方向（用户提及、本轮未做）：窗口卡片"更有真实物理交互手感"——待迁移验收后如需可单独 brainstorm。
- #20 真机测量仍暂停。Deferred minors 沿用第五/六轮。

## 默认手势修正（2026-11-12 第七轮补充，#26，TDD）

用户真机再报：「四指上滑还是没能进入全览视角，还是普通高度平移」。系统排查（systematic-debugging）根因：`defaults read com.spacefarm.sunlight CanvasSeeAllGesture` 不存在 → getter 回退 `.tap`；tap 模式下四指上滑就是平移、永不 See All（日志全是 `Pan: four-finger drag`，无一条 See All）。#23 的去速度判定只作用于 `.swipeUp` 模式，接线（`followSetting` 读 `Settings.seeAllGesture == .swipeUp`）正确无误——不是代码 bug，是「用户已选上滑、但默认仍是 tap」的开箱落差。

- #26 完成（bd19f28）：`Settings.seeAllGesture` getter 缺省回退由 `.tap` 改为 `.swipeUp`（key 不存在时即上滑模式）。UI picker（GestureGuide）、手势指南 `gestures(seeAll:)`、教程 `resolved(seeAll:)` 均动态读该值，自动随之显示「Four-finger swipe up」；Tutorial 一处过时注释「the tap by default」改为「swipe up by default」。tap 仍可在 Settings›How to use›Trackpad 选回。
  - Ruling: 改默认而非仅让用户手动切设置 — 用户在 #23 已明确拍板「上滑即 See All」，默认留 .tap 等于该选择开箱不生效，正是本次报修；改默认才兑现其意图 — 代价：偏好「四指轻点=See All」的用户开箱变为上滑，需手动切回 tap；但这是用户个人 fork 且其已明示偏好，tap 仍可一键选回。
  - Ruling: 此改动取代 #23 Ruling 中「默认仍 .tap，故默认行为不变」一句 — 默认行为自此改变（上滑即 See All），#23 的识别器逻辑不变 — 代价：无（识别器/测试不变，仅缺省值）。
  - Ruling: 可逆、不动已保存状态 — 仅改 UserDefaults 缺省回退，不写任何 key、不触碰 Canvas.json/布局；用户现有显式设置（若有）原样优先 — 代价：无。满足「不擅自改已保存/手动状态、优先可逆」。
  - 验证：SettingsTests 新增 testSeeAllGestureDefaultsToSwipeUpAndRoundTrips RED（"tap" is not equal to "swipeUp"）→GREEN；swift test 721 tests、1 skipped、0 failures。真机：当前运行中的旧 build 无需重建即可验证——在 Settings›How to use›Trackpad 把 See All gesture 切到「Four-finger swipe up」，上滑即应 See All（followSetting 监听通知即时生效）；新默认需重建+重 launch 才生效（ad-hoc 签名，重 launch 须重新授予 Accessibility+Screen Recording）。
  - 环境注：`security find-identity -v -p codesigning` 返回 0 valid identities，故 make app 仍 ad-hoc；无稳定签名身份可让授权跨重建保留（不擅自创建证书/改钥匙串）。

## 推送与验收状态（2026-11-12 #26 末）

- 本轮提交：bd19f28（#26 默认上滑即 See All）+ 本 ledger 更新。待 push origin（cyancloudyang/sunlight）tablecloth；未 push upstream（spacefarm-digital）。PR #1 仍 OPEN/draft，未合并、未发布。
- 全套 `swift test`：721 tests、1 skipped、0 failures（skip 仍为 DockItemTests 无 bundle 用例）。生产 Canvas 模块 Swift 5、测试 target Swift 6 严格模式；编译警告均为既有基线，本轮未新增。
- 仍未验收（需用户真机）：#26 上滑默认即 See All（旧 build 切设置即可即时验证；新默认需重建重 launch+重授权）；#25 迁移真机效果；#23 慢速上滑手感、#24 单击滑入观感；及第五/六轮遗留真机项。一律不虚构数字、不宣称达标。
- #20 真机测量仍暂停。Deferred minors 沿用第五/六轮。

## 空间相机设计批准（2026-11-12，#27，关键交接节点）

用户批准设计文档（「同意，开始吧。关键节点要确保其他的 agent 可以接手。」）。方案甲：先 A（跟手入场 + 入图逐卡飞行）后 B（指针意图 dwell-to-zoom 导航），A 真机验收后再细化 B。

- 设计文档（权威）：`docs/superpowers/specs/2026-11-12-spatial-camera-design.md`，提交 6efcf5a + 状态更新。§7.3 为建造者审查 7 问落定表，**无遗留「只有用户能答」项**。接手 agent 读该文档即可 plan，不必回问用户。
- 地基性事实已亲自读码核实（非推测）：`mapDidHide`(CanvasController:8367) 不清 proxies（隐藏期整套保留）；`snapshot(at:)`(:5665) 同步取 fresh WindowList+相机(~1ms)；`FrameSnapshot.worldOrigin`=camera.toWorld(frame.origin)；`enter()`(:5877) enteredCamera=view.camera（tile/PiP zoom≠1 caveat :5878）；`placeNewWindows`(:3688) 直接 place 无飞行（分裂感来源）；`flightRect`(Handoff:124) clamp[0,1]；`fly`(CanvasView:1303) 可重定向保留速度；`interruptMotion`(:1357)。
- Ruling（Q2 起始相机）：入图从 view.camera（=enteredCamera，聚焦窗 1:1）起步，不强制 home — 强制 home 会先跳再拉远，正是「无分裂感」反面 — 代价：tile/PiP 入图 zoom≠1 时飞行起点有缩放差，必要时该情形退化为 fly（真机确认）。
- Ruling（Q3 A2 作用域）：逐卡飞行只用于「从真实堆叠桌面入图」（上滑/热键/菜单，canvas 隐藏且真实桌面在）；F3 单窗返回(flightBack)保留既有相机飞行，本轮不扩逐卡飞 — 依据用户措辞「从当前屏幕的堆叠状态」隐含多窗堆叠 — 代价：若用户期望 F3 返回也逐卡飞，本轮未做，可后续扩（已明示用户）。
- Ruling（Q4 幂等）：已在俯瞰(view.camera isClose overviewCamera)再上滑=幂等 re-fit，不重复飞卡；进度驱动仅用于从真实桌面入图 — 沿用 #23/#26 上滑=See All — 代价：幂等阈值太松则微上滑触发无谓 re-fit，真机调。
- Ruling（Q5 取消/打断）：取消（释放未过 commit）相机+卡片同一 t 反向飞回真实起点（整段可逆）；打断（飞行中其它输入）interruptMotion 落到目标、新输入接管 — 用户「可取消」意图+既有 interruptMotion 语义 — 代价：取消时卡片与相机须同一 t 反向否则脱节。
- Ruling（Q6 过冲）：卡片 clamp[0,1] 不过冲（沿用 flightRect），相机 Spring(0.45/0.72) ~4% 过冲；释放动量经 fly 传入弹簧 — 既有 handoff 同款 — 代价：落位瞬间卡片先停相机后停，可接受。
- Ruling（Q7 PiP/widget/attached）：PiP drawnPip 忽略相机→不飞保持屏幕角；attached 随父飞；widget 无真实堆叠位→存储位淡入(setArrival) — 沿用既有模型 — 代价：PiP 入图仍占屏幕角可能与俯瞰构图重叠，真机确认。
- 下一步：invoke writing-plans 出 A 部分实现计划（docs/superpowers/plans/），TDD 逐项 RED→GREEN→全套件；每关键节点 commit+push origin（cyancloudyang/sunlight）tablecloth，绝不 push upstream。PR #1 保持 draft 直到用户验收。
- 硬约束沿用（逐条生效）：不关 SIP/不注入系统进程/低占用/零常驻流/私有 API 仅可选有公开兜底（MultitouchSupport 既有）/不改系统偏好不做登录项/许可证边界/只 push origin。
- 仍未验收（真机）：#26/#25/#23/#24 及第五/六轮遗留；空间相机 A/B 待实施后真机验收。一律不虚构数字、不宣称达标。#20 真机测量仍暂停。

## 空间相机 Part A 实施（2026-11-13，#28，TDD）

按已批准计划 `docs/superpowers/plans/2026-11-12-spatial-camera-entry.md` 逐任务执行；起点 `origin/tablecloth = 87fd379`（fetch 后未前移，工作树干净）。每个任务 RED（看着失败）→GREEN→全量 `swift test`→本 ledger→commit→push origin。

### #28 Task 1 完成：识别器入场进度相位（TrackpadPan）

- 内容：`TrackpadPan.Phase` 增 `.entryBegan/.entryProgress(CGFloat)/.entryEnded`；新常量 `entryDistance=0.30`（可调）；识别器新状态 `entryActive`。swipeUp 模式下上滑不再发一次性 `.seeAll`：达 `swipeDistance`(0.12) 起 `.entryBegan` + 首个 `.entryProgress(0)`，其后每帧按 `(rise−swipeDistance)/(entryDistance−swipeDistance)` 发进度（钳制 [0,1]，回拉可 scrub 回 0）；`reset()` 在 entry 活动时发 `.entryEnded`（取代 `.ended`）。tap 模式 `.seeAll`、普通 pan、spread 均不变。
- 测试：`Test`/`TrackpadRecognizerTests` 22 项全绿（原三条 seeAll 断言替换为 4 条 entry 断言，tap/水平/对角三条加 `!entryBegan` 断言）。
- 全量：`swift test` → **722 tests, 1 skipped, 0 failures**（skip 为 `DockItemTests.testTheAppsOwnBundleIsItsIcon`，runner 无 app bundle）。
- Ruling: 计划里 `TrackpadRecognizerTests` 的 `XCTAssertEqual(ts.first, 0, accuracy:)` 不能编译（`CGFloat?` 非 `Double`）→ 改为 `ts.first ?? -1` — 计划文本的机械笔误，语义不变 — 代价：无。
- Ruling: Task 1 只改识别器时 `Desk.trackpadPan` / `CanvasController.trackpadPan` 的 phase 穷尽 switch 编译失败 → 本任务先加 inert `case .entryBegan, .entryProgress, .entryEnded: break` 占位，路由与编排按计划在 Task 3 落地 — 保持任务粒度（Task 1 只碰识别器+其测试）且编译必须通过 — 代价：Task 1 与 Task 3 之间上滑入场在 app 内 inert（计划 Notes 已预期），此时上滑不再 See All。
- 待真机验收：`entryDistance` 0.30 与起算点（0.12→0.30 区间）的实际跟手行程需真机确认，未调未测。
