# 复制以下内容给接手的 coding agent

接手我的 Tablecloth 项目，延续已经批准的路线，不重新 brainstorm、不从头重做。

请在本地仓库 `/Users/cycloudyang/Documents/Qoder/2026-11-10/4aceb90d/sunlight` 工作。若我已迁移目录，以我提供的新路径为准；如果目录不存在或缺少下列文件，先告知我，不要只 clone 远程后继续，因为开发提交和未提交补丁尚未 push。

开始前依次完整阅读：
1. `docs/superpowers/2026-11-11-tablecloth-handoff.md`
2. `docs/superpowers/specs/2026-11-10-tablecloth-design.md`
3. `docs/superpowers/plans/2026-11-10-tablecloth.md`
4. `docs/superpowers/2026-11-11-tablecloth-ledger.md`

然后核对 git status/diff/log/remotes，并单独阅读未跟踪的 `Sources/Canvas/Takeover/CanvasInput.swift`。交接时分支为 tablecloth，HEAD 为 22e7da9475eb1844aa73746e8c897a58d8b03172；存在未完成安全补丁，当前局部测试在 App.swift 的四处残留 takeover 引用处编译失败。此前 609 项 XCTest（1 skipped、0 failures）只证明补丁之前的提交，不代表当前版本通过。保留所有现有工作，不 reset/restore/clean，不为编译通过接回 takeover。

目标已定：Sunlight fork 上的低资源快照地图；RTS 式相机、空间位置记忆、1–9 书签、平滑聚焦真实窗口/F3 返回。禁止 SIP 改动、系统进程注入、常驻 SCK/CGDisplayStream、系统偏好修改和登录项；私有 API 必须可选且有公开兜底；macOS 15+、v1 主屏；保留 MIT 署名，不复制无许可证项目代码。

请按交接文档继续修复：先完成安全入口/权限/独立输入补丁，再处理截图公开降级与 1024px 上限、聚焦状态机与持久化、隐藏/睡眠异步生命周期、分批窗口匹配、安全打包及更新配置。现有 package.sh 会打包上游 helper，修好前不要运行 make app。已有一次整分支审查，完整阻塞清单在交接文档；不重复付费跑整分支审查，直接逐项核实并修 Critical/Important，保留明确列出的 deferred minor。

由你在当前会话原生实现，测试先行、确认 RED→GREEN，每组修复跑全套测试并记录结果，不只跑局部。无需 Qoder 专属工具或技能。不要自动修改系统/隐私权限；真机验证受限就说明，不能用构建成功代替交互测试，也不能虚构 CPU/GPU/内存达标。

按有意义的修复单元保存提交，保留进度与取舍；发布前核对状态和权限。只允许 push origin（cyancloudyang/sunlight）的 tablecloth，绝不 push upstream（spacefarm-digital/sunlight）；PR 也只面向用户 fork。当前尚未推送、没有 PR，不能称已发布或已验收。

请先简短报告你从实际文件确认的状态和第一个修复点，然后开始执行；不要让我重新讲一遍需求。
