import Foundation

open class View {
    public var frame: Rect
    public var zIndex: Int
    public var fg: Console.PaletteColor = .default
    public var bg: Console.PaletteColor = .default
    public var isFocusable: Bool = false
    public internal(set) var hasFocus: Bool = false
    private var pending = Region()

    public init(frame: Rect, zIndex: Int = 0) {
        self.frame = frame
        self.zIndex = zIndex
        invalidate()
    }

    public func invalidate(_ r: Rect? = nil) {
        if let r = r { pending.add(r) } else { pending.add(frame) }
    }
    internal func takeInvalidRegion() -> [Rect] {
        var tmp = pending; tmp.normalize(); pending.clear(); return tmp.rects
    }

    open func draw(into surface: Surface, clip: Rect) {
        surface.fill(clip, cell: .init(" ", fg: fg, bg: bg))
    }

    public func hitTest(x: Int, y: Int) -> Bool { frame.contains(x, y) }
}
