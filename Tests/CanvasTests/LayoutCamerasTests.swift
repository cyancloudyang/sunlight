import XCTest
import CoreGraphics
@testable import Canvas

final class LayoutCamerasTests: XCTestCase {
    private func layout(cameras: [String: Layout.DisplayCamera]? = nil) -> Layout {
        var l = Layout(name: "", saved: Date(timeIntervalSince1970: 0), center: .init(x: 500, y: 400), zoom: 0.5, entries: [])
        l.cameras = cameras
        return l
    }

    @MainActor
    func testEachDisplayHasItsOwnCameraAndTheLeadFallsBackToTheMainOne() {
        let size = CGSize(width: 1000, height: 800)
        let side = Layout.DisplayCamera(center: .init(x: 2500, y: 300), zoom: 0.25)
        let l = layout(cameras: ["SIDE": side])
        let own = l.camera(for: "SIDE", lead: false, viewSize: size)
        XCTAssertEqual(own?.zoom, 0.25)
        XCTAssertEqual(own?.center(viewSize: size), CGPoint(x: 2500, y: 300))
        // From before there was a camera per display: the lead takes the main one, another display none.
        XCTAssertEqual(l.camera(for: "MAIN", lead: true, viewSize: size)?.center(viewSize: size), CGPoint(x: 500, y: 400))
        XCTAssertNil(l.camera(for: "OTHER", lead: false, viewSize: size))
    }

    @MainActor
    func testWrittenDownAndReadBack() throws {
        let size = CGSize(width: 1000, height: 800)
        let camera = Camera(center: CGPoint(x: -1200, y: 90), zoom: 0.4, viewSize: size)
        let l = layout(cameras: ["SIDE": Layout.displayCamera(camera, viewSize: size)])
        let back = try JSONDecoder().decode(Layout.self, from: JSONEncoder().encode(l))
        XCTAssertEqual(back.cameras, l.cameras)
        XCTAssertTrue(back.sameArrangement(as: l))
        XCTAssertFalse(layout().sameArrangement(as: l))
    }

    func testALayoutFromBeforeDecodesWithoutCameras() throws {
        let json = #"{"name":"","saved":0,"center":{"x":1,"y":2},"zoom":1,"entries":[]}"#
        let l = try JSONDecoder().decode(Layout.self, from: Data(json.utf8))
        XCTAssertNil(l.cameras)
    }

    func testBookmarksWrittenDownAndReadBack() throws {
        var l = layout()
        l.bookmarks = ["1": Layout.DisplayCamera(center: .init(x: -400, y: 250), zoom: 0.5),
                       "9": Layout.DisplayCamera(center: .init(x: 1200, y: -800), zoom: 0.1)]
        let back = try JSONDecoder().decode(Layout.self, from: JSONEncoder().encode(l))
        XCTAssertEqual(back.bookmarks, l.bookmarks)
        XCTAssertTrue(back.sameArrangement(as: l))
        // A bookmark saved is a change worth writing down, though nothing moved.
        XCTAssertFalse(layout().sameArrangement(as: l))
    }

    @MainActor
    private static func proxy(id: CGWindowID, x: CGFloat) -> WindowProxy {
        WindowProxy(info: WindowInfo(id: id, pid: getpid(), layer: 0,
                                    bounds: CGRect(x: x, y: 40, width: 800, height: 600),
                                    title: "Untitled", alpha: 1), camera: Camera(), scale: 1)
    }

    func testSameTitleMatchesLiveIDsBeforeSavedOrder() async {
        await MainActor.run {
            let first = Self.proxy(id: 20, x: -1000)
            let second = Self.proxy(id: 10, x: 2000)
            let entries = [Layout.Entry(first, document: nil), Layout.Entry(second, document: nil)]
            let pairs = Layout.match(entries, [second, first])
            XCTAssertEqual(pairs.map(\.entry), [0, 1])
            XCTAssertEqual(pairs.map(\.proxy.windowID), [20, 10])
            for (index, p) in pairs { p.place(entries[index].frame.cgRect) }
            XCTAssertEqual(first.worldRect.minX, -1000)
            XCTAssertEqual(second.worldRect.minX, 2000)
        }
    }

    func testSameTitleAfterRestartUsesIDOrderRegardlessOfListingOrder() async {
        await MainActor.run {
            let entries = [Layout.Entry(Self.proxy(id: 20, x: -1000), document: nil),
                           Layout.Entry(Self.proxy(id: 10, x: 2000), document: nil)]
            let low = Self.proxy(id: 101, x: 0)
            let high = Self.proxy(id: 102, x: 0)
            for listing in [[high, low], [low, high], [high, low]] {
                let pairs = Layout.match(entries, listing)
                XCTAssertEqual(pairs.map(\.entry), [0, 1])
                XCTAssertEqual(pairs.map(\.proxy.windowID), [101, 102])
            }
        }
    }

    func testALayoutFromBeforeDecodesWithoutBookmarks() throws {
        let json = #"{"name":"","saved":0,"center":{"x":1,"y":2},"zoom":1,"entries":[]}"#
        let l = try JSONDecoder().decode(Layout.self, from: Data(json.utf8))
        XCTAssertNil(l.bookmarks)
    }
}
