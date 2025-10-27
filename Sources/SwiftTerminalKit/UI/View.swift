import Foundation

/// Border style for views.
public enum BorderStyle {
	case none
	case single
	case double
}

/// Base class for all composited views.
/// Holds geometry, z-order, colors, focus state and invalidation logic.
open class View {
	/// Position & size in **screen coordinates**.
	/// When moved/resized, we invalidate both the **old** and **new** rects
	/// so the compositor will repaint (clearing old borders/artifacts).
	public var frame: Rect {
		didSet {
			invalidate(oldValue)   // old area must be repainted (clears old visuals)
			invalidate(frame)      // new area must be painted
		}
	}
	
	/// Lower values are further back; higher values are in front.
	public var zIndex: Int
	
	/// Default colors for this view's drawing.
	public var foregroundColor: Console.PaletteColor = .default
	public var backgroundColor: Console.PaletteColor = .default
	
	public var fg: Console.PaletteColor {
		get { foregroundColor }
		set { foregroundColor = newValue }
	}
	
	public var bg: Console.PaletteColor {
		get { backgroundColor }
		set { backgroundColor = newValue }
	}
	
	/// Whether the view can receive focus.
	public var isFocusable: Bool = false
	
	/// True when this view currently has focus.
	public internal(set) var hasFocus: Bool = false
	
	/// How the view should draw its border (if any).
	public var borderStyle: BorderStyle = .none

    public private(set) weak var superview: View?
    private(set) var subviews: [View] = []

	
	/// Accumulated invalid region (screen coords).
	private var pending = Region()
	
	public init(frame: Rect, zIndex: Int = 0) {
		self.frame = frame
		self.zIndex = zIndex
		invalidate() // start dirty
	}

    public func addSubview(_ view: View) {
        subviews.append(view)
        view.superview = self
        invalidate(view.frame)
    }

	
	/// Mark the whole view (or a specific rect) as needing repaint.
	public func invalidate(_ r: Rect? = nil) {
		if let r = r { pending.add(r) } else {
			pending.add(frame)
		}
	}
	
	/// Grab and clear the currently invalid region (for the compositor).
	internal func takeInvalidRegion() -> [Rect] {
		var tmp = pending
		tmp.normalize()
		pending.clear()
		return tmp.rects
	}
	
	/// Default drawing: fill background. Subclasses override to draw content.
	open func draw(into surface: Surface, clip: Rect) {
		surface.fill(clip, cell: .init(" ", fg: fg, bg: bg))

        for subview in subviews {
            let subviewClip = clip.intersection(subview.frame)
            if !subviewClip.isEmpty {
                subview.draw(into: surface, clip: subviewClip)
            }
        }
	}
	
	/// Hit-testing helper.
	public func hitTest(x: Int, y: Int) -> Bool { frame.contains(x, y) }
}
