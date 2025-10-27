import Foundation

public final class Screen {
	private let console: Console
	private var surface: Surface
	private var views: [View] = []
	public private(set) var focusedView: View? = nil
	
	// Screen-wide background (base layer)
	public var backgroundFG: Console.PaletteColor = .default
	public var backgroundBG: Console.PaletteColor = .default
	
	// When true, we force a one-shot full repaint (e.g. first frame, after resize).
	private var needsFullRepaint: Bool = true
	
	public init(console: Console) {
		self.console = console
		let s = console.size
		self.surface = Surface(width: s.cols, height: s.rows)
		self.needsFullRepaint = true
	}
	
	public var size: (cols: Int, rows: Int) { console.size }
	
	public func addView(_ v: View) { views.append(v); sortViews() }
	public func removeView(_ v: View) {
		if let i = views.firstIndex(where: { $0 === v }) { views.remove(at: i) }
		if focusedView === v { focusedView = nil }
	}
	
	public func setFocus(_ v: View?) {		
		let old = focusedView
		if old === v { return }           // no-op if nothing changes
		old?.hasFocus = false
		focusedView = v
		focusedView?.hasFocus = true
		// invalidate BOTH so headers/markers redraw
		old?.invalidate()
		focusedView?.invalidate()
	}
	
	public func resizeToConsole() {
		let s = console.size
		surface.resize(s.cols, s.rows)
		invalidateAll()
		needsFullRepaint = true
	}
	
	public func invalidateAll() { for v in views { v.invalidate() } }
	
	public func render() {
		var damage = Region()
		
		// Force a full repaint once (startup/resize) so the base background is uniform.
		if needsFullRepaint {
			damage.add(Rect(0, 0, surface.width, surface.height))
			needsFullRepaint = false
		}
		
		// Collect per-view invalid regions
		for v in views {
			let rs = v.takeInvalidRegion()
			if !rs.isEmpty { damage.add(rs) }
		}
		if damage.isEmpty { return }
		damage.normalize()
		
		let ordered = views.sorted { $0.zIndex < $1.zIndex }
		
		for rect in damage.rects {
			// 1) Clear to screen background inside the damage
			surface.fill(rect, cell: .init(" ", fg: backgroundFG, bg: backgroundBG))
			
			// 2) Draw all views that overlap this rect in z-order
			for v in ordered {
				let clip = v.frame.intersection(rect)
				if !clip.isEmpty { v.draw(into: surface, clip: clip) }
			}
		}
		
		console.hideCursor(true)
		surface.present(to: console, only: damage.rects)
		console.hideCursor(false)
	}
	
	private func sortViews() { views.sort { $0.zIndex < $1.zIndex } }
}
