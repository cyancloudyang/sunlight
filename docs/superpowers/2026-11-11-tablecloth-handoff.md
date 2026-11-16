# Tablecloth 跨 coding agent 交接

更新：2026-11-11。用户要求因 Qoder 额度有限停止实现，保存接手材料。本文记录的是**未完成、当前无法编译的开发现场**，不是发布说明。

> **状态更新（2026-11-11 第五轮后，当前）**：分支 tablecloth，HEAD `7490488b37caaaac93866af60ee5181757b09d9f`，工作树干净，**已全部 push 到 origin（cyancloudyang/sunlight）**，PR #1 OPEN/draft（https://github.com/cyancloudyang/sunlight/pull/1），未合并、未发布。Tasks 1–8、安全审查 #1–#11、用户 7 条反馈 #12–#18 均已实现并各自 TDD 落地。最新全套 `swift test`：**702 tests、1 skipped、0 failures**（skip 仍为 DockItemTests 无 bundle 用例）；136 条编译警告为既有 Swift 6 严格模式基线。第五轮（反馈优化）提交 `4f37a71..7490488`：#12 提示常驻、#13 引导按钮固定中下部、#14 背景随相机渐模糊、#15 手势入图拉远、#17 opt-in 真实桌面（发系统 F11）、#16 ⌘Tab 更高弧（rho 1.6，不接管）、#18 返回地图优先窗口列表而非主线程同步 AX 帧（消除日志 1336ms 卡顿）。**仍未验收（需用户真机再跑，不虚构数字）：5 分钟静止 CPU/内存、#13/#14/#15/#16 视觉观感、#17 真实桌面系统交互、#18 卡顿降幅复测。** deferred minor：#16 方向性运动条纹、#12 活跃地图新窗口脉冲。#18 后续候选（未做）：其余主线程 AXWindow.frame 同步点、listNow/snapshot 的 WindowList.queue.sync hop、主 runloop 计时器合并。接手以 [ledger](2026-11-11-tablecloth-ledger.md) 与当前代码为准；下文第 2 节 HEAD/push 状态已更新，第 5–7 节为历史。
>
> **状态更新（2026-11-11 第二轮后）**：本文第 5 节描述的未编译补丁已由接手 agent（marvis）完成并分 13 个提交落地（`5c185f5..084ac6f`），审查 #1–#11 全部处理、#12 仍 deferred。Qoder 主会话已独立复核：全新 `swift test` 679 项、1 skipped、0 failures；`build/Sunlight.app` 无 Helpers/LaunchDaemons/Sparkle 键、codesign 通过且晚于最后代码提交；#1/#2/#8/#11 的关键 diff 已亲验。详见 [ledger](2026-11-11-tablecloth-ledger.md) 末尾两条记录。**仍未做：真机交互与资源实测（未验收）、发布。** 下文第 5–7 节保留为历史记录，接手者以 ledger 与当前代码为准。

## 1. 接手入口与权威顺序

1. 阅读本文，以及 [已批准设计](specs/2026-11-10-tablecloth-design.md)、[实现计划](plans/2026-11-10-tablecloth.md)。
2. 阅读 [执行记录归档](2026-11-11-tablecloth-ledger.md)：完整保留此前的 Ruling、取舍及代价，不依赖 Qoder 历史或隐藏目录。
3. 查看当前 `git status`、`git diff`、未跟踪文件及日志，以实际代码为准；本文只保证交接时间点的状态。
4. 用户硬约束高于计划中的疏漏；设计约束高于旧测试/上游行为。历史 Ruling 不可用来豁免已确认的安全或功能缺陷。

用户已批准“快照地图（最省）”“平滑缩放动画”“Native，执行吧”。保持这条路线，不重新选架构，不从头重做 Tasks 1–8。计划里“当前 main”等描述是实施前的历史背景，不是现在的状态。

接手不要求安装任何 Qoder skill、MCP 或插件；普通文件读写、git、Swift 工具链即可。用户可复制 [接手 prompt](2026-11-11-tablecloth-prompt.md)。

## 2. 仓库、分支与本地数据

```text
本地仓库 /Users/cycloudyang/Documents/Qoder/2026-11-10/4aceb90d/sunlight
分支     tablecloth
HEAD     7490488b37caaaac93866af60ee5181757b09d9f（第五轮后；历史交接点为 22e7da9）
基线     cf7aa16fa0035fa867529787dce02bd3d3ca5e60（Sunlight 0.2.4）
origin   https://github.com/cyancloudyang/sunlight.git
upstream https://github.com/spacefarm-digital/sunlight.git
```

**当前（第五轮后）：功能提交、安全修复、反馈优化与交接文件均已 push 到 origin 的 tablecloth（`0d54a41..7490488`），PR #1 OPEN/draft，未合并、未发布。** 同机请直接打开上述目录；换机请保留仓库的 `.git` 与 `.superpowers/sdd/2026-11-10-tablecloth/` 的记录与日志。`.build` 是可重建缓存，不是源码交付物（测试构建需 `.build/out/Products/Debug/PackageFrameworks/Sparkle.framework` 符号链接，`swift package clean` 后需重建）。

不要 reset、restore、clean、覆盖未提交补丁或重建仓库来“恢复干净”。不要自动改 git config、跳过 hooks、amend 或强推。只允许 push 用户 fork 的 origin，绝不 push upstream。发布动作应遵守接手环境的权限确认要求；用户此前批准的范围仅限该 fork。

## 3. 产品路线与不可突破的边界

目标：macOS 桌面成为一张巨大虚拟桌布，窗口有稳定世界坐标；像 RTS 地图一样平移、缩放、保存视角，点击窗口平滑飞入真实窗口，F3 返回原位。地图是定格快照，不要求内容实时更新。

- 不关闭 SIP，不做任何 SIP 相关改动，不注入系统进程。
- 不改 Dock、Finder、系统手势、Stage Manager 等系统偏好；不做 takeover、登录项或辅助守护进程安装。
- 零常驻捕获流：禁止 SCK stream / CGDisplayStream。一次性截图可以使用 ScreenCaptureKit，但不能创建流。
- 私有 API 仅可选，必须有实际可用的公开兜底；不能靠强链接后写一个不可到达的 fallback。
- CPU、GPU、内存尽量低；默认关闭轮换刷新；快照最长边 ≤ 1024px；隐藏/睡眠不继续捕获。
- macOS 15+、Apple Silicon；v1 仅主屏，不扩展多显示器、虚拟屏、PiP、桌面小组件等范围。
- 只需辅助功能和屏幕录制两个权限。权限授予由用户决定，不自动修改权限、安全设置或触发系统改造。
- Sunlight、orcv 为 MIT，可以保留署名改编；canvasWM、minfwm 无许可证，只借鉴思路，不复制代码。
- 资源目标是地图静止 CPU ≈ 0、典型内存 < 100MB、聚焦开销 ≈ 0；**这些均未实测达标**。不透明遮挡可能降低后方应用绘制负载，不保证所有应用 CPU/GPU 归零。

架构继续复用 AppKit + Core Animation、Sunlight 快照渲染器、CameraPath 与 Layouts。世界坐标不等于真实窗口位置；地图平移/缩放不能用持续 AX resize 模拟。真实 resize 只用于聚焦切换。

## 4. 已提交工作与验证范围

| 提交 | 已实现的主体 |
|---|---|
| `841ae9f` | 设计与实现计划 |
| `f2dc70e` | capture-only 默认、零流设置、两权限方向、移除主要 live upsell |
| `8ec00f1` | 不透明画布、召唤式隐藏策略 |
| `d6646ae` | 事件刷新策略、轮换默认关闭 |
| `cd6ba5e` | 充屏聚焦/返回、保存 frame、相机与卡片飞行 |
| `268b58d` | 悬停阴影、远距名称牌、脉冲环、光标反馈 |
| `2229140` | 1–9 跳转 / Ctrl+1–9 保存、WASD/方向键、Space 全景、持久化 |
| `ab8b1bd` | 前五次地图提示条、菜单重看 |
| `22e7da9` | 同标题窗口在完整候选集合中的确定性匹配、初始坐标测试 |

Tasks 1–8 的实现提交及各自测试门已完成，但**不代表集成功能已经验收**：整分支审查发现下面的阻塞项，真机检查一直延后到 Task 9。

最后一次全绿对应上述 HEAD、尚未添加当前安全补丁时：

- `swift test`：609 个 XCTest，1 skipped，0 failures。
- skip：`DockItemTests.testTheAppsOwnBundleIsItsIcon`，测试 runner 没有 app bundle。
- `swift build -c release`：exit 0；不是零警告，有并发/导入和 trailing-closure 等警告。
- 原始日志：`.superpowers/sdd/2026-11-10-tablecloth/task-9-suite.log`、`task-9-release.log`。
- 日志末尾 Swift Testing 的“0 tests”不能替代前面的 XCTest 总数。

没有启动 Sunlight GUI，没有完成安全打包，没有五分钟 CPU/内存测量。不能把旧提交的绿色测试套用到当前 dirty tree。

## 5. 当前未提交补丁：先保留，再完成

交接时 `git status --short`：

```text
 M Sources/Canvas/App.swift
 M Sources/Canvas/CanvasController.swift
 M Sources/Canvas/Desk.swift
 M Sources/Canvas/Setup/SetupFlow.swift
 M Sources/Canvas/Setup/SetupWizard.swift
 M Sources/Canvas/Takeover/KeyTap.swift
 M Tests/CanvasTests/SetupFlowTests.swift
 M Tests/CanvasTests/SwitcherKeysTests.swift
?? Sources/Canvas/Takeover/CanvasInput.swift
```

### 补丁意图与实际范围

- 新 `CanvasInput`（MainActor）持有 `KeyTap` 和 `ForegroundWatcher`，把前台/AX 事件转发给 `Desk`，只有 start/stop；不构造 `SpacesWatcher`，不设置偏好或登录项。
- `App` 将实例属性改为 `input: CanvasInput?`；启动时在开关开启且 AX 已授权时 start。移除了主要 TakeoverMode 构造、Stage Manager 修改、guard 启动、迁移、接管同意弹窗、普通退出恢复偏好和卸载路径等调用。
- `--release` 改为说明 Tablecloth 不改系统偏好后退出；`--status` 仍用旧的只读状态函数。帮助文案和部分 legacy 入口尚未审完。
- `Desk.takeover`、Controller 的 `takeover/env` 类型改为 `CanvasInput?`，名字暂时保留；删除了依赖旧 `ignoreActivationsUntil` 的 guard 条件。
- `SetupFlow` 不再路由登录项页，不再把跳过录屏当成已满足；只调整了部分测试。
- `SetupWizard.chooseLoginItem` 删除 Stage Manager 与 LoginItem 的系统操作；旧页、录屏 Skip 按钮和部分误导文案还在。
- `KeyTap` 实际 keyDown 改走新 `summonAction`：仅无修饰 Mission Control 160 / F3 99 触发；autorepeat 吞掉；release 支持二者；其他系统快捷键透传。旧 `action` 和旧测试仍保留，不代表 runtime 仍用旧路由。
- 新增了系统快捷键透传测试。**尚未完成可配置备用热键、输入/权限生命周期集成测试、Settings/MenuBar 残留入口清理。**

### 当前确定的失败

最近运行：

```bash
swift test --filter 'SetupFlowTests|SwitcherKeysTests'
```

结果 **exit 1，编译失败，尚未执行这些测试**。日志：`.superpowers/sdd/2026-11-10-tablecloth/handoff-current-tests.log`。

已读取并核实的四处错误（交接时行号）：

| 位置 | 残留引用 |
|---|---|
| `Sources/Canvas/App.swift:328` | `actions.takeOver` 调用已删除的 `takeOverTheMac()` |
| `Sources/Canvas/App.swift:329` | `actions.release` 调用已删除的 `releaseTheMac()` |
| `Sources/Canvas/App.swift:374` | `moreMenu()` 的 `#selector(takeOverTheMac)` |
| `Sources/Canvas/App.swift:375` | `moreMenu()` 的 `#selector(releaseTheMac)` |

下一步是删除/改正这些危险功能的残留接线与对应 UI，**不是为了编译通过把 takeover 实现接回去**。`Settings.swift` 的 General 页仍有接管 toggle、旧说明、卸载按钮；当前 App 已断开回调，它们是无效 UI，尚待移除。`MenuBarPanel` 也需查实际展示与动作，不能仅断回调便称完成。

前面的 RED 证据：`final-safety-red.log` 有登录项路由与跳过录屏的两项断言失败；`final-summon-red.log` 是缺少 `summonAction` 的编译 RED，证据比行为断言弱。补丁后没有局部 GREEN 或 full-suite GREEN；编译修好后其他旧 setup 预期仍可能失败，须实际运行判断。

## 6. 已完成的独立审查：阻塞清单

一次只读整分支审查已完成，范围 `cf7aa16..22e7da9`，41 个净变更文件及相关调用者；结论 **不应合并**。它审的是已提交版本，不是当前半成品补丁。原 diff 在 `.superpowers/sdd/2026-11-10-tablecloth/review-cf7aa16..22e7da9.diff`，也可用 `git diff cf7aa16..22e7da9` 重建。

不要重复付费跑整分支审查。既定流程是核实已有 findings，修 Critical/Important，逐项 RED→GREEN + 全套测试；Minor 记录延后。审查的行号可能漂移，以下给出文件/符号作为定位依据。除已直接核实的安全入口/权限路由外，其余是审查报告，接手者仍需按代码确认根因，不可机械照改。

### #1 Critical：setup/startup 仍可修改系统

原 `SetupWizard.chooseLoginItem` 默认注册登录项并关闭 Stage Manager；`TakeoverMode.start/apply` 可因旧 opt-in 改系统偏好、调用 `Spaces.fold` 合并桌面；菜单也有入口。当前补丁只做了一部分切断。

完成条件：普通启动、旧设置升级、setup、菜单、退出及异常路径都不触发系统偏好/登录项/Spaces 操作；输入监听独立启动。旧 `TakeoverMode`、`Stability.putMacBack` 等代码尚在，不可为验证而执行；需检查剩余可达入口及包内 payload。

### #2 Important：缺少运行时权限门控

旧录屏 Skip → Open Canvas，但 capture 模式枚举失败并不会自动造出所承诺的可用占位，只会日志/再排队。`App` 的 `setup.onStatus` 仍只更新菜单进度，当前启动也仍先 show canvas。

完成条件：未授权/撤销授权阻止 show/sync/focus/capture，显示两权限引导；授权变化能正确启动/停止输入与捕获。删除无效 Skip 与错误说明。只改 `SetupFlow.page` 不够。

### #3 Important：成功聚焦后不隐藏不透明地图

`CanvasController.enter` 先设 `activeProxy` 再激活应用；`hideMapForForeignFront` 要求 `activeProxy == nil`，聚焦成功并未显式 orderOut。固定尺寸/被钳制窗口周围仍可能露出地图，聚焦零工作也未达成。

完成条件：handoff 结束显式隐藏地图并暂停地图工作，返回时正确恢复；验证固定尺寸与 AX 钳制窗口。

### #4 Important：聚焦中退出会保存临时几何

`App.applicationShouldTerminate` 的 shutdown/remember 路径会把放大的 proxy rect 和聚焦 camera 保存，真实窗口也未恢复。旧 ledger 称它“可能因 watcher 触发”，审查确认退出路径本身就足够，不可继续当可接受风险。

完成条件：canonical 地图 worldRect/camera 与飞行动画临时状态分离；聚焦中保存、退出、重启都不污染布局；正常退出恢复真实 frame。同时测试事件保存和退出保存。

### #5 Important：F3 原依赖 takeover，返回飞行会被 fitAll 打断

旧 KeyTap 只有 takeover 启动才可用；当前 `CanvasInput` 已开始解除依赖，但未验收。`CanvasController.missionControl/showCanvas` 的 `fitAll: true` 会经 pendingFitAll/reconcile/animateCamera 打断逆向飞行。

完成条件：无需 takeover 也能全局召回；检查现有 hotkey 机制并实现可配置备用热键；F3 返回使用保存的 camera，不自动全景；重复键/取消/非地图快捷键不能吞错。Secure Keyboard Entry 等限制要如实说明，不能承诺绕过。

### #6 Important：实际 frame 读回不等于完整视觉 handoff

去程 resize 后改 frame 就激活，无 resize 后截图屏障与末端 crossfade。返程发起异步截图立刻 AX restore，可能截到恢复尺寸后的内容。`WindowProxy.refresh` 尚无完成屏障/代次控制。

完成条件：明确转换阶段、截图完成顺序、crossfade 和取消代次；关闭/最小化/换前台/连续召回时不接受旧 completion。测试截图与 AX 操作的时序，真机验证无黑帧/闪烁/露桌面。历史“resize 放在 flight completion”取舍不能冒充 crossfade 已实现。

### #7 Important：没有 1024px 纹理上限

`WindowCapture.swift` 的公开/私有路径返回原尺寸图像，`WindowProxy` 直接 retain；每张高分屏截图可能很大。

完成条件：每条实际保留截图的路径（包括 seam、可选私有和桌面路径）最长边 ≤ 1024，保持比例，不放大小图；测试尺寸与边界。未实现上限时不能声称内存目标可达。

### #8 Important：私有 API 仍是硬依赖

`OneShotCapture` 的公开 `SCScreenshotConfiguration/captureScreenshot` 分支只支持 macOS 26+，此前版本退到私有路径；按 windowID 的桌面捕获也 private-only。`AX.swift` 用 `@_silgen_name("_AXUIElementGetWindow")` 强链接，后面的 frame fallback 无法弥补符号不可用。

完成条件：macOS 15 部署范围内可用的公开一次性截图；候选为 macOS 14+ 的 `SCScreenshotManager.captureImage(contentFilter:configuration:completionHandler:)`，**先核对 SDK 声明**。使用 `SCStreamConfiguration` 作为截图配置不等于启动流。AX 私有符号可选动态查询并提供 public frame matching；检查所有 windowID 调用者。不扩展桌面功能，移除不可达/非目标入口也可以，但留下的路径必须满足约束。

### #9 Important：隐藏/睡眠后的计时器与异步捕获未全停

轮换关闭仍有 4Hz refresh timer；`mapDidHide` 只停其中一个，listing/heartbeat 等继续。睡眠前未完成的枚举可在结束后创建 proxy/截图，`WindowProxy.refresh` completion 后排队的 seam 仍可能再次捕获。

完成条件：统一 map 工作资格和 lifecycle generation，停掉隐藏/睡眠下不必要的 timer，拒绝过期枚举/截图 completion 与后续排队；仅有实际轮换工作时开轮换 timer。保留必要的事件监听不等于已证明零空闲开销，需要测量。

### #10 Important：同标题匹配依然受分批到达顺序影响

`Layouts.match` 对每次候选排序，但 Controller 恢复只看本批新 proxy 并消费 saved entry；先到 `[102]` 再到 `[101]` 与一次 `[101,102]` 仍可有不同结果。Task 8 只证明完整候选集合中的稳定排序。

完成条件：为启动增量候选制定稳定匹配/重算策略，加入 staggered-batch 回归测试；不能重排用户已手动移动的窗口。不要求跨重启识别完全不可区分窗口的真实身份，但要明确、确定地尽力匹配。

### #11 Important：打包仍包含注入 helper，更新信任指向上游

`packaging/release.conf` 的 feed/key 仍是上游；`scripts/package.sh` 写入 Sparkle 元数据，并运行 `build-live-windows.sh`、拷贝 `SunlightLiveWindows`，有签名时还附带 LaunchDaemon。fork 可能被更新回上游而失去安全边界。

完成条件：禁用更新检查直到 fork 有自己的 feed/key，不能编造 URL/key；移除 helper/LaunchDaemon 构建与打包路径，检查安全产物。**现阶段不要运行 `make app` 或 package.sh。** 包含 helper 不等于已注入；本会话没有运行打包或注入。

### #12 Minor：活跃地图上的普通新窗口缺脉冲

Controller 的 `noteArrived` 与 foreign-front bookkeeping 绑定，活跃地图的普通新窗口未走该反馈路径。建议以后将视觉反馈与该 bookkeeping 分离；当前按审查流程明确延后，不顺手扩充修复范围。最终报告不能宣称这一项已实现。

审查没有“Declined to judge”项。另有少量未证实的光标/提示条边缘疑点，不是已确认 bug，不据此扩展任务。

## 7. 推荐继续顺序与最小回归边界

1. **先完成现有安全补丁（#1/#2/#5 输入部分）**：处理上述四处编译错误；清理实际 UI 入口；完成权限授予/撤销与 input start/stop；局部测试转绿，再跑全套。不要用修改旧测试来保留不允许的 takeover 行为。
2. **兼容与内存（#7/#8）**：公开 one-shot 降级、可选 AX symbol、图像尺寸上限；覆盖私有 API 不可用与低版本可用分支。
3. **聚焦状态机（#3/#4/#5 返回/#6）**：canonical 持久化、截图屏障、隐藏/crossfade/取消；覆盖 AX 钳制、目标消失、聚焦中退出、连续切换。
4. **后台工作（#9）**：隐藏/睡眠/权限丢失时阻止新工作和 stale completion，测试 pending enumeration 与 queued seam。
5. **增量匹配（#10）**：分批到达顺序不同仍稳定，用户手动位置不被后续批次覆盖。
6. **安全打包（#11）**：在运行构建脚本前修它及 updater 配置。普通 `swift build` 成功不代表 app bundle 安全。
7. 全套测试 + release build + 安全 bundle 检查 + 真机验收，再决定 fork 提交/推送/PR；不要把未验收版本标记 ready。

先读代码确认每项根因，再测试先行，看到预期 RED 后最小修复、GREEN、全套测试。不能只跑自己改的文件；既有失败也要逐项报告，不能在日志里略过。对这次已经写了一半的补丁，保留现场、补齐行为验证并记录现有 RED 的局限，不为了重演仪式丢弃用户工作。

实现继续由主 agent 原生执行；不需要每任务派实现/审查 agent。更新进度记录，按有意义的修复单元提交；不要无关重构或 Swift Testing 迁移。审查证据所指缺陷核实后若选择不修，必须向用户解释取舍及代价。

## 8. 关键接口与实现陷阱

- SwiftPM executable target/module `Canvas`，binary `Sunlight`；Swift language mode 5；XCTest、`@testable import Canvas`。
- `Camera` = origin + zoom，上左坐标；已 Equatable/Codable。`CanvasView.fly(to:step:completion:)` 复用 van Wijk–Nuij `CameraPath` + spring；`animateCamera` 是直线中心插值/log zoom，不能拿来替换长距离飞行。
- `trackpadPan(by:)` 参数是屏宽归一化 travel，不是 point；内部 `delta = travel * bounds.width * 1.5`。键盘 120pt 步长需除 width*gain，然后 `trackpadPanCancelled()` 释放 synthetic hold（不丢 pending input）。
- `Desk` 是布局持久化 owner。复用 Sunlight `Layouts`，**不另建**设计概念中的 `Tablecloth/Layout.json`。`Layout.bookmarks` 为可选 `[String: DisplayCamera]`，`sameArrangement` 已比较它；slots 由 Desk 共享，不按显示器分叉。
- `Layout.match` 顺序为 ID → widgetID → document → title → sameApp；Task 8 只把 free candidates 按 windowID 排序。
- 首次 identity Camera 下 proxy.worldRect 等于 physical frame；非 identity 下新窗口原点需转 world，不可把测试扩成“始终直接等于物理 frame”。
- 聚焦字段包括 `focusSavedFrame/ID`、`focusMapRect`、`focusReturnCamera`、`focusGrownRect`、`focusReturnProxy`；先理解现有取消路径，避免再叠一套互相竞争状态。
- `Handoff` 纯函数测试不证明 Controller 的异步顺序、真实 AX 效果或 crossfade。
- `WindowProxy.refresh` 失败保留旧纹理、清 refreshing，不重试空转；补生命周期时别破坏这个已存在的行为。
- `OverlayView` 是 flipped；`covers` 依据 subview frame/isHidden，不是 hitTest，透明提示视图可能影响覆盖判断。
- `HintPolicy` 为前五次；兵牌 zoom<0.35，compact<0.8，悬停优先；脉冲应尊重 reduce motion。小地图/zoom readout 原本默认开启，保持已有 opt-out。
- `TakeoverMode`、`Stability`、live helper 的遗留源码存在，不代表普通路径必然执行；反过来，仅断一个入口也不能证明所有路径安全。

## 9. 工具链与可靠命令

交接机：Mac14,2 / M2 Air / 8 GiB RAM；macOS 27.2 (26B123)，Xcode 27.0 (27A5218g)。shell 是 fish。SwiftPM 构建目录布局曾导致 Sparkle framework 找不到；当时仅在 `.build/out/Products/Debug/PackageFrameworks/Sparkle.framework` 建立到 `.build/artifacts` 内真实 slice 的 symlink，未改仓库配置。若重现，先定位框架与搜索路径；不要猜 slice 路径，不要用 `swift package clean` 当通用修复。

在仓库目录执行：

```bash
git status --short --branch
git diff --stat
git diff
git log -12 --oneline
git remote -v
swift test --filter 'SetupFlowTests|SwitcherKeysTests'
swift test
swift build -c release
```

`git diff` 不包含未跟踪的 `CanvasInput.swift`，务必单独阅读。不要用上述命令清单替代真实结果；命令失败需读完整错误后再行动。跨 agent 迁移时不依赖 `.superpowers` 中的执行脚本，直接运行项目命令即可。

原日志目录 `.superpowers/sdd/2026-11-10-tablecloth/` 被 git ignore：包含 progress、task briefs、各阶段测试、审查 diff。交接归档已保存完整历史 Ruling；不要删原目录，因为修复与验收尚未结束。

## 10. 真机验收与完成定义

此前 `System Events` 查询 `UI elements enabled` 返回 false；没有更改授权。这只说明当时自动化受限，不等于已经测试了应用的两权限流程。尚无 GUI、资源目标或旧系统兼容的实测证据。

在安全打包后，经用户决定授予所需权限并运行：

- 授权前/拒绝/授予/撤销，引导和运行门控均正确；不出现接管/登录项/系统修改。
- 捏合/滚动指向缩放、平移、空拖、WASD/方向键、Space、小地图与 zoom HUD。
- 书签保存 toast、弧线跳转、重启恢复；空 slot 与额外修饰键不误触发。
- 悬停/拖拽/远距名称牌/返回脉冲；提示条前五次与菜单重看；新窗脉冲仍是已知 deferred minor。
- 正常窗口与固定尺寸窗口聚焦/返回：实际 frame 接受钳制，末端交接不闪，地图隐藏、返回原 camera/worldRect/physical frame。
- 飞行中关闭/最小化、快速反复切换、聚焦中退出重启，不能崩溃、留下幽灵层或污染布局。
- 地图隐藏、锁屏/睡眠、权限撤销后无继续截图；唤醒/召回恢复。
- 至少记录地图静止 5 分钟与聚焦模式的 CPU/内存；注明窗口数、分辨率、轮换开关与机器信息；测量 GPU/后方视频页负载时使用实际可用工具。未测不填估计值。

完成门：Critical/Important 已解决或用户明确接受未解决项；全套测试及 release build 有新证据；bundle 无注入/守护 payload、无上游更新入口；真机结果及资源数据明确；最终列出 Ruling 与 deferred minor。若无法真机测试，明确标记“未验收”，不要宣称完成或把 PR 当 ready。

最后只向 `origin` 推送 `tablecloth`；如果创建 PR，目标也是 `cyancloudyang/sunlight` 的 main，不是上游。发布前核对 remote、提交内容和授权；保留 MIT 署名，不上传凭据或用户窗口数据。
