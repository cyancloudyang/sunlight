# Tablecloth 首轮真机验证与用户反馈（2026-11-11）

状态：用户已授予两权限并实际运行 `build/Sunlight.app`（pid 21031），主观评价"总体效果超过预期"。测试由用户操作、Qoder 读 `~/Library/Logs/Sunlight/Sunlight.log` 佐证。本文记录已验证项、性能观测与 7 条反馈，作为下一轮优化的依据。PR 仍为 draft（cyancloudyang/sunlight#1）。

## 已由运行时日志确认

- 两权限授予后捕获正常：12–13 个窗口代理，**全程 0 streaming**。
- 双捕获路径都实际使用：可选私有 SkyLight ≈13–28ms/帧；公开 ScreenCaptureKit ≈42–104ms/帧（#8 公开兜底真实可用）。
- 聚焦后地图自动隐藏（"the map steps off the screen"，#3）；多次聚焦/返回循环正常。
- 切换时丢弃在途旧帧（"Lifecycle: captures in flight dropped (life N)"，N 递增到 9，#9 代次控制生效）。
- 新窗口自动落位（"New window: … placed"）；窗口关闭有处理（"Close: …"）。
- 持久化 `~/Library/Application Support/Sunlight/Canvas.json`：12 个窗口按世界坐标散布（x −3162…3640，y −1360…2880），相机 center/zoom 已存；聚焦过的窗口存的是正常地图尺寸而非全屏临时矩形（#4 几何分离生效）。书签字段当时尚未写入（用户未存书签）。
- 边界复核：`SystemPrefs` 仅只读（`managed` 表描述历史 takeover 供卸载还原），无实时偏好写入；无 helper/LaunchDaemon/Sparkle 键。

## 性能观测（待优化，非崩溃）

主线程卡顿 6 次：510 / 777 / 821 / 1336 / 3080 / 5369 ms。最大两次在启动阶段；1336ms 一次明确标注 `in Accessibility: a window's frame (AXWindow.frame)`。根因：`AXWindow.frame`（AX.swift:151/233-237，两次同步跨进程往返）在主线程被多处调用（CanvasController unscaledFrame:2722、handoff:5032、seam:5074、flightBack:5752、return:5919 等）；`listNow` 在 `WindowList.queue.sync` 上阻塞主线程（:2229/:5596）。主 runloop 计时器偏多：listing 3s + heartbeat 30s、refresh 0.25s、live keepalive 0.5s、arrival watch 1/120s 等。

## 用户 7 条反馈与优化方向（代码锚点为 Explore 实测）

1. **引导页 Next 按钮位置随图示大小上下漂移，易误点**。`Setup/SetupWizardView.swift:184-269` 单 VStack，按钮(:308-318)在 demo 下方随图示高度移动。方向：按钮固定在中下部确定位置，中间为弹性动图演示区（参照已固定底部的 "Set Up Later" :113-143 模式）。
2. **快捷键提示后来消失，希望一直显示**。`HintBar.swift:3-5` `HintPolicy.shows = seen < 5`；增量在 CanvasController:1366-1372。方向：改为常驻显示（去掉 <5 门控），保留菜单重看/隐藏。
3. **四指上滑进入地图但没有缩放，进入感不明显**。`showCanvas(fitAll:)` CanvasController:1453；`showFitsAll`:1449 在从窗口返回时抑制 fit，相机不变。方向：手势召回时加一个拉远（zoom-out）入场动画，明确"进入地图"。
4. **四指分开无法进入桌面（地图模式下也不行）**。TrackpadPan 的 session tap 在四指按下时丢弃 Dock-control 事件(type 30, filter:253-261, dropDockControlUntil:308)，吞掉了系统 spread/Mission Control；`.spread` 本应→`showDesktop()`(CanvasController:1658/1696)。方向：让 spread 手势能到达桌面（放行或正确触发 showDesktop），不改任何系统偏好。
5. **背景模糊随相机高度变化太粗暴，想要逐渐模糊**。`Background/BackgroundSpec.swift:128-144` smoothstep focus(forZoom:) 0.9→0.5，但 sigma 只有 5 档 [0,4,12,28,60]（BackgroundPipeline:14）交叉淡入，观感分级。方向：更细的档位/更平滑过渡；注意更多预模糊层=更多内存，需权衡三低。
6. **⌘Tab 切换应用没有"飞起-降落"相机效果，想要快速飞行+运动模糊**。现状：takeover 关闭后 ⌘Tab 透传系统，地图只 orderOut 无动画（KeyTap.summonAction 仅认 MC/F3）；旧切换器飞行代码 beginSwitcher:7754/view.fly:7866 仅在接管模式生效。**边界冲突**：重新拦截 ⌘Tab 等于恢复对系统快捷键的接管，违背"无 takeover"约定；真实运动模糊耗 GPU，违背三低。→ 需用户拍板（见下）。
7. **继续找任何性能优化**。见上性能观测：AX frame 移出主线程、合并/降频主 runloop 计时器、listNow 去同步阻塞。

## 待用户决定

#6 的实现路线（是否接受重新接管 ⌘Tab，以及运动模糊的开销取舍）。其余 1–5、7 在既定边界内可直接实现。
