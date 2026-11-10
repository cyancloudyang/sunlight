import XCTest
@testable import Canvas

final class SetupFlowTests: XCTestCase {
    private typealias Record = SetupFlow.Record

    private func status(accessibility: Bool = true, screenRecording: Bool = true, sip: Bool = true, bootArgument: Bool = true,
                        helper: SetupStatus.Helper = .daemonEnabled, loaded: Bool = true) -> SetupStatus {
        SetupStatus(accessibility: accessibility, screenRecording: screenRecording, sipAllowsLiveWindows: sip,
                    bootArgument: bootArgument, helper: helper, liveWindowsLoaded: loaded)
    }

    private let fresh = SetupStatus(accessibility: false, screenRecording: false, sipAllowsLiveWindows: false,
                                    bootArgument: false, helper: .daemonNotRegistered, liveWindowsLoaded: false)
    private let permissionsDone = SetupStatus(accessibility: true, screenRecording: true, sipAllowsLiveWindows: false,
                                              bootArgument: false, helper: .daemonNotRegistered, liveWindowsLoaded: false)
    private let welcomed = Record(welcomed: true, loginItemChosen: true, learnedBasics: true)
    private let live = Record(welcomed: true, loginItemChosen: true, learnedBasics: true, consented: true, startedLive: true)
    /// Consented, the helper on, nothing else: the Mac as it is when the Recovery page shows.
    private let helperOn = SetupStatus(accessibility: true, screenRecording: true, sipAllowsLiveWindows: false,
                                       bootArgument: false, helper: .daemonEnabled, liveWindowsLoaded: false)

    private func page(_ status: SetupStatus, _ record: Record, mac: SetupFlow.Mac = .supported) -> SetupFlow.Page {
        SetupFlow.page(for: status, record: record, mac: mac)
    }

    // MARK: The preview phase

    func testAFreshMacStartsAtWelcomeThenThePermissions() {
        XCTAssertEqual(page(fresh, .fresh), .welcome)
        XCTAssertEqual(page(fresh, Record(welcomed: true)), .loginItem, "open at login has a page of its own")
        XCTAssertEqual(page(fresh, Record(welcomed: true, loginItemChosen: true)), .accessibility, "the permissions before the tutorial")
        XCTAssertEqual(page(fresh, welcomed), .accessibility)
        XCTAssertEqual(page(status(screenRecording: false, sip: false, bootArgument: false, helper: .daemonNotRegistered, loaded: false), welcomed), .screenRecording)
        XCTAssertEqual(page(permissionsDone, welcomed), .preview)
    }

    func testScreenRecordingCanBeSkippedAndTheRelaunchComesBackToIt() {
        var skipped = welcomed
        skipped.skippedScreenRecording = true
        let noRecording = status(screenRecording: false, sip: false, bootArgument: false, helper: .daemonNotRegistered, loaded: false)
        XCTAssertEqual(page(noRecording, skipped), .preview)
        var resuming = welcomed
        resuming.resume = .screenRecording
        XCTAssertEqual(page(noRecording, resuming), .screenRecording)
        XCTAssertEqual(page(permissionsDone, resuming), .preview, "granted: the relaunch lands past the permission")
    }

    func testThePreviewPageIsTheEndOfTheWizard() {
        XCTAssertEqual(page(permissionsDone, welcomed), .preview)
        var started = welcomed
        started.startedLive = true
        XCTAssertEqual(page(permissionsDone, started), .preview, "Tablecloth has no live-windows phase")
    }

    func testAMacWithoutLiveWindowsStaysOnThePreview() {
        let intel = SetupFlow.Mac(appleSilicon: false, osSupported: true, admin: true)
        XCTAssertFalse(intel.liveWindowsSupported)
        XCTAssertEqual(page(permissionsDone, live, mac: intel), .preview)
        XCTAssertEqual(SetupFlow.rail(for: permissionsDone, record: live, mac: intel, showing: .preview).count, 5)
        XCTAssertTrue(SetupFlow.progress(for: permissionsDone, mac: intel) == (2, 2))
        XCTAssertNil(SetupFlow.litRays(for: permissionsDone, mac: intel))
    }

    // MARK: No live phase

    /// The live-windows phase is gone: no record or status routes to its pages, and a stale Recovery
    /// resume lands on the canvas page.
    func testNoLivePhase() {
        for record in [live, welcomed] {
            XCTAssertEqual(page(permissionsDone, record), .preview)
            XCTAssertEqual(page(helperOn, record), .preview)
            XCTAssertEqual(page(status(loaded: false), record), .preview)
            XCTAssertEqual(page(status(), record), .preview)
        }
        var back = live
        back.resume = .recovery
        XCTAssertEqual(page(helperOn, back), .preview)
    }

    /// The load page starts the load as it opens once the daemon is on and nothing can ask; a build
    /// without the daemon waits for the button, since its load may put up the administrator prompt.
    func testTheLoadRunsByItselfOnceNothingWillAsk() {
        XCTAssertTrue(SetupFlow.loadsByItself(status(loaded: false)))
        XCTAssertFalse(SetupFlow.loadsByItself(status(helper: .passwordless, loaded: false)))
        XCTAssertFalse(SetupFlow.loadsByItself(status(helper: .asksForPassword, loaded: false)))
        XCTAssertFalse(SetupFlow.loadsByItself(status(helper: .daemonNeedsApproval, loaded: false)))
        XCTAssertFalse(SetupFlow.loadsByItself(status(helper: .daemonNotRegistered, loaded: false)))
        XCTAssertFalse(SetupFlow.loadsByItself(status(helper: .missing, loaded: false)))
    }

    func testLoadedEndsOnTheCanvasPage() {
        XCTAssertEqual(page(status(), live), .preview)
        XCTAssertEqual(page(status(), welcomed), .preview)
    }

    // MARK: Opening at launch

    func testOpensAtLaunchForThePreviewAndForAResume() {
        XCTAssertTrue(SetupFlow.opensAtLaunch(status: fresh, record: .fresh, mac: .supported, previewMode: true, showsAtLaunch: true))
        XCTAssertTrue(SetupFlow.opensAtLaunch(status: permissionsDone, record: .fresh, mac: .supported, previewMode: true, showsAtLaunch: true), "never welcomed")
        XCTAssertFalse(SetupFlow.opensAtLaunch(status: permissionsDone, record: welcomed, mac: .supported, previewMode: true, showsAtLaunch: true), "the preview works: the demo mode card takes over")
        var skipped = welcomed
        skipped.skippedScreenRecording = true
        XCTAssertFalse(SetupFlow.opensAtLaunch(status: status(screenRecording: false, sip: false, bootArgument: false, helper: .daemonNotRegistered, loaded: false),
                                               record: skipped, mac: .supported, previewMode: true, showsAtLaunch: true))
        var back = live
        back.resume = .recovery
        XCTAssertTrue(SetupFlow.opensAtLaunch(status: permissionsDone, record: back, mac: .supported, previewMode: true, showsAtLaunch: false))
        // Past preview mode, the checkbox rules while a permission is missing; live steps never count.
        XCTAssertTrue(SetupFlow.opensAtLaunch(status: status(screenRecording: false), record: live, mac: .supported, previewMode: false, showsAtLaunch: true))
        XCTAssertFalse(SetupFlow.opensAtLaunch(status: status(screenRecording: false), record: live, mac: .supported, previewMode: false, showsAtLaunch: false))
        XCTAssertFalse(SetupFlow.opensAtLaunch(status: status(bootArgument: false, loaded: false), record: live, mac: .supported, previewMode: false, showsAtLaunch: true),
                       "SIP and the add-on are not Tablecloth steps")
        XCTAssertFalse(SetupFlow.opensAtLaunch(status: status(), record: live, mac: .supported, previewMode: false, showsAtLaunch: true))
    }

    // MARK: The rail and the rays

    func testTheRailIsAlwaysTheFiveCanvasSteps() {
        let rail = SetupFlow.rail(for: permissionsDone, record: welcomed, mac: .supported, showing: .preview)
        XCTAssertEqual(rail.map(\.title), ["Welcome", "Accessibility", "Screen Recording", "The basics", "Preview"])
        XCTAssertEqual(rail.map(\.state), [.done, .done, .done, .done, .current])
        let started = SetupFlow.rail(for: helperOn, record: live, mac: .supported, showing: .preview)
        XCTAssertEqual(started.map(\.title), rail.map(\.title), "no live-windows entries, even for a record that started them")
    }

    func testTheRaysFollowProgress() {
        XCTAssertTrue(SetupFlow.progress(for: fresh, mac: .supported) == (0, 2))
        XCTAssertEqual(SetupFlow.litRays(for: fresh, mac: .supported), 0)
        XCTAssertTrue(SetupFlow.progress(for: permissionsDone, mac: .supported) == (2, 2))
        XCTAssertNil(SetupFlow.litRays(for: permissionsDone, mac: .supported))
        XCTAssertNil(SetupFlow.litRays(for: status(loaded: false), mac: .supported), "live windows never count")
    }

    /// Open at login: asked once, after the welcome, inside the Welcome step; a Mac welcomed before the
    /// page existed answered it there, and never sees it.
    func testOpenAtLoginIsItsOwnPageInTheWelcomeStep() {
        let chosenNot = Record(welcomed: true)
        XCTAssertEqual(page(permissionsDone, chosenNot), .loginItem, "even with the permissions already granted")
        XCTAssertTrue(SetupFlow.opensAtLaunch(status: permissionsDone, record: chosenNot, mac: .supported, previewMode: true, showsAtLaunch: true))
        let rail = SetupFlow.rail(for: fresh, record: chosenNot, mac: .supported, showing: .loginItem)
        XCTAssertEqual(rail.first?.title, "Welcome")
        XCTAssertEqual(rail.first?.state, .current)
        XCTAssertEqual(rail.count, SetupFlow.rail(for: fresh, record: .fresh, mac: .supported, showing: .welcome).count)
        XCTAssertEqual(SetupFlow.rail(for: fresh, record: welcomed, mac: .supported, showing: .accessibility).first?.state, .done)
        XCTAssertFalse(SetupFlow.Page.loginItem.isLive)

        XCTAssertTrue(SetupRecord.loginItemChosen(stored: nil, welcomed: true), "welcomed before the page existed")
        XCTAssertFalse(SetupRecord.loginItemChosen(stored: nil, welcomed: false))
        XCTAssertFalse(SetupRecord.loginItemChosen(stored: false, welcomed: true), "Get Started stores false")
        XCTAssertTrue(SetupRecord.loginItemChosen(stored: true, welcomed: true))
    }

    /// The wizard comes back in front by itself only when a step it sent the person away for gets done.
    func testComesBackOnlyWhenAStepGetsDone() {
        XCTAssertEqual(SetupFlow.stepFinished(from: fresh, to: status(screenRecording: false, sip: false, bootArgument: false, helper: .daemonNotRegistered, loaded: false)), "Accessibility")
        XCTAssertEqual(SetupFlow.stepFinished(from: status(screenRecording: false, sip: false, bootArgument: false, helper: .daemonNotRegistered, loaded: false), to: permissionsDone), "Screen Recording")
        XCTAssertEqual(SetupFlow.stepFinished(from: status(sip: false, bootArgument: false, helper: .daemonNeedsApproval, loaded: false), to: helperOn), "the background helper")
        XCTAssertEqual(SetupFlow.stepFinished(from: status(loaded: false), to: status()), "loading live windows")
        XCTAssertNil(SetupFlow.stepFinished(from: fresh, to: fresh), "nothing changed")
        XCTAssertNil(SetupFlow.stepFinished(from: permissionsDone, to: fresh), "a permission taken away isn't a reason to jump forward")
        XCTAssertNil(SetupFlow.stepFinished(from: status(sip: false, helper: .daemonNotRegistered), to: status(sip: false, helper: .daemonNeedsApproval)), "registered, still waiting for approval")
    }

    /// The tutorial: once, after the permissions and before "You're set", and the wizard opens for it at
    /// launch until it's done; a Mac that has had live windows never sees it.
    func testTheTutorialComesOnceBeforeTheCanvasOpens() {
        let notLearned = Record(welcomed: true, loginItemChosen: true)
        XCTAssertEqual(page(permissionsDone, notLearned), .basics)
        var skipped = notLearned
        skipped.skippedScreenRecording = true
        XCTAssertEqual(page(status(screenRecording: false, sip: false, bootArgument: false, helper: .daemonNotRegistered, loaded: false), skipped), .basics)
        XCTAssertEqual(page(permissionsDone, welcomed), .preview)
        XCTAssertEqual(page(status(), Record(welcomed: true, loginItemChosen: true, consented: true, startedLive: true)), .preview, "no live phase: the canvas page")
        XCTAssertFalse(SetupFlow.Page.basics.isLive)
        XCTAssertTrue(SetupFlow.opensAtLaunch(status: permissionsDone, record: notLearned, mac: .supported, previewMode: true, showsAtLaunch: true))
        XCTAssertFalse(SetupFlow.opensAtLaunch(status: permissionsDone, record: welcomed, mac: .supported, previewMode: true, showsAtLaunch: true))
        let rail = SetupFlow.rail(for: permissionsDone, record: notLearned, mac: .supported, showing: .basics)
        XCTAssertEqual(rail.first { $0.state == .current }?.title, "The basics")
        XCTAssertTrue(SetupFlow.progress(for: permissionsDone, mac: .supported) == (2, 2), "the tutorial isn't a step the rays count")
    }

    func testEveryReviewScenarioLandsOnItsPage() {
        let expected: [String: SetupFlow.Page] = [
            "fresh": .welcome, "login-item": .loginItem, "basics": .basics, "permissions-done": .preview, "helper-waiting": .preview, "sip-on": .preview, "boot-arg-missing": .preview,
            "ready-to-load": .preview, "ad-hoc-build": .preview, "done": .preview, "intel": .preview, "no-admin": .preview,
        ]
        for scenario in SetupReview.scenarios {
            XCTAssertEqual(SetupFlow.page(for: scenario.status, record: scenario.record, mac: scenario.mac), expected[scenario.name], scenario.name)
        }
        XCTAssertEqual(Set(SetupReview.scenarios.map(\.name)).count, SetupReview.scenarios.count)
    }
}
