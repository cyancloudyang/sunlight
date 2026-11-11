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
