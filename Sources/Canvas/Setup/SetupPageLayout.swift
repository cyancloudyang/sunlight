import CoreGraphics

/// Where the wizard's action row sits: a fixed distance up from the content area's bottom edge, the
/// same on every page. The illustration above it flexes to fill the middle; the primary button never
/// moves with the demo's height, so the click target stays in one predictable place.
struct SetupPageLayout: Equatable {
    /// From the content area's bottom edge to the action row's bottom, unscaled. Lower-middle: clear of
    /// the Set Up Later row at the very bottom, below the vertical centre.
    static let bottomMargin: CGFloat = 140

    let area: CGRect
    let scale: CGFloat

    /// The action row's bottom edge. Only the area and the scale set it — never the demo's height.
    var actionsBottom: CGFloat { area.maxY - Self.bottomMargin * scale }
}