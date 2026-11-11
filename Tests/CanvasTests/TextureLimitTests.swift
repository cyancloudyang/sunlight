import CoreGraphics
import XCTest
@testable import Canvas

/// Snapshots are kept for as long as their proxy lives: a cap on the long edge is what keeps a map of
/// big windows inside a MacBook Air's memory (#7 in the handoff).
final class TextureLimitTests: XCTestCase {
    func testASmallImageKeepsItsSize() {
        XCTAssertEqual(TextureLimit.size(for: CGSize(width: 800, height: 600)), CGSize(width: 800, height: 600))
    }

    func testAnImageAtTheLimitIsLeftAlone() {
        XCTAssertEqual(TextureLimit.size(for: CGSize(width: 1024, height: 640)), CGSize(width: 1024, height: 640))
    }

    func testALandscapeImageIsScaledToTheLimit() {
        XCTAssertEqual(TextureLimit.size(for: CGSize(width: 2000, height: 1000)), CGSize(width: 1024, height: 512))
    }

    func testAPortraitImageIsScaledToTheLimit() {
        XCTAssertEqual(TextureLimit.size(for: CGSize(width: 500, height: 1536)), CGSize(width: 333, height: 1024))
    }

    /// A 5K window's frame: the case the cap exists for.
    func testABigFrameIsScaledDownKeptInProportion() {
        let size = TextureLimit.size(for: CGSize(width: 5120, height: 2880))
        XCTAssertEqual(size, CGSize(width: 1024, height: 576))
        XCTAssertEqual(size.width / size.height, 5120.0 / 2880.0, accuracy: 0.01)
    }

    func testAOnePixelImageStaysOnePixel() {
        XCTAssertEqual(TextureLimit.size(for: CGSize(width: 1, height: 1)), CGSize(width: 1, height: 1))
    }

    func testACustomLimitIsHonoured() {
        XCTAssertEqual(TextureLimit.size(for: CGSize(width: 800, height: 400), longEdge: 200), CGSize(width: 200, height: 100))
    }

    // MARK: The image itself

    func testABiggerImageComesBackSmaller() throws {
        let image = try XCTUnwrap(bitmap(width: 2048, height: 1024))
        let fitted = TextureLimit.fit(image)
        XCTAssertEqual(fitted.width, 1024)
        XCTAssertEqual(fitted.height, 512)
    }

    func testASmallerImageIsNotEnlarged() throws {
        let image = try XCTUnwrap(bitmap(width: 320, height: 200))
        let fitted = TextureLimit.fit(image)
        XCTAssertEqual(fitted.width, 320)
        XCTAssertEqual(fitted.height, 200)
    }

    func testAFittingImageIsNotCopied() throws {
        let image = try XCTUnwrap(bitmap(width: 1024, height: 768))
        XCTAssertTrue(TextureLimit.fit(image) === image, "at the limit there is nothing to do")
    }

    func testAScaledImageKeepsItsColourSpace() throws {
        let image = try XCTUnwrap(bitmap(width: 1600, height: 900))
        let fitted = TextureLimit.fit(image)
        XCTAssertEqual(fitted.colorSpace?.name, image.colorSpace?.name)
    }

    private func bitmap(width: Int, height: Int) -> CGImage? {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else { return nil }
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}

/// The stream's frames take the same cap as a snapshot.
@MainActor
final class StreamPixelSizeTests: XCTestCase {
    func testAWindowAtLevelZeroIsCapped() {
        let size = WindowCapture.pixelSize(real: CGSize(width: 2560, height: 1440), scale: 2, factor: 1)
        XCTAssertEqual(size.width, 1024)
        XCTAssertEqual(size.height, 576)
    }

    func testASmallWindowKeepsItsSize() {
        let size = WindowCapture.pixelSize(real: CGSize(width: 400, height: 300), scale: 2, factor: 1)
        XCTAssertEqual(size.width, 800)
        XCTAssertEqual(size.height, 600)
    }

    func testAZoomedOutWindowStaysProportionalAndTinyFloor() {
        let size = WindowCapture.pixelSize(real: CGSize(width: 1200, height: 800), scale: 2, factor: 0.125)
        XCTAssertEqual(size.width, 300)
        XCTAssertEqual(size.height, 200)
        let floor = WindowCapture.pixelSize(real: CGSize(width: 1, height: 1), scale: 1, factor: 1)
        XCTAssertEqual(floor.width, 2)
        XCTAssertEqual(floor.height, 2)
    }
}
