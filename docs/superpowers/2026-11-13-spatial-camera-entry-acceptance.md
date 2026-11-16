# 空间相机 Part A 真机验收清单（2026-11-13）

状态：**代码完成并通过 PM 验收**（HEAD = `origin/tablecloth` = `a9114df`；`swift build` Build complete，`swift test` 738 tests / 1 skipped / 0 failures）。本文只是真机验收步骤与记录表，**全部验收项均为「未实测·需真机」，不声称顺滑、不代填任何数字**。权限授予与实际手势由用户完成，agent 只读日志佐证。PR #1 仍为 draft。

本文沿用 `docs/superpowers/2026-11-11-tablecloth-native-feedback.md` 的体例：用户操作 → agent 读 `~/Library/Logs/Sunlight/Sunlight.log` 佐证。

## 0. 这一版是什么

- 构建：`make app SIGN=-`（= `SIGN="-" scripts/package.sh --app-only`），产物 `build/Sunlight.app`，版本 0.2.4，bundle id `com.spacefarm.sunlight`，**adhoc 签名、无 TeamIdentifier**。
- 内容：Part A —— 四指上滑的手势驱动入场相机（行程 1:1，无固定计时器）+ 入图逐卡飞行 + 释放弹簧（带抬起速度，commit 阈值 0.5）。
- 不含：Part B（指针意图 dwell-to-zoom，未实施）；无 takeover、无注入器（本 fork 从不打包 live-windows helper）、无系统偏好改动、无常驻捕获流。

## 1. 前置步骤（全部由用户执行）

**1.1 重新授予两权限。** ad-hoc 签名每次构建都是新身份，所以辅助功能与屏幕录制授权必然失效，必须重授：

- 打开 系统设置 › 隐私与安全性 › **辅助功能**，以及 屏幕录制。
- 若列表里已有旧的 Sunlight：选中它按 `−` 移除，再按 `+` 添加 `build/Sunlight.app`（或从 Finder 拖进去），然后勾选。
- 没授予的征兆：画布上没有真实的窗口卡片，日志里出现 `Entry: nothing to fit — the swipe is a plain See All flight` 或 `Entry: 0 cards fly, 0 open in place`。

**1.2 启动。** Finder 双击 `build/Sunlight.app`（或 `open build/Sunlight.app`）。

**1.3 边做手势边看日志。** 另开一个终端窗口：

```sh
tail -f ~/Library/Logs/Sunlight/Sunlight.log | grep --line-buffered 'Entry:'
```

行格式：`2026-11-13 18:40:01.123 [4521] Entry: released at 0.62 — in, speed 2.31`。每行在 `Log.note` 返回前就已落盘，可以边做边看。

> 只想看退场/权限类线索时，换成 `grep -E 'Entry:|Lifecycle:|Rendering:|Handoff:'`。

## 2. 本版本真实的日志串（映射用，取自源码）

| 时机 | 日志串 | 源码 |
|---|---|---|
| 手势开关关着 | `Entry: gesture entry off in Settings — the swipe is See All` | `CanvasController.swift:1729` |
| 手势开始 | `Entry: four-finger swipe up begins`（从隐藏进入时附 `, bringing the canvas back`） | `:1734` |
| 没有可飞的卡 | `Entry: nothing to fit — the swipe is a plain See All flight` | `:1761` |
| 飞行集确定 | `Entry: <N> cards fly, <M> open in place` | `:1797` |
| 释放 | `Entry: released at <t> — in\|back out, speed <v>` | `:1829` |
| 被打断 | `Entry: interrupted` | `:1860` |
| 画布退场（副作用） | `Lifecycle: captures in flight dropped (life <n>)` | `:8565` |

注意：日志只能证明「手势被识别 / 释放的进度与初速是多少 / 几张卡在飞」，**跟手度、分裂感、过冲观感必须靠眼睛判断**，下文每项都按这个界线写。

## 3. 验收项（结果栏由用户填）

每一项记「通过 / 不通过 + 一句备注」，不通过时把那几行日志（含时间戳）一起贴回来。

### A1 上滑半程 1:1 跟手，无固定计时滞后

- 步骤：站在某个窗口里（画布不在屏上）→ 四指慢慢上滑到约一半，**停住不动 1 秒** → 再往回滑一点。
- 期望：缩放跟着手指走，手停画面就停（不会自顾自继续走完）；没有「松手后按 0.42 s 播一段动画」的感觉；回滑时画面同步回缩。
- 日志佐证：`Entry: four-finger swipe up begins, bringing the canvas back`（只证明手势被识别；跟手度非日志可证）。
- 结果：☐ 通过 ☐ 不通过　备注：＿＿＿＿

### A2 可见窗口从真实堆叠位起飞，与相机同一 t 落位

- 步骤：屏上摆 3–4 个窗互相叠着（记住各自位置和大小）→ 四指一次上滑到顶。
- 期望：每张卡从它在屏幕上真实的位置/大小起飞，飞到画布里的存储位；起飞第一帧与手势第一帧一致（无「先跳一下」）；卡与背景同时到达（无脱节、无一张先停另一张后停到肉眼可见）。
- 日志佐证：`Entry: <N> cards fly, <M> open in place`，N 应≈屏上窗口数。
- 结果：☐ 通过 ☐ 不通过　备注：＿＿＿＿

### A3 释放弹簧（三种收尾）

- **A3a flick（越甩越快）**：快速上滑越过一半后立刻松手。期望：松手后继续带着速度冲进去，一次轻微过冲后停住，不是从静止重新起步。
- **A3b 静止收尾**：滑到约 70%，停住约 0.5 s 再松手。期望：平稳收尾，没有「突然加速」的突兀感。
- **A3c 回抽释放**：滑到约 60%，再往回拉到约 30% 松手。期望：先被带出去一点（外溢）再回到起点附近，外溢量自然、不像被弹开。
- 日志佐证：`Entry: released at 0.62 — in, speed 2.31` / `… — back out, speed …`；A3b 的 speed 应≈`0.00`（采样窗只取末 3 个样本，静止收尾读不出 flick）。
- 结果：A3a ☐ 通过 ☐ 不通过　A3b ☐ 通过 ☐ 不通过　A3c ☐ 通过 ☐ 不通过　备注：＿＿＿＿

### A4 低于 0.5 阈值干净回退（含从隐藏状态退场）

- **A4a**：从窗口上滑到 30–40% 就松手。期望：干净退回原窗口状态，卡片回落真实位，画布不留残影、不半途停住。
- **A4b**：同上，但松手时没有别的 app 在前台（即画布本来是因为手势才出现的）。期望：画布随即退场回到原桌面，不留在屏上。
- 日志佐证：`Entry: released at 0.38 — back out, speed …`；A4b 之后紧跟 `Lifecycle: captures in flight dropped (life <n>)`（life 递增＝画布退场的副作用）。
- 结果：A4a ☐ 通过 ☐ 不通过　A4b ☐ 通过 ☐ 不通过　备注：＿＿＿＿

### A5 屏外／最小化窗口原地淡入是否过亮

- 步骤：把 2 个窗最小化（或移到别的 Space），屏上留 2–3 个 → 四指上滑。
- 期望：屏外/最小化的窗**不飞**，在画布的存储位原地淡入；淡入不至于亮到抢眼、不像闪一下。
- 日志佐证：`Entry: <N> cards fly, <M> open in place`，M ≥ 1 且与最小化数量大致对应。
- 结果：☐ 通过 ☐ 不通过　备注：＿＿＿＿

### A6 多屏落位 + live 渲染（本构建 capture-only）

- **A6a 副屏（display origin ≠ 0）**：接一块副屏，把几个窗放副屏（画布也铺在副屏），在副屏上四指上滑。期望：卡片不整体偏移（偏移即 `toView` 转换回归），落位到画布存储位。
- **A6b live realWindows**：**本 fork 不可达，不列为失败项**——`Settings.renderer` 恒为 `.capture`（`Settings.swift:12`），且本 fork 不打包注入器；日志若出现 `Rendering: addition unavailable or incompatible; using capture proxies` 属预期。
- 日志佐证（A6a）：`Entry: <N> cards fly, <M> open in place`，N 与副屏窗口数相符。
- 结果：A6a ☐ 通过 ☐ 不通过　A6b ☐ 不适用　备注：＿＿＿＿

### A7 占用（CPU / GPU / 内存）——数字留空待填，绝不代填

- 打开帧计时（影响本次启动，读完再关）：

```sh
defaults write com.spacefarm.sunlight PerfLog -bool YES     # 观察完改回 NO
```

- 步骤：① 静止停在画布上约 15 s；② 连续上滑/释放 10 次；③ 再静止 15 s。
- 采样（另开终端，`Sunlight` 在跑）：

```sh
scripts/perf-snapshot.sh 15
```

- 日志佐证：`Perf: <n> ticks/s · main p50 <a> / p95 <b> / max <c> ms · <e> events, <m> missed · <f> MB`（每 5 s 一行）。
- 记录（**待填**）：
  - 静止 CPU（Sunlight / WindowServer / replayd）：＿＿ ／ ＿＿ ／ ＿＿
  - 手势期间 CPU：＿＿　main p50 / p95 / max：＿＿ / ＿＿ / ＿＿ ms
  - Footprint：＿＿ MB（其中 IOSurface / IOAccelerator：＿＿）
  - GPU：＿＿（无采集手段则写「未采集」）
- 结果：☐ 通过 ☐ 不通过　备注：＿＿＿＿

## 4. PM 额外观察项（先测再说，非必改）

**封顶限的是 progress 速率，不是归一化后的 v0。** `maxProgressRate = 4` 作用在「progress/秒」，而 `fly` 里 `Spring v0 = speed / L_release`：接近 overview 时释放，`L_release` 很小，同一个 progress 速率会换算出很大的 v0，观感上就是「过冲偏猛」。

- 步骤：一次**连续快速甩到底**（进度远超 0.5）并立刻松手，与 A3a 的中速 flick 对比。
- 期望：过冲约 4%（spring 0.45 / 0.72），视觉上是**一次**轻微回弹；若像被弹回、来回摆两次以上或停在目标外很明显 → 记为不通过。
- 若确实偏猛：下一步是给 v0 加归一化封顶（限 `speed / L_release` 而不是限 progress 速率），**本轮不改**。
- 结果：☐ 通过 ☐ 不通过　备注：＿＿＿＿

## 5. 可调项（一律真机调，本轮不动）

| 参数 | 现值 | 位置 | 手感含义 |
|---|---|---|---|
| `entryDistance` | 0.30 | `TrackpadPan` | 走完全程需要的手指行程；太小易误触，太大滑不动 |
| `commitThreshold` | 0.5 | `EntryFlight` | 松手时「进去」与「回去」的分界 |
| `maxProgressRate` | 4 | `EntryFlight` | 释放最多带走多快的手速（progress/秒） |
| 采样窗 | 末 5 个采样取末 3 个 | `CanvasController.driveEntry` / `EntryFlight.velocity` | 越大越平滑、越迟钝 |
| spring | response 0.45 / damping 0.72 | `Spring` | 飞行时长与过冲量（约 4%） |

## 6. 已知不测项

- **Part B**（指针意图 dwell-to-zoom）：未实施，不在本清单。
- **live realWindows 跟手**：本构建不可达（见 A6b）。
- 任何系统偏好、权限、TCC：本轮不改，也不由 agent 改。

## 7. 回报方式

每条填「通过 / 不通过 + 一句备注」，不通过项附上时间戳附近的 `Entry:` / `Lifecycle:` 行。收到后按「通过项保持、不通过项定向修」推进，改动一律 TDD + 全量 `swift test`，只 push origin，PR #1 保持 draft。
