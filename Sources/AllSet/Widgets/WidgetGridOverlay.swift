import AllSetCore
import AppKit
import QuartzCore

/// The desktop grid, shown only while a widget is being dragged: the free
/// slots, faintly, and the one the widget will land in. Drawn with Core
/// Animation layers, so it costs the app nothing per frame.
@MainActor
final class WidgetGridOverlay {
    private var panel: NSPanel?
    private var view: WidgetGridOverlayView?
    private(set) var screen: NSScreen?
    private var grid: WidgetGrid?
    private var scale: CGFloat = 1

    /// What a drop from the gallery does; set while one is under way.
    var onDragUpdate: (@MainActor (CGPoint) -> Void)?
    var onDrop: (@MainActor (CGPoint) -> Bool)?

    /// Shown, or on its way; false once hiding starts.
    private(set) var isShowing = false

    /// Shows the grid on `screen`. `occupied` (layout rects) stay unmarked.
    /// With `acceptsDrops`, the overlay dims the screen and takes the drop.
    func show(on screen: NSScreen, grid: WidgetGrid, scale: CGFloat, occupied: [CGRect],
              level: NSWindow.Level, below window: NSWindow? = nil, acceptsDrops: Bool = false) {
        let panel = self.panel ?? makePanel()
        let view = self.view ?? WidgetGridOverlayView()
        if panel.contentView !== view { panel.contentView = view }
        self.screen = screen
        self.grid = grid
        self.scale = scale
        panel.level = level
        panel.ignoresMouseEvents = !acceptsDrops
        if panel.frame != screen.visibleFrame { panel.setFrame(screen.visibleFrame, display: false) }
        view.acceptsDrops = acceptsDrops
        view.overlay = self
        view.draw(cells: freeCells(grid, avoiding: occupied), scale: scale, dims: acceptsDrops)
        view.target(nil)
        if let window {
            panel.order(.below, relativeTo: window.windowNumber)
        } else {
            panel.orderFront(nil)
        }
        if !isShowing {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = Motion.reducesMotion ? 0 : 0.15
                panel.animator().alphaValue = 1
            }
        }
        isShowing = true
        self.panel = panel
        self.view = view
    }

    /// Highlights where the widget will land (a layout rect), or nothing.
    func highlight(_ rect: CGRect?) {
        view?.target(rect.map { CGRect(x: $0.minX * scale, y: $0.minY * scale, width: $0.width * scale, height: $0.height * scale) })
    }

    func hide() {
        guard isShowing, let panel else { return }
        isShowing = false
        view?.target(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Motion.reducesMotion ? 0 : 0.18
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                if self?.isShowing == false { panel.orderOut(nil) }
            }
        }
    }

    /// A point on screen, in the layout points of the screen shown.
    func layoutPoint(_ point: CGPoint) -> CGPoint? {
        guard let screen else { return nil }
        let visible = screen.visibleFrame
        return CGPoint(x: (point.x - visible.minX) / scale, y: (visible.maxY - point.y) / scale)
    }

    private func freeCells(_ grid: WidgetGrid, avoiding occupied: [CGRect]) -> [CGRect] {
        let side = WidgetGrid.pitch - WidgetLayout.spacing
        var cells: [CGRect] = []
        for column in 0..<grid.columns {
            for row in 0..<grid.rows {
                let corner = grid.offset(of: WidgetGrid.Cell(column: column, row: row))
                let cell = CGRect(origin: corner, size: CGSize(width: side, height: side))
                guard !occupied.contains(where: { $0.insetBy(dx: 1, dy: 1).intersects(cell) }) else { continue }
                cells.append(CGRect(x: cell.minX * scale, y: cell.minY * scale, width: cell.width * scale, height: cell.height * scale))
            }
        }
        return cells
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.alphaValue = 0
        return panel
    }

    fileprivate func dragUpdated(_ point: CGPoint) { onDragUpdate?(point) }
    fileprivate func dropped(_ point: CGPoint) -> Bool { onDrop?(point) ?? false }
}

/// Draws the slots and the target; takes a widget dropped from the gallery.
private final class WidgetGridOverlayView: NSView {
    weak var overlay: WidgetGridOverlay?
    var acceptsDrops = false {
        didSet {
            if acceptsDrops {
                registerForDraggedTypes([.string])
            } else {
                unregisterDraggedTypes()
            }
        }
    }

    private let dim = CALayer()
    private let cells = CAShapeLayer()
    private let slot = CAShapeLayer()

    override var isFlipped: Bool { true }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.addSublayer(dim)
        layer?.addSublayer(cells)
        layer?.addSublayer(slot)
        dim.backgroundColor = NSColor.black.withAlphaComponent(0.32).cgColor
        cells.fillColor = NSColor.white.withAlphaComponent(0.05).cgColor
        cells.strokeColor = NSColor.white.withAlphaComponent(0.22).cgColor
        cells.lineWidth = 1
        cells.lineDashPattern = [5, 4]
        slot.fillColor = NSColor.white.withAlphaComponent(0.18).cgColor
        slot.strokeColor = NSColor.white.withAlphaComponent(0.85).cgColor
        slot.lineWidth = 2
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for sublayer in [dim, cells, slot] as [CALayer] { sublayer.frame = bounds }
        CATransaction.commit()
    }

    func draw(cells rects: [CGRect], scale: CGFloat, dims: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dim.isHidden = !dims
        let path = CGMutablePath()
        let radius = 18 * scale
        for rect in rects {
            path.addRoundedRect(in: rect.insetBy(dx: 0.5, dy: 0.5), cornerWidth: radius, cornerHeight: radius)
        }
        cells.path = path
        CATransaction.commit()
    }

    func target(_ rect: CGRect?) {
        guard let rect else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            slot.path = nil
            CATransaction.commit()
            return
        }
        let radius = min(22, rect.height / 4)
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        // Glides from slot to slot, unless it's appearing.
        CATransaction.begin()
        CATransaction.setDisableActions(slot.path == nil || Motion.reducesMotion)
        CATransaction.setAnimationDuration(0.16)
        slot.path = path
        CATransaction.commit()
    }

    // MARK: Dropping from the gallery

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        draggingUpdated(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard acceptsDrops, let window else { return [] }
        overlay?.dragUpdated(window.convertPoint(toScreen: sender.draggingLocation))
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        target(nil)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard acceptsDrops, let window else { return false }
        return overlay?.dropped(window.convertPoint(toScreen: sender.draggingLocation)) ?? false
    }
}
