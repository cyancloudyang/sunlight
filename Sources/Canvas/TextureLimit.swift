import CoreGraphics

/// A cap on the snapshots the canvas keeps.
///
/// Every proxy holds its picture for as long as the window is on the map, and on a Retina Mac a big
/// window's native frame is thousands of pixels across: 5120×2880 is 59 MB at four bytes a pixel, times
/// every window on the map. A proxy drawn a few hundred points wide can't show that detail anyway, so
/// every kept frame — the routine tick, the handoff seam, the private path, the desktop floor — is scaled
/// to at most `longEdge` on its longest side, in proportion. Smaller frames are left alone rather than
/// enlarged.
enum TextureLimit {
    /// The longest edge a kept frame may have (#7 in the handoff).
    static let longEdge = 1024

    /// The size to keep, from the size a capture came back at: scaled down in proportion when the long
    /// edge is over the limit, unchanged otherwise. Never zero, never bigger than what came in.
    static func size(for size: CGSize, longEdge: Int = TextureLimit.longEdge) -> CGSize {
        let longest = max(size.width, size.height)
        guard longest > CGFloat(longEdge), longest > 0 else { return size }
        let scale = CGFloat(longEdge) / longest
        return CGSize(width: max(1, (size.width * scale).rounded()),
                      height: max(1, (size.height * scale).rounded()))
    }

    /// `image`, scaled down to the limit if it is over it. An image that already fits comes back as it
    /// is, not copied.
    static func fit(_ image: CGImage, longEdge: Int = TextureLimit.longEdge) -> CGImage {
        let target = size(for: CGSize(width: image.width, height: image.height), longEdge: longEdge)
        let width = Int(target.width)
        let height = Int(target.height)
        guard width != image.width || height != image.height, width > 0, height > 0 else { return image }
        // The image's own colour space: a widened-gamut window stays as it was, rather than being drawn
        // through sRGB and coming back duller.
        let space = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else {
            return image
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? image
    }
}
