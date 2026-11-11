import AppKit

@MainActor
final class CanvasInput {
    let keyTap: KeyTap
    let watcher = ForegroundWatcher()
    private(set) var isRunning = false

    init(canvas: Desk) {
        keyTap = KeyTap { [weak canvas] command in canvas?.handle(command) }
        watcher.onForeignActivation = { [weak canvas] app in canvas?.foreignActivation(app) }
        watcher.onDockClickOnFrontApp = { [weak canvas] app in canvas?.dockClickOnFrontApp(app) }
        watcher.onAppGone = { [weak canvas] pid in canvas?.appGone(pid: pid) }
        watcher.onFocusedWindowChanged = { [weak canvas] pid, element in canvas?.focusedWindowChanged(pid: pid, element: element) }
        watcher.onWindowCreated = { [weak canvas] pid, element in canvas?.windowCreated(pid: pid, element: element) }
        watcher.onWindowMiniaturized = { [weak canvas] pid, element in canvas?.windowMiniaturized(pid: pid, element: element) }
        watcher.onWindowMoved = { [weak canvas] pid, element in canvas?.windowMoved(pid: pid, element: element) }
        watcher.onEnteredWindowDestroyed = { [weak canvas] pid in canvas?.enteredWindowDestroyed(pid: pid) }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        keyTap.start()
        watcher.start()
    }

    func stop() {
        isRunning = false
        keyTap.stop()
        watcher.stop()
    }
}
