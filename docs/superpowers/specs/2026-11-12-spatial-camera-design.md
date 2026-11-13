# 空间相机：跟手入场 + 指针意图导航 设计文档

- 日期：2026-11-12
- 适用：Sunlight fork（Tablecloth），分支 `tablecloth`，只 push origin（cyancloudyang/sunlight）
- 状态：待批准（方案甲已认可：先 A 后 B；建造者审查 7 问已落定，见 §7.3，无遗留「只有用户能答」项）
- 关联：原设计 `docs/superpowers/specs/2026-11-10-tablecloth-design.md`；进度 `docs/superpowers/2026-11-11-tablecloth-ledger.md`；任务 #27

## 1. 意图与为什么

用户要把 tablecloth 的操作手感对标 macOS 四指上滑进 Mission Control 的「丝滑跟手」，并要游戏全局地图式的空间导航。两个具体痛点：

1. **不跟手**：进入 canvas 时相机走的是一段固定时长动画，手指/指针无法驱动它。
2. **分裂感**：聚焦态是 macOS 真实堆叠桌面，进 canvas 瞬间变成平铺地图——卡片不动、只有相机拉远，认知断裂。

深层意图（此前 deferred 的方向，现在具体化）：窗口卡片更有「真实物理交互感」，不堆在一起。

## 2. 目标 / 非目标 / 反目标

### 目标
- **A1 跟手入场**：四指上滑的行程**实时驱动**拉远进度（1:1 跟手），释放按动量用弹簧收尾到全局俯瞰；非手势触发（热键/菜单/点击 See All）用**可重定向弹簧**飞到俯瞰。
- **A2 拟真飞行**：入图时，当前屏幕可见的堆叠窗口卡**从真实屏幕位置飞向各自 tablecloth 存储位置**（逐卡），与相机拉远同步，消除分裂感。
- **B1 指针意图导航**：全局俯瞰 → 指针在某卡片群停留 → 俯冲该群（热点 zoom-in）→ 进单卡再拉近到「可读」（非 100%）→ 指针移出缩回群 → 移出群缩回全局；点击窗口仍走既有聚焦。
- 全程低 CPU/GPU/内存：零常驻流、静态快照、单 CA transform。

### 非目标
- 不做 live 捕获流（沿用快照地图）。
- 不接管系统手势 / ⌘Tab / Dock / Finder。
- 不改 SIP、不注入系统进程。
- B 不取代手动平移/缩放——**手永远优先**。

### 反目标（即使技术上工作也算失败）
- 相机跟用户抢：dwell-zoom 在用户手动操作时触发 → 更不跟手。
- 自动缩放让人迷失方向（ZUI 的 desert fog）。
- 入图对屏外卡做无意义飞行，或飞行卡顿。
- 放大超过快照原生分辨率导致糊（「看清」必须有清晰度上限）。

## 3. 约束

### 硬约束（沿用，逐条生效）
不关闭 SIP、不做任何 SIP 相关改动；不注入系统进程；CPU/GPU/内存尽量低；常驻捕获流（SCK stream / CGDisplayStream）一律不用；任何「必须」的私有 API 不接受（私有 API 只允许作为有公开兜底的可选项——MultitouchSupport 为既有可选私有件，沿用）；不改 Dock/Finder/系统手势等任何系统偏好、不做登录项；许可证边界（Sunlight/orcv MIT 可改编署名，canvasWM/minfwm 无许可证只借鉴思路不复制代码）；只 push origin，绝不 push upstream。

### 技术约束
- 卡片是 ≤1024px 长边的静态快照（`TextureLimit.longEdge=1024`），放大只是 CA 缩放、**不重渲染更高清** → 「可读缩放」天然停在快照原生分辨率处（整窗约 zoom 0.6–0.75），再往上糊。
- 生产模块 `Sources/Canvas` 为 Swift 5；测试 target `Tests/CanvasTests` 为 Swift 6 严格模式。
- TDD：每项 RED→GREEN→全套件；纯几何/策略可单测，控制器/视图胶水不单元测试（沿用约定，薄纯策略包装可测）。
- **复用现有动画件，不新造引擎**。
- 不擅自改用户已保存布局/手动状态；新行为优先可逆、可一键关。

## 4. 调研依据（真实出处）

- **Apple WWDC18《Designing Fluid Interfaces》**：流体手势三原则——①手势直接驱动动画进度（非定时器播放）；②可中断/可重定向（弹簧而非固定时长曲线）；③释放按动量投影落点。这是「跟手」的本质，曲线形状只是其一。
- **niri（高星滚动平铺 compositor）官方动画文档**：弹簧「更适合触控板手势，因为它考虑手指速度」；默认 `damping-ratio=1.0`（临界阻尼、无过冲）、`stiffness=800`、`epsilon=0.0001`。
- **Unity `Vector3.SmoothDamp`**：游戏跟随相机标准做法，弹簧-阻尼模型、永不 overshoot；`smoothTime≈0.3s` 约 0.3s 内走完突跳的 ~60%。
- **ZUI 文献（Cockburn 2007 综述；Eagle Mode）**：overview+detail / focus+context / semantic zoom 分类；自动缩放易致迷失（desert fog），需平滑过渡 + 保留全局上下文。
- **Van Wijk & Nuij 2003**：平滑 pan-zoom 路径（d3-zoom 的插值器）——codebase `CameraPath` 已实现。
- **easings.net / Figma**：ease-out（先快后慢）适合移动物体落位。

链接：
- https://developer.apple.com/videos/play/wwdc2018/803/
- https://github.com/nathangitter/fluid-interfaces
- https://github.com/niri-wm/niri/wiki/Configuration:-Animations
- https://docs.unity.com/engine/6000.3/script-reference/unityengine/vector3/smoothdamp
- https://worrydream.com/refs/Cockburn_2007_-_A_Review_of_Overview+Detail,_Zooming,_and_Focus+Context_Interfaces.pdf
- https://en.wikipedia.org/wiki/Zooming_user_interface
- https://easings.net/

## 5. 方案（Approaches）

- **方案甲「地基优先、分两步」（选定）**：先做 A（跟手入场 + 入图逐卡飞行），真机验收手感后再做 B（指针意图 dwell-to-zoom 导航）。每步独立可验收、可交接、风险低；复用现有弹簧/飞行件。
- 方案乙「一次性意图相机重构」（弃）：把入场/导航/聚焦统一成一个弹簧驱动意图相机。更一致，但改动面广、难分段验收、风险高。
- 方案丙「只换缓动曲线」（弃）：把 `animateCamera` 的 ease-out 换成弹簧就完事。治标——不解决手势驱动/可中断/卡片飞行，不跟手与分裂感仍在。

为什么甲：用户核心痛点（不跟手/分裂感）都在 A，先治本地基；B 是新导航范式，风险与调参量大，放在 A 验收后单独细化计划，符合「一次 brainstorm 一个独立子项目」。

## 6. 运动模型（核心决策）

| 场景 | 模型 | 参数（依据） |
|---|---|---|
| 手指/指针**拖动中** | 1:1 即时，**无平滑** | 保持现状（加平滑=加延迟=害跟手） |
| 四指上滑**入图** | 手势行程→拉远进度 1:1 + 释放弹簧收尾 | 复用 `Spring`（response 0.45 / damping 0.72，~4% 过冲） |
| 热键/菜单入图、指针意图俯冲、聚焦飞行 | **可重定向弹簧** `fly` + Van Wijk `CameraPath` | 复用 `fly`/`CameraPath`（rho 1.1） |
| 指针跟随辅助（B） | 临界阻尼弹簧，无过冲 | damping≈1.0（niri 同款，避免晃动） |
| 释放动量 | `PanCoast`/`ZoomCoast` | 已有，保留 |
| 任何定时动画 | ease-out cubic/quint，~0.35–0.5s | 优先弹簧（可中断）而非定时器 |

关键细化（核实用户「线性→曲线」猜测）：曲线化只适用于**动画落位**；**正在拖动的那一刻保持 1:1 线性**才对。真正治不跟手的是「手势驱动 + 可中断弹簧 + 动量」，不只是换曲线形状。

## 7. A 部分设计（build-ready）

### 现状（调查所得）
- 入口：`trackpadPan(.seeAll)` → `showCanvas(fitAll:true, seeAll:true)`（CanvasController:1667）→ 窗口列表同步钩子（CanvasController:2482 / :2656）`view.fitAll(animated:true)` → `animateCamera(to: overviewCamera)`（固定 0.42s、ease-out-cubic、**不可重定向**，CanvasView:1242/1458）。
- 卡片入图**不动**：`placeNewWindows`（CanvasController:3688）直接 `p.place(at: spot.origin)`，只有相机拉远。
- 可复用件：`fly(to:rho:step:completion:)`（可重定向、保留速度，CanvasView:1303）；`Handoff.flightRect(from:to:at:)`（两矩形线性插值、clamp[0,1]，Handoff:124）；`FrameSnapshot.frames` + `worldOrigin(of:)`（入图时真实帧已知，FrameSnapshot:14/41）；`WindowProxy.worldRect(forReal:inset:camera:)`（仅 origin 过相机、size 保持真实点，WindowProxy:860）；`Spring`/`CameraPath`（Camera.swift）；`interruptMotion()`（输入打断落到目标，CanvasView:1357）。

### A1 跟手入场（手势进度驱动）
**决策**：采用「手势进度驱动」（Mission Control 式），而非仅「可重定向弹簧落位」。理由：用户明确对标 Mission Control，其跟手来自手指实时驱动缩放进度。

机制：
1. 四指上滑被识别为入图意图时，**立即显示 canvas**（当前相机≈1:1 覆盖真实桌面），进入「入图拖动」态。
2. 手指上升行程归一化为进度 `t∈[0,1]`，相机 = `CameraPath(from: 起始相机, to: overviewCamera).camera(at: t)`（或 log-zoom 插值）——**1:1 跟手**，每帧直接 set，无定时器。
3. 释放：若 `t` 过 commit 阈值 → 用 `Spring` 按释放动量收尾到 overview；否则弹簧回弹到起始相机（**可取消**）。
4. 非手势触发（热键/菜单/点击 See All）：`fly(to: overviewCamera)`（可重定向弹簧），不走进度驱动。

识别器影响：`TrackpadRecognizer` 需在 swipeUp 模式下，从「上滑越阈值即发离散 `.seeAll`」改为「上滑期间持续发入图进度、释放发 commit/cancel」。保留 #23/#26 语义（上滑=进俯瞰），只是把离散触发改为连续进度。具体相位/接口由 writing-plans 定。

边界：
- 入图手势与其它四指方向的关系：上滑=入图，左/右/下/对角=平移（沿用 #23）。
- 行程不足释放 → 回弹原相机（不强行进俯瞰）。
- 飞行/进度中用户其它输入 → `interruptMotion()` 落到目标（已有）。

### A2 入图逐卡飞行
**决策**：可见堆叠窗口从真实位置飞出；屏外/远处卡原位淡入/微缩放。

机制：
1. 入图开始时，对**当前屏幕可见**的窗口卡：起点 = 真实屏幕帧换算的世界矩形（`FrameSnapshot` + `worldRect(forReal:inset:camera:)`，入图相机≈1:1 故 world≈screen）；终点 = 存储位置（`worldRect` / Tidy spot）。
2. 逐卡 `Handoff.flightRect(from: 起点, to: 终点, at: t)`，`t` 与 A1 的相机进度**同一 t**（卡随相机拉远同步飞出）；释放时随弹簧一并落位。
3. 屏外/远处卡（无真实堆叠位置）：原位淡入/微缩放，复用既有 `setArrival` opening effect（WindowEffects）。
4. PiP tiles 忽略相机（drawnPip）→ 不参与飞行，单独处理。
5. 坐标空间：world 顶左 y-down、CA y-up（`caRect`）；`flightRect` 已处理插值，沿用。

性能：N 卡（用户约 6–15）每帧 step 回调；单 CA transform + 近视野 chrome counter-scale；飞行期间门控 far chrome（`leaveChromeStale`）。零流、零重渲染。

可中断：飞行中用户输入 → `interruptMotion()` 把 moving 卡落到目标（已有机制）。

### 7.3 入场编排落定（建造者审查 → 我的调用）

建造者审查提了 7 个排序问题。逐条用「已核实代码 + 用户意图 + #21–#26 既有决定」落定；凡属我的判断而非用户明说的，标「我的调用」并附代价。地基性事实（Q1/Q2/Q3）已亲自读码核实，非推测。**无遗留「只有用户能答」的问题**——用户意图足够具体，既有决定 + 代码已覆盖全部。

**Q1 入场时机 / 数据齐备**（已核实）
- `mapDidHide`（CanvasController:8367）只 `window.orderOut` + 停计时器 + `invalidationOfCaptures()`（丢在途捕获），**不清 proxies** → 隐藏期间整套 proxy 保留，手势时刻飞行集合已在。
- `overviewCamera`（CanvasView:1222）由现有 proxies 并集即可算，手势时刻可得。
- 真实帧：`snapshot(at:)`（CanvasController:5665）同步取 `WindowList.onScreen()` + 当前相机（~1ms）；`lastRealFrame` 仅 entered app 新鲜，其余自隐藏前同步后已陈旧 → **手势时刻取一次 fresh FrameSnapshot** 作飞行起点，不用陈旧 lastRealFrame。
- 首次 ever 入场（无 proxies）：无飞行集合 → 退化为 `fly` 弹簧拉远（A1.4 路径），不飞卡。
- 代价：若同步取帧在某机型超一帧预算，手势首帧可能迟一帧；真机测，必要时预取。

**Q2 起始相机**（已核实 + 我的调用）
- 起始 = `view.camera`（= `enteredCamera`，enter() CanvasController:5877 设），即聚焦窗 1:1 覆盖真实桌面的相机。**不强制 home**——强制会先跳一下再拉远，正是「无分裂感」的反面。
- 我的调用：tile/PiP 入场时 `view.camera.zoom≠1`（enter() :5878 注释），仍用实际 view.camera 做起点；真实→世界换算走 `FrameSnapshot.worldOrigin`（camera.toWorld），飞行在世界空间插值，故 zoom≠1 也正确，只是「1:1 覆盖」近似在该情形不成立。代价：从 tile 直接上滑入图时飞行起点可能有缩放差；真机确认，必要时该情形退化为 fly。

**Q3 飞行集合 / t=0 几何**（已核实 + 用户意图）
- 飞行集合 = 当前屏幕可见真实窗口 = fresh FrameSnapshot ∩ proxies(kind==.window)，对应用户「当前屏幕的堆叠状态」。
- t=0：proxy 置于真实帧的世界矩形（`FrameSnapshot.worldOrigin(of:)` + 真实 size；`worldRect(forReal:inset:camera:)` WindowProxy:860 仅 origin 过相机）；终点 = 存储 `worldRect`。逐卡 `flightRect(from:to:at:t)`。
- 屏外 / 最小化 / 无真实帧的卡：无堆叠起点 → 原位淡入（`setArrival`），不飞。
- 我的调用：A2 作用域 = 从真实堆叠桌面入图（上滑/热键/菜单，canvas 隐藏且真实桌面在）。F3 单窗返回（flightBack）不属「堆叠状态飞入」，保留既有相机飞行；逐卡飞入是否扩到返回留待后续。依据：用户措辞「从当前屏幕的堆叠状态」隐含多窗堆叠。代价：若用户期望 F3 返回也逐卡飞，本轮未做，可后续扩。

**Q4 上滑何时由平移转为入图进度**（#23/#26 既有决定 + 我的调用）
- swipeUp 模式下四指向上（rise≥swipeDistance、axisLock 内、landedTogether）= 入图意图（#23「上滑即 See All」、#26 默认 swipeUp）；左/右/下/对角仍平移。进度自 `dragOrigin` 起算。
- 我的调用：已在俯瞰（view.camera isClose overviewCamera）时再上滑 = 幂等 re-fit（不重复飞卡）；进度驱动仅用于「从真实桌面入图」。归一化常数 / commit 阈值 = 真机调参（§9）。代价：幂等阈值太松则微上滑触发无谓 re-fit；真机调。

**Q5 中途取消 / 打断时卡片行为**（我的调用）
- 取消（释放未过 commit）：相机弹簧回弹到起始，**卡片同步反向飞回真实起点**（同一 t 反向），整段入场可逆。
- 打断（飞行中用户其它输入 pan/zoom/click）：`interruptMotion()`（CanvasView:1357）把 moving 卡与相机落到目标，新输入接管。
- 依据：用户「可取消」意图 + 既有 interruptMotion 语义。代价：取消时卡片与相机须同一 t 反向，否则脱节。

**Q6 逐卡 t 从手势→弹簧的交接 / 过冲**（我的调用，沿用既有件）
- 手势期 t = 手指进度；释放后相机用 `Spring`（0.45/0.72，~4% 过冲）收尾到 overview，卡片 t 随同一弹簧进度但 **clamp[0,1]**（`flightRect` 已 clamp，Handoff:124「spring overshoot must not breathe rect」）→ 卡片不过冲、相机微过冲。
- 速度交接：释放动量经 `fly`（可重定向、保留速度，CanvasView:1303）传入弹簧。
- 代价：卡片 clamp 而相机过冲 → 落位瞬间卡片先停、相机后停；既有 handoff 同款行为，可接受。

**Q7 PiP / widget / attached**（我的调用，沿用既有模型）
- PiP tile：`drawnPip` 忽略相机（CanvasView:848）→ 不参与世界飞行，保持屏幕角，单独处理。
- attached 子窗：随父窗飞（父的 flightRect 带动）。
- widget：无真实堆叠位置 → 存储位淡入（setArrival），不飞。
- 代价：PiP 入图时仍占屏幕角，可能与拉远后俯瞰构图重叠；沿用既有 drawnPip 行为，真机确认。

## 8. B 部分设计（interaction-level；A 验收后细化为独立 plan）

- 默认入图视角 = 全局俯瞰。
- **指针意图控制器（新）**：追踪指针世界坐标 → 判定所在区域 → 停留阈值（提案 ~0.4–0.6s 静止）→ `fly` 到 `framing(groupBounds)`。
- **群定义**（提案，B 阶段定）：空间邻近簇（Tidy 按 app 排后≈同 app 簇）；可选 Polarity 磁吸组（`Magnetism.Body.bounds` 已算并集矩形）；`view.framing(_:)` 已可取景。
- 进单卡：指针在卡上 → 再拉近到「可读 zoom」（快照原生分辨率上限，整窗约 0.6–0.75，按卡尺寸/快照分辨率计算）。
- 移出卡 → 缩回群；移出群 → 缩回全局。
- 点击 → 既有 `handoff` 聚焦（不变）。
- **主动性（决策）**：停留辅助、**手永远优先**——任何手动 pan/zoom/手势瞬间接管、意图暂停；移出即缩回；Settings 一键开关（默认开/关由用户定，倾向可逆）。依据：ZUI 自动缩放迷失风险 + 用户跟手目标。
- 防迷失：平滑 Van Wijk 过渡、保留全局上下文（minimap 已有）、点击/esc 退出。
- 参数（dwell 时间、zoom 目标、群算法）待 A 验收后真机调。

## 9. 留给实现者（writing-plans 产出）
- 入场编排**决策已落定**（§7.3 Q1–Q7）；writing-plans 据此定具体接口/签名/测试用例（识别器入图进度相位、相机进度映射、逐卡飞行编排、意图控制器）。
- 归一化常数、commit/回弹阈值、dwell 时间、可读 zoom 计算 → 真机调。
- 群定义算法（空间簇 vs app vs Polarity）→ B 阶段定。

## 10. 验收
- **A**：真机四指上滑跟手（行程驱动、无固定定时器滞后感）；入图可见窗口从真实位置飞出、无分裂感；释放弹簧落位顺滑；低占用（PerfLog 实测，**不虚构数字**）。
- **B**：真机停留俯冲/缩回顺滑、不跟手抢、可一键关。
- 全套 `swift test` 绿；TDD 每项 RED→GREEN；编译警告不新增（既有基线除外）。
- 原生视觉顺滑度需真机确认，不代为宣称达标。

## 11. 交接与状态跟踪
- ledger `docs/superpowers/2026-11-11-tablecloth-ledger.md` 增「空间相机」轮条目（含 Rulings）。
- 任务 #27（设计）+ 后续 A/B 子任务；每步 commit + push origin；PR #1 保持 draft 直到用户验收。
- 合适节点固化交接（设计批准、A 完成、B 完成各一节点）。