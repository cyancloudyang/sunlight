import AppKit
import Carbon.HIToolbox

@main
enum CanvasApp {
    @MainActor static func main() {
        // A Mac already set up for live windows (SIP partly off, boot argument set) that gets this build
        // isn't a fresh install: no preview mode for it.
        if !Settings.liveWindowsEverLoaded, SetupStatus.liveWindowsPossible() { Settings.liveWindowsEverLoaded = true }
        let args = Set(CommandLine.arguments.dropFirst())
        Settings.previewForced = args.contains("--preview-mode")
        if args.contains("--renderer-status") {
            print(SetupDiagnose.rendererStatus(preferred: Settings.renderer.rawValue, wantsLiveWindows: Settings.renderer == .realWindows,
                                               available: LiveWindowsConnection.probe(), previewMode: Settings.previewMode,
                                               reload: SetupDiagnose.reloadDescription()))
            print(SetupDiagnose.setupLines(SetupStatus.current()).joined(separator: "\n"))
            exit(0)
        }
        if args.contains("--diagnose") {
            print(SetupDiagnose.report(SetupDiagnose.gather(.current)), terminator: "")
            exit(0)
        }
        if let index = CommandLine.arguments.firstIndex(of: "--welcome-music") {
            let path = CommandLine.arguments.count > index + 1 ? CommandLine.arguments[index + 1] : "Sunlight Welcome.wav"
            do {
                try WelcomeMusic.wav().write(to: URL(fileURLWithPath: path))
                print(path)
                exit(0)
            } catch {
                print("Couldn't write \(path): \(error.localizedDescription)")
                exit(1)
            }
        }
        if args.contains("--release") {
            print("Tablecloth does not change system preferences or login items.")
            exit(0)
        }
        if args.contains("--status") {
            TakeoverMode.printStatus()
            exit(0)
        }
        if args.contains("--help") || args.contains("-h") {
            print("Sunlight [--release | --status | --renderer-status | --diagnose | --setup-preview <scenario> | --preview-mode | --welcome-music <file.wav>]\n  --release  restore the Dock, Finder, Stage Manager and login item changed by Sunlight, then exit\n  --status   print takeover state and the current values\n  --renderer-status  check the live-window protocol without opening the canvas\n  --diagnose  print the Diagnose report: this Mac's setup, the renderer, the helper, the setup log\n  --setup-preview  show the Set Up Sunlight wizard for a made-up Mac (list: the scenarios)\n  --preview-mode  open the canvas in preview mode for this launch, even on a Mac set up for live windows\n  --welcome-music  write the wizard's welcome music to a WAV file")
            exit(0)
        }
        var reviewScenario: SetupReview.Scenario?
        if let index = CommandLine.arguments.firstIndex(of: "--setup-preview") {
            let name = CommandLine.arguments.count > index + 1 ? CommandLine.arguments[index + 1] : "list"
            guard let scenario = SetupReview.scenario(named: name) else {
                print(SetupReview.usage)
                exit(name == "list" ? 0 : 1)
            }
            reviewScenario = scenario
        }

        if reviewScenario == nil {
            let info = Bundle.main.infoDictionary ?? [:]
            Log.note("Startup: Sunlight \(info["CFBundleShortVersionString"] as? String ?? "dev") (\(info["CFBundleVersion"] as? String ?? "-")), pid \(getpid()), \(ProcessInfo.processInfo.operatingSystemVersionString)")
            Stability.launched()
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        delegate.reviewScenario = reviewScenario
        app.delegate = delegate
        // No Dock icon and no menu bar of its own: Sunlight lives in its menu bar icon (`MenuBarItem`).
        // Info.plist's LSUIElement says the same for the app bundle; this covers `swift run`.
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    /// Every display's canvas (`Desk`), which routes each command to the right one.
    private var canvas: Desk?
    /// The ⌃⌥ placement keys (`TileMenu`): global, so they work in a real window too.
    private var tileHotkeys: [Hotkey] = []
    private var trackpadPan: TrackpadPan?
    private var input: CanvasInput?
    private var signalSources: [DispatchSourceSignal] = []
    private var settings: SettingsWindowController?
    private var setup: SetupWizardController?
    /// What no setup step can change about this Mac, read once.
    private let mac = SetupFlow.Mac.current()
    /// The last look at the Mac's setup, for the menu item's title.
    private var setupStatus: SetupStatus?
    /// `--setup-preview`: only the wizard, against a made-up Mac.
    var reviewScenario: SetupReview.Scenario?
    private var reviewController: SetupWizardController?
    private var updater: Updater?
    /// The menu bar icon: with no Dock icon, every command lives there, in its panel or its right-click menu.
    private var menuBar: MenuBarItem?
    /// Tell Sunlight's bar (⌃⌥Space), made the first time it's asked for.
    private var agentBar: AgentBar?
    private let layoutsMenu = NSMenu(title: "Layouts")
    /// Rebuilt when an experimental feature is turned on or off (`rebuildWindowMenu`).
    private let windowMenu = NSMenu(title: "Window")

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let reviewScenario {
            installMenu()
            reviewController = SetupReview.run(reviewScenario)
            return
        }
        // Opened from the disk image or Downloads: the offer to move to Applications comes first, and if
        // this copy goes, nothing else comes up.
        if MoveToApplications.offerIfNeeded() { return }
        Watchdog.shared.start()
        DispatchQueue.global(qos: .utility).async { CrashReports.collect() }
        DispatchQueue.main.asyncAfter(deadline: .now() + Stability.settleTime) { MainActor.assumeIsolated { Stability.settle() } }
        AXWindow.installGlobalTimeout(1)
        updater = Updater()
        updater?.onFoundUpdate = { [weak self] version in self?.menuBar?.model.updateVersion = version }
        installMenu()
        // A login item can be up before AppKit lists a display (the lid closed on a Mac whose external
        // display is still waking, a display coming back from sleep): the canvas has nothing to be on, and
        // starting it anyway crashed at launch. It waits for the first display instead.
        if Display.all.isEmpty {
            waitForDisplay()
            return
        }
        startCanvas()
    }

    private var displayWait: NSObjectProtocol?
    private var displayPoll: Timer?

    private func waitForDisplay() {
        Log.note("Startup: no display listed yet; waiting for one before opening the canvas")
        displayWait = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                             object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.displayMayHaveCome() }
        }
        // And a look every second, in case the notification never comes.
        displayPoll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.displayMayHaveCome() }
        }
    }

    private func displayMayHaveCome() {
        guard canvas == nil, !Display.all.isEmpty else { return }
        if let displayWait { NotificationCenter.default.removeObserver(displayWait) }
        displayWait = nil
        displayPoll?.invalidate()
        displayPoll = nil
        Log.note("Startup: a display is listed now; opening the canvas")
        startCanvas()
    }

    /// The canvas and everything around it, once there is a display to put it on.
    private func startCanvas() {
        let canvas = Desk()
        self.canvas = canvas
        canvas.onCustomiseBackground = { [weak self] in self?.showSettings(tab: .background) }
        canvas.onHowToUse = { [weak self] in self?.showInstructions(chapter: nil) }
        // A display more or fewer: ⌃⌥⇧ → ← are Sunlight's only while there's somewhere to move to.
        canvas.onDisplaysChanged = { [weak self] in self?.experimentalFeaturesChanged() }
        // At launch the add-on usually isn't answering yet (quitting restarted the Dock) and the setup
        // status says so; once the canvas has reloaded it, the menu bar shouldn't go on saying setup is unfinished.
        canvas.onLiveWindowsAnswering = { [weak self] in self?.setup?.recheck() }
        menuBar = makeMenuBar(for: canvas)
        if Settings.sunlightOn { installHotkeys(for: canvas) }
        NotificationCenter.default.addObserver(forName: Settings.experimentalFeaturesDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.experimentalFeaturesChanged() }
        }
        // Four-finger drag pans the canvas from anywhere, a window included. Not while Sunlight is off.
        let pan = TrackpadPan { [weak canvas] phase in
            guard Settings.sunlightOn else { return }
            canvas?.trackpadPan(phase)
        }
        pan.start()
        pan.setActive(Settings.sunlightOn)
        trackpadPan = pan

        if Settings.sunlightOn {
            canvas.show()
        } else {
            // Switched off in the menu bar last time: it stays off until the switch says otherwise.
            canvas.setPaused(true)
        }
        canvas.permissionsAskedElsewhere = true
        setupController().showIfNeeded { _, _ in }

        let input = CanvasInput(canvas: canvas)
        self.input = input
        canvas.takeover = input
        installSignalHandlers()
        // The keys reach Sunlight through the tap only with Accessibility: without it there's nothing
        // to tap and no window to drive, and the wizard holds the grant.
        if Settings.sunlightOn, PermissionGate.current().allows(.focus) { input.start() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        canvas?.shutdown()
        canvas?.remember()
        input?.stop()
        Stability.quitCleanly()
        return .terminateNow
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let setup, setup.isShowing {
            setup.showWindow(nil)
        } else if !Settings.sunlightOn {
            setSunlightOn(true)   // opened again from Finder or Launchpad: that's on
        } else {
            canvas?.show()
        }
        return false
    }

    // MARK: The menu bar

    /// The keys that reach Sunlight from any app: the ⌃⌥ placement layer and ⌃⌥S. (The canvas itself has
    /// one key, the Mission Control key, which takeover's key tap claims.) Registered while Sunlight is
    /// on; off, they're the Mac's again (`setSunlightOn`).
    private func installHotkeys(for canvas: Desk) {
        // ⌃⌥ ← → ↑ ↓, U I J K, D F G, E T, ⏎, C: a window to a half, quarter, third, two-thirds, full,
        // centre. One another app already holds (Rectangle, say) logs a failure and stays that app's.
        tileHotkeys = TileMenu.shortcuts.map { shortcut in
            Hotkey(keyCode: UInt32(shortcut.keyCode), modifiers: TileMenu.carbonModifiers) { [weak canvas] in
                canvas?.tile(shortcut.preset)
            }
        }
        // ⌃⌥ 2, 3, 4: the windows of the screen in view in columns. ⌃⌥A: everything, tidied. From a real
        // window the canvas comes forward first. Only with arranging on (Settings › Experimental):
        // off, the keys stay free for other apps.
        if Settings.arranging {
            tileHotkeys += TileMenu.arrangements.compactMap { a in
                a.keyCode.map { code in
                    Hotkey(keyCode: UInt32(code), modifiers: TileMenu.carbonModifiers) { [weak canvas] in
                        canvas?.arrange(columns: a.columns, rows: a.rows)
                    }
                }
            }
            tileHotkeys.append(Hotkey(keyCode: UInt32(TileMenu.tidyKeyCode), modifiers: TileMenu.carbonModifiers) { [weak canvas] in
                canvas?.tidy()
            })
        }
        // ⌃⌥⇧ → ←: the window to the next or previous display, from the canvas or from inside it. Only with
        // more than one display: with one, the keys stay free for other apps (`Desk.onDisplaysChanged`).
        if canvas.canvases.count > 1 {
            tileHotkeys += displayHotkeys(for: canvas)
        }
        // ⌃⌥P: the window under the pointer (or the one used last) into Picture in Picture, or out of it;
        // from a real window, that window.
        tileHotkeys.append(Hotkey(keyCode: UInt32(TileMenu.pipKeyCode), modifiers: TileMenu.carbonModifiers) { [weak canvas] in
            canvas?.togglePip()
        })
        // ⌃⌥Space: Tell Sunlight's bar, from the canvas or a window. Only with its flag on.
        if Settings.tellSunlight {
            tileHotkeys.append(Hotkey(keyCode: UInt32(kVK_Space), modifiers: TileMenu.carbonModifiers) { [weak self] in
                self?.toggleAgentBar()
            })
        }
        // ⌃⌥S: strip mode on or off, from a real window too. Only with strip mode's flag on.
        if Settings.stripModeEnabled {
            tileHotkeys.append(Hotkey(keyCode: UInt32(TileMenu.stripKeyCode), modifiers: TileMenu.carbonModifiers) { [weak canvas] in
                canvas?.toggleStripMode()
            })
        }
    }

    private func toggleAgentBar() {
        guard Settings.tellSunlight, let canvas else { return }
        if agentBar == nil {
            let bar = AgentBar(desk: canvas, onLayoutsChanged: { [weak self] in self?.rebuildLayoutsMenu() })
            bar.onOpenSettings = { [weak self] in self?.showSettings(tab: .general) }
            agentBar = bar
        }
        agentBar?.toggle()
    }

    private func displayHotkeys(for canvas: Desk) -> [Hotkey] {
        [(kVK_RightArrow, 1), (kVK_LeftArrow, -1)].map { code, step in
            Hotkey(keyCode: UInt32(code), modifiers: TileMenu.displayCarbonModifiers) { [weak canvas] in
                canvas?.moveToDisplay(step: step)
            }
        }
    }

    /// The panel's Sunlight switch. Off: the canvas goes (`CanvasController.setPaused`), the hotkeys are
    /// unregistered and takeover's key tap stops, so ⌘Tab, Mission Control, F11 and the ⌃⌥ layer
    /// are the Mac's own again; the Dock add-on and takeover's settings stay. On: all of it back, and
    /// the canvas in front.
    func setSunlightOn(_ on: Bool) {
        guard on != Settings.sunlightOn || canvas?.paused == on else { return }
        Settings.sunlightOn = on
        trackpadPan?.setActive(on)
        if on {
            if let canvas, tileHotkeys.isEmpty { installHotkeys(for: canvas) }
            if PermissionGate.current().allows(.focus) { input?.start() }
            canvas?.setPaused(false)
        } else {
            tileHotkeys = []
            input?.stop()
            canvas?.setPaused(true)
        }
        menuBar?.model.isOn = on
    }

    /// The menu bar icon with its panel, every button wired to what the menus used to call.
    private func makeMenuBar(for canvas: Desk) -> MenuBarItem {
        let item = MenuBarItem()
        item.onWillOpen = { [weak self] in self?.refreshPanel() }
        item.moreMenu = moreMenu()
        var actions = MenuBarPanelModel.Actions()
        actions.setOn = { [weak self] on in self?.setSunlightOn(on) }
        actions.tidy = { [weak canvas] in canvas?.tidy() }
        actions.toggleMinimap = { [weak canvas] in canvas?.toggleMinimap() }
        actions.toggleSwitcher = { Settings.switcherOn.toggle() }
        actions.restoreLayout = { [weak canvas] name in canvas?.restoreLayout(named: name) }
        actions.saveLayout = { [weak self] in self?.saveLayout() }
        actions.deleteLayout = { [weak self] name in
            LayoutStore.delete(name: name)
            Log.note("Layout: deleted “\(name)”")
            self?.rebuildLayoutsMenu()
        }
        actions.toggleStrip = { [weak canvas] in canvas?.toggleStripMode() }
        actions.toggleSnapshotRotation = { Settings.snapshotRotation.toggle() }
        actions.showDesktop = { [weak canvas] in canvas?.showDesktop() }
        actions.arrange = { [weak canvas] columns, rows in canvas?.arrange(columns: columns, rows: rows) }
        actions.showSettings = { [weak self] in self?.showSettings(nil) }
        actions.showInstructions = { [weak self] in self?.showInstructions(nil) }
        actions.setUp = { [weak self] in self?.showSetup() }
        actions.checkForUpdates = { [weak self] in self?.checkForUpdates() }
        actions.reloadLiveWindows = { [weak self] in self?.reloadLiveWindows() }
        actions.quit = { NSApp.terminate(nil) }
        item.model.actions = actions
        return item
    }

    /// The panel's state, pulled as it opens: what a menu's validation did as it opened.
    private func refreshPanel() {
        guard let menuBar else { return }
        let model = menuBar.model
        model.isOn = Settings.sunlightOn
        model.minimap = canvas?.isMinimapShown ?? Settings.showMinimap
        model.switcher = Settings.switcherOn
        model.stripMode = canvas?.isStripMode ?? Settings.stripMode
        model.snapshotRotation = Settings.snapshotRotation
        model.arranging = Settings.arranging
        model.stripModeEnabled = Settings.stripModeEnabled
        model.showingDesktop = canvas?.isShowingDesktop ?? false
        model.busy = canvas?.isAddingWidgets == true || canvas?.isRestoringLayout == true
        model.setupShowing = setup?.isShowing == true
        model.liveWindowsUnloaded = canvas?.canReloadLiveWindows == true
        model.canCheckForUpdates = updater?.canCheck == true
        model.updateVersion = updater?.foundVersion
        model.rendering = canvas?.renderer == .realWindows ? .live : Settings.previewMode ? .preview : .pictures
        model.layouts = MenuBarPanelModel.layoutRows(LayoutStore.layouts.map(\.name))
        if let setupStatus {
            let progress = SetupFlow.progress(for: setupStatus, mac: mac)
            model.setupProgress = MenuBarPanelModel.Progress(done: progress.done, total: progress.total)
        }
    }

    /// The icon's right-click menu: More's rows as menu items, the way the whole menu once was.
    private func moreMenu() -> NSMenu {
        let menu = NSMenu(title: "Sunlight")
        func add(_ title: String, _ action: Selector, _ key: String = "") {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.target = self
            menu.addItem(item)
        }
        add("How to Use…", #selector(showInstructions(_:)), "?")
        add("Settings…", #selector(showSettings(_:)), ",")
        add("Set Up Sunlight…", #selector(showSetup))
        add("Check for Updates…", #selector(checkForUpdates))
        add("Reload Live Windows…", #selector(reloadLiveWindows))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Sunlight", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    /// Ctrl-C in `make run` is SIGINT, which would skip the quit path and leave the Mac taken over.
    private func installSignalHandlers() {
        for sig in [SIGINT, SIGTERM] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { NSApp.terminate(nil) }
            source.resume()
            signalSources.append(source)
        }
    }

    // MARK: Menu

    /// The main menu. With no Dock icon macOS never draws it, but its key equivalents still work while a
    /// Sunlight window is key: ⌘, ⌘S ⌘1–⌘9 ⌘Z ⌘W ⌘Q and F11. Everything in it is also in the menu bar icon
    /// (`statusMenuItems`), which is the only place it can be clicked.
    private func installMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        for item in appCommandItems() { appMenu.addItem(item) }
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Sunlight", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        // Undo and redo reach the key window's undo manager: ⌘Z on the canvas puts the last background back.
        let editItem = NSMenuItem()
        main.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editItem.submenu = editMenu

        let layoutsItem = NSMenuItem()
        main.addItem(layoutsItem)
        layoutsItem.submenu = layoutsMenu
        rebuildLayoutsMenu()

        // Close only applies to the settings window; the borderless canvas has no close button, so it can't
        // be closed by accident.
        let windowItem = NSMenuItem()
        main.addItem(windowItem)
        windowItem.submenu = windowMenu
        rebuildWindowMenu()

        // No Help menu: macOS keeps ⌘? for a Help menu's search field, and with the menu bar never drawn
        // that ate the key. ⌘? is How to Use: the key tap takes it from anywhere while Sunlight has the
        // Mac (`KeyTap.Command.howToUse`); without the takeover, this catches it in any Sunlight window.
        NSApp.mainMenu = main
        if howToUseKey == nil {
            howToUseKey = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard event.modifierFlags.intersection([.command, .shift, .option, .control]) == [.command, .shift],
                      event.charactersIgnoringModifiers == "?", let self, self.setup?.isShowing != true
                else { return event }
                self.showInstructions(chapter: nil)
                return nil
            }
        }
    }

    /// ⌘? in any Sunlight window: Settings › How to use (`installMenu`).
    private var howToUseKey: Any?

    /// What was the app menu, minus Quit. Fresh items on every call: the main menu and the menu bar icon
    /// each need their own.
    private func appCommandItems() -> [NSMenuItem] {
        func item(_ title: String, _ action: Selector, _ key: String = "") -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.target = self
            return item
        }
        return [
            item("Settings…", #selector(showSettings(_:)), ","),
            item("How to Use Sunlight", #selector(showInstructions(_:)), "?"),
            item("Set Up Sunlight…", #selector(showSetup)),
            item("Check for Updates…", #selector(checkForUpdates)),
            item("Change Background…", #selector(showBackgroundSettings)),
            item("Add Widgets…", #selector(addWidgets)),
            item("Minimap", #selector(toggleMinimap)),
            item("显示操作提示", #selector(showControlHints)),
            item("Desktop Files", #selector(toggleDesktopFloor)),
            captureMethodMenuItem(),
        ]
    }

    /// Strip Mode and Show Desktop, then placement, then Close. Rebuilt rather than hidden when a flag
    /// changes, so a feature that's off has no key equivalent either.
    private func rebuildWindowMenu() {
        windowMenu.removeAllItems()
        for item in canvasItems() { windowMenu.addItem(item) }
        windowMenu.addItem(.separator())
        // Placement, in scope order: everything, one screen, one window (`TileMenu`).
        for item in TileMenu.placementItems(target: self, actions: placementActions, represent: { $0.rawValue }) {
            windowMenu.addItem(item)
        }
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
    }

    /// Settings › Experimental: arranging or strip mode turned on or off. The Window menu,
    /// the hotkeys and the menu bar panel follow; the canvas's right-click menus are built as they open.
    private func experimentalFeaturesChanged() {
        if !Settings.tellSunlight { agentBar?.shutDown() }
        rebuildWindowMenu()
        if Settings.sunlightOn, let canvas {
            tileHotkeys = []
            installHotkeys(for: canvas)
        }
        refreshPanel()
    }

    /// Strip Mode (while that feature is on) and Show Desktop: the top of the Window menu.
    private func canvasItems() -> [NSMenuItem] {
        // The canvas's mode: free, or every app on one strip (⌃⌥S).
        let strip = NSMenuItem(title: "Strip Mode", action: #selector(toggleStripMode), keyEquivalent: TileMenu.stripKey)
        strip.keyEquivalentModifierMask = TileMenu.modifiers
        strip.target = self
        // F11 reaches the canvas through the key tap while takeover runs; the item shows the key anyway.
        let showDesktop = NSMenuItem(title: "Show Desktop", action: #selector(showDesktop),
                                     keyEquivalent: String(Character(UnicodeScalar(NSF11FunctionKey)!)))
        showDesktop.keyEquivalentModifierMask = []
        showDesktop.target = self
        // A window to another display; greyed out with one display.
        let arrow = { (code: Int) in String(Character(UnicodeScalar(UInt16(code))!)) }
        let next = NSMenuItem(title: "Move to Next Display", action: #selector(moveToNextDisplay), keyEquivalent: arrow(NSRightArrowFunctionKey))
        next.keyEquivalentModifierMask = TileMenu.displayModifiers
        next.target = self
        let previous = NSMenuItem(title: "Move to Previous Display", action: #selector(moveToPreviousDisplay), keyEquivalent: arrow(NSLeftArrowFunctionKey))
        previous.keyEquivalentModifierMask = TileMenu.displayModifiers
        previous.target = self
        // The window under the pointer (or the one used last, or the one you're in) into Picture in Picture.
        let pip = NSMenuItem(title: "Picture in Picture", action: #selector(togglePip), keyEquivalent: TileMenu.pipKey)
        pip.keyEquivalentModifierMask = TileMenu.modifiers
        pip.target = self
        return (Settings.stripModeEnabled ? [strip, showDesktop] : [showDesktop]) + [.separator(), pip, .separator(), next, previous]
    }

    private var placementActions: TileMenu.Actions {
        TileMenu.Actions(tidy: #selector(tidyFromMenu), tidyBy: #selector(tidyByFromMenu(_:)),
                         arrange: #selector(arrangeFromMenu(_:)), tile: #selector(tileFromMenu(_:)))
    }

    /// Save Layout…, then every saved layout (⌘1–⌘9 for the first nine), then Delete Layout ›. Rebuilt
    /// whenever the list changes rather than as the menu opens, so the key equivalents are always there.
    /// The menu bar panel's list follows.
    private func rebuildLayoutsMenu() {
        let menu = layoutsMenu
        menu.removeAllItems()
        let save = NSMenuItem(title: "Save Layout…", action: #selector(saveLayout), keyEquivalent: "s")
        save.target = self
        menu.addItem(save)
        addLayouts(to: menu)
        menuBar?.model.layouts = MenuBarPanelModel.layoutRows(LayoutStore.layouts.map(\.name))
    }

    private func addLayouts(to layoutsMenu: NSMenu) {
        let layouts = LayoutStore.layouts
        guard !layouts.isEmpty else { return }
        layoutsMenu.addItem(.separator())
        for (i, layout) in layouts.enumerated() {
            let item = NSMenuItem(title: layout.name, action: #selector(restoreLayout(_:)), keyEquivalent: i < 9 ? "\(i + 1)" : "")
            item.target = self
            item.representedObject = layout.name
            layoutsMenu.addItem(item)
        }
        layoutsMenu.addItem(.separator())
        let delete = NSMenu()
        for layout in layouts {
            let item = NSMenuItem(title: layout.name, action: #selector(deleteLayout(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = layout.name
            delete.addItem(item)
        }
        let deleteItem = NSMenuItem(title: "Delete Layout", action: nil, keyEquivalent: "")
        deleteItem.submenu = delete
        layoutsMenu.addItem(deleteItem)
    }

    @objc private func moveToNextDisplay() {
        canvas?.moveToDisplay(step: 1)
    }

    @objc private func moveToPreviousDisplay() {
        canvas?.moveToDisplay(step: -1)
    }

    @objc private func tileFromMenu(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let preset = Tiling.Preset(rawValue: raw) else { return }
        canvas?.tile(preset)
    }

    @objc private func arrangeFromMenu(_ sender: NSMenuItem) {
        guard let a = TileMenu.arrangement(of: sender) else { return }
        canvas?.arrange(columns: a.columns, rows: a.rows)
    }

    @objc private func tidyFromMenu() {
        canvas?.tidy()
    }

    /// Window › Tidy By › an order: tidies by it, and it's the order from now on.
    @objc private func tidyByFromMenu(_ sender: NSMenuItem) {
        guard let order = TileMenu.order(of: sender) else { return }
        canvas?.tidy(by: order)
    }

    /// ⌘?, Sunlight › How to Use Sunlight and More › How to Use… in the menu bar icon: Settings › How to use.
    @objc private func showInstructions(_ sender: Any?) {
        showInstructions(chapter: nil)
    }

    /// Settings › How to use, on a chapter or where it was left. The ? in Settings › Windows opens it on
    /// Placing.
    private func showInstructions(chapter: Manual.Chapter?) {
        settingsController()?.showHowToUse(chapter)
    }

    @objc private func saveLayout() {
        canvas?.saveLayout { [weak self] in self?.rebuildLayoutsMenu() }
    }

    @objc private func restoreLayout(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        canvas?.restoreLayout(named: name)
    }

    @objc private func deleteLayout(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        LayoutStore.delete(name: name)
        Log.note("Layout: deleted “\(name)”")
        rebuildLayoutsMenu()
    }

    @objc private func showSettings(_ sender: Any?) {
        settingsController()?.showWindow(sender)
    }

    /// Settings › Background: the app menu's Change Background…, and Customise… on the canvas's menu.
    @objc private func showBackgroundSettings() {
        showSettings(tab: .background)
    }


    private func showSettings(tab: SettingsWindowController.Tab) {
        settingsController()?.show(tab: tab)
    }

    private func settingsController() -> SettingsWindowController? {
        guard let canvas else { return nil }
        if settings == nil {
            settings = SettingsWindowController(background: canvas.background)
            settings?.onTryPlacing = { [weak self] scope in
                guard let canvas = self?.canvas else { return }
                switch scope {
                case .window: canvas.tile(.leftHalf)
                case .screen: canvas.arrange(columns: 3, rows: 1)
                case .everything: canvas.tidy()
                }
            }
            settings?.onTutorial = { [weak self] in
                self?.settings?.close()
                self?.setupController().showBasics()
            }
            settings?.onMinimapChange = { [weak self] shown in
                if let canvas = self?.canvas, canvas.isMinimapShown != shown { canvas.toggleMinimap() }
            }
            settings?.onDesktopFilesChange = { [weak self] shown in
                if let canvas = self?.canvas, canvas.isDesktopFloorShown != shown { canvas.toggleDesktopFloor() }
            }
            settings?.desktopMap = { [weak self] in self?.canvas?.desktopMap }
            if updater?.canCheck == true {
                settings?.onCheckForUpdates = { [weak self] in self?.updater?.checkForUpdates() }
            }
        }
        return settings
    }

    @objc private func checkForUpdates() {
        updater?.checkForUpdates()
    }

    @objc private func showSetup() {
        setupController().show(startingLive: false)
    }

    private func setupController() -> SetupWizardController {
        if let setup { return setup }
        let controller = SetupWizardController(mac: mac, statusProvider: { SetupStatus.current() })
        controller.onVisibilityChanged = { [weak self] showing in self?.canvas?.isSetupShowing = showing }
        controller.onStatus = { [weak self] status in
            guard let self else { return }
            self.setupStatus = status
            self.menuBar?.showSetupProgress(lit: SetupFlow.litRays(for: status, mac: self.mac))
            let progress = SetupFlow.progress(for: status, mac: self.mac)
            self.menuBar?.model.setupProgress = MenuBarPanelModel.Progress(done: progress.done, total: progress.total)
            self.permissionsChanged()
        }
        setup = controller
        return controller
    }

    /// The two permissions as last read. The wizard re-reads them every pass, so a grant or a revocation
    /// made in System Settings while Sunlight is running is answered here rather than at the next launch.
    private var lastGate: PermissionGate?

    private func permissionsChanged() {
        let gate = PermissionGate.current()
        defer { lastGate = gate }
        guard let old = lastGate, old != gate else { return }
        let change = PermissionGate.Change(from: old, to: gate)
        if change.stopInput { input?.stop() }
        if change.startInput, Settings.sunlightOn { input?.start() }
        canvas?.permissionsChanged(change)
        Log.note("Permissions: Accessibility \(gate.accessibility ? "on" : "off"), Screen Recording \(gate.screenRecording ? "on" : "off")")
    }

    /// The desktop's widget gallery; the canvas steps aside while it's open.
    @objc private func addWidgets() {
        canvas?.addWidgets()
    }

    @objc private func showControlHints() {
        canvas?.showControlHints()
    }

    @objc private func toggleMinimap() {
        canvas?.toggleMinimap()
    }

    @objc private func toggleStripMode() {
        canvas?.toggleStripMode()
    }

    /// Window › Picture in Picture (⌃⌥P): the window into Picture in Picture, or out of it (`PictureInPicture`).
    @objc private func togglePip() {
        canvas?.togglePip()
    }

    /// Flies to Finder's desktop and dims the windows; again, back.
    @objc private func showDesktop() {
        canvas?.showDesktop()
    }

    /// Finder's desktop under the windows, or not.
    @objc private func toggleDesktopFloor() {
        canvas?.toggleDesktopFloor()
    }

    /// A "Capture Method ›" submenu to switch the one-shot capture path live. Both choices always show so
    /// it's clear what exists; an unavailable one is disabled (both are in live mode, where one-shot
    /// captures never run), and `validateMenuItem` checks the current.
    private func captureMethodMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Capture Method", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "Capture Method")
        for method in CaptureMethod.allCases {
            let choice = NSMenuItem(title: method.title, action: #selector(setCaptureMethod(_:)), keyEquivalent: "")
            choice.target = self
            choice.representedObject = method.rawValue
            submenu.addItem(choice)
        }
        item.submenu = submenu
        return item
    }

    @objc private func setCaptureMethod(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let method = CaptureMethod(rawValue: raw) else { return }
        Settings.captureMethod = method
        Log.note("OneShotCapture: method set to \(method.title)")
    }

    /// Loads the live-window addition into the Dock with an administrator prompt, after a Dock restart
    /// unloaded it and no passwordless reload is set up.
    @objc private func reloadLiveWindows() {
        canvas?.reloadAddition(interactive: true)
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        // While the setup window is up, nothing that would put the canvas or another window in front.
        if setup?.isShowing == true, let action = item.action,
           [#selector(addWidgets), #selector(showControlHints), #selector(reloadLiveWindows),
            #selector(saveLayout), #selector(restoreLayout(_:)), #selector(deleteLayout(_:)),
            #selector(arrangeFromMenu(_:)), #selector(tileFromMenu(_:)),
            #selector(tidyFromMenu), #selector(tidyByFromMenu(_:)), #selector(showInstructions(_:)),
            #selector(toggleStripMode)].contains(action) {
            return false
        }
        switch item.action {
        case #selector(addWidgets): return canvas?.isAddingWidgets == false
        case #selector(reloadLiveWindows): return canvas?.canReloadLiveWindows == true
        case #selector(showSetup):
            if let setupStatus { item.title = setupStatus.isComplete ? "Set Up Sunlight…" : "Finish Setting Up Sunlight…" }
            return true
        case #selector(checkForUpdates): return updater?.canCheck == true
        case #selector(toggleMinimap):
            item.state = canvas?.isMinimapShown == true ? .on : .off
            return true
        case #selector(toggleStripMode):
            item.state = canvas?.isStripMode == true ? .on : .off
            return canvas?.isAddingWidgets == false && canvas?.isRestoringLayout == false
        // Strip mode lays the windows out itself: Arrange and Tidy have nothing to do. Move & Resize
        // stays, as its arrows step along the strip.
        case #selector(arrangeFromMenu(_:)), #selector(tidyFromMenu), #selector(tidyByFromMenu(_:)):
            return canvas?.isStripMode != true
        case #selector(showDesktop):
            item.state = canvas?.isShowingDesktop == true ? .on : .off
            return canvas?.isAddingWidgets == false
        case #selector(toggleDesktopFloor):
            item.state = canvas?.isDesktopFloorShown == true ? .on : .off
            return true
        case #selector(moveToNextDisplay), #selector(moveToPreviousDisplay):
            return (canvas?.canvases.count ?? 0) > 1 && canvas?.isAddingWidgets == false
        case #selector(setCaptureMethod(_:)):
            let raw = item.representedObject as? String
            item.state = raw == Settings.captureMethod.rawValue ? .on : .off
            // One-shot captures never run in live mode (the refresh timer is gated on the capture
            // renderer), so the choice is inert there: the checkmark stays, the enablement goes.
            guard canvas?.renderer != .realWindows else { return false }
            switch raw.flatMap(CaptureMethod.init(rawValue:)) {
            case .skyLight: return OneShotCapture.skyLightAvailable
            case .screenCaptureKit: return OneShotCapture.screenCaptureKitAvailable
            case nil: return true
            }
        case #selector(saveLayout), #selector(restoreLayout(_:)), #selector(deleteLayout(_:)):
            return canvas?.isAddingWidgets == false && canvas?.isRestoringLayout == false
        default: return true
        }
    }
}
