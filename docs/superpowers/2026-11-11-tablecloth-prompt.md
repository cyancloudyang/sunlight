# 复制以下内容给接手的 coding agent

接手我的 Tablecloth 项目，延续已经批准的路线，不重新 brainstorm、不从头重做 Tasks 1–8，也不重做已落地的安全修复与反馈优化。

请在本地仓库 `/Users/cycloudyang/Documents/Qoder/2026-11-10/4aceb90d/sunlight` 工作。若我已迁移目录，以我提供的新路径为准；如果目录不存在或缺少下列文件，先告知我。本次工作已 push 到 origin 的 tablecloth，但 `.superpowers/sdd/` 的记录与日志只在本地，优先用本地目录而不是只 clone 远程。

开始前依次完整阅读（ledger 是权威记录，本文与 handoff 只保证交接时间点状态）：
1. `docs/superpowers/2026-11-11-tablecloth-handoff.md`（顶部"第五轮后"状态条）
2. `docs/superpowers/2026-11-11-tablecloth-ledger.md`（全部 Ruling、取舍、代价、验证证据）
3. `docs/superpowers/specs/2026-11-10-tablecloth-design.md`
4. `docs/superpowers/plans/2026-11-10-tablecloth.md`
5. `docs/superpowers/2026-11-11-tablecloth-native-feedback.md`（用户 7 条反馈原文）

然后核对 `git status/diff/log/remotes`，以实际代码为准。交接时：分支 tablecloth，HEAD `7490488b37caaaac93866af60ee5181757b09d9f`，工作树干净，已全部 push 到 origin（cyancloudyang/sunlight），PR #1 OPEN/draft（https://github.com/cyancloudyang/sunlight/pull/1），未合并、未发布。最新全套 `swift test`：702 tests、1 skipped、0 failures（skip 为 DockItemTests 无 app bundle 用例）；136 条编译警告是既有 Swift 6 严格模式基线，不是本轮新增。

已完成：Tasks 1–8（快照地图/RTS 相机/书签/聚焦往返）、安全审查 #1–#11、用户 7 条反馈 #12–#18（提示常驻、引导按钮固定中下部、背景随相机渐模糊、手势入图拉远、opt-in 真实桌面、⌘Tab 更高弧不接管、返回地图优先窗口列表而非主线程同步 AX 帧）。

不可突破的硬约束（高于计划疏漏）：不关闭 SIP，不做任何 SIP 相关改动；不注入系统进程；CPU、GPU、内存占用尽量低；常驻捕获流（SCK stream / CGDisplayStream 一律不用）；任何"必须"的私有 API 不接受（私有 API 只允许作为有公开兜底的可选项）；不改 Dock/Finder/系统手势等任何系统偏好（无 takeover）、不做登录项；许可证边界：Sunlight（MIT）、orcv（MIT）可改编代码并署名，canvasWM、minfwm 无许可证只借鉴思路不复制代码；macOS 15+、Apple Silicon、v1 主屏；只 push origin（cyancloudyang/sunlight）的 tablecloth，绝不 push upstream（spacefarm-digital/sunlight），PR 只面向用户 fork。

仍未验收（需我真机再跑，你不能替我宣称达标）：5 分钟静止 CPU/内存测量；#13/#14/#15/#16 的视觉观感（按钮落点、模糊梯度、入场拉远、⌘Tab 弧高）；#17 真实桌面系统交互（依赖系统设置启用 Show Desktop 快捷键 F11）；#18 卡顿降幅复测。deferred minor：#16 方向性运动条纹（替代真运动模糊，留真机迭代）、#12 活跃地图新窗口 noteArrived 脉冲。#18 后续性能候选（未做）：其余主线程 AXWindow.frame 同步点、listNow()/snapshot() 的 WindowList.queue.sync 阻塞 hop、主 runloop 计时器合并；handoff/seam 逻辑精密，无第二次整分支复核不宜贸然线程重构。

工作方式：由你在当前会话原生实现，测试先行、确认 RED→GREEN，每组改动跑全套 `swift test` 并记录结果，不只跑局部。已有一次整分支审查，不重复付费跑整分支审查；逐项核实并修 Critical/Important，保留明确列出的 deferred minor。不要自动修改系统/隐私权限；不 reset/restore/clean 未提交工作；真机验证受限就如实说明，不能用构建成功代替交互测试，也不能虚构 CPU/GPU/内存达标。测试构建需 `.build/out/Products/Debug/PackageFrameworks/Sparkle.framework` 符号链接（`swift package clean` 后需重建）。按有意义的单元提交，保留进度与取舍；发布前核对状态和权限，PR 在我验收前保持 draft。

我这次想让你聚焦：______（例如：#18 后续性能候选 / 真机验收清单 / 某个 deferred minor / 其它）。若我没指定，先简短报告你从实际文件确认的状态和你建议的下一步，等我确认再动手；不要让我重新讲一遍需求。