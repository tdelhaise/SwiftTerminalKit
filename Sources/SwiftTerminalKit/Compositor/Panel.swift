import Foundation

/// Simple concrete view with background, optional border, and a title.
/// Shows `[ * ]` marker when it has focus.
public final class Panel: View {
	public let title: String
	
	public init(frame: Rect, zIndex: Int, title: String, color: Console.NamedColor,	border: BorderStyle = .single) {
		self.title = title
		super.init(frame: frame, zIndex: zIndex)
		self.bg = .gray(level: 2)
		self.fg = .named(color)
		self.isFocusable = true
		self.borderStyle = border
	}
	
	public override func draw(into s: Surface, clip: Rect) {
		// Background first
		s.fill(clip, cell: .init(" ", fg: fg, bg: bg))
		
		let r = self.frame
		
		// Fast exit if no border — still draw title (inline) if there is room.
		guard borderStyle != .none else {
			if r.contains(r.x + 2, r.y) && clip.intersects(Rect(r.x + 2, r.y, max(0, title.count + 4), 1)) {
				let mark = hasFocus ? "[*] " : "[ ] "
				s.putString(x: r.x + 2, y: r.y, text: mark + title, fg: fg, bg: bg)
			}
			return
		}
		
		// Box-drawing characters depending on the style.
		let (h, v, tl, tr, bl, br): (String, String, String, String, String, String)
		switch borderStyle {
			case .single:
				(h, v, tl, tr, bl, br) = ("─","│","┌","┐","└","┘")
			case .double:
				(h, v, tl, tr, bl, br) = ("═","║","╔","╗","╚","╝")
			case .none:
				// already handled by guard
				return
		}
		
		// Top edge
		if clip.intersects(Rect(r.x, r.y, r.w, 1)) {
			if r.w >= 1 {
				s.putString(x: r.x, y: r.y, text: tl, fg: fg, bg: bg)
				if r.w >= 2 {
					if r.w > 2 {
						s.putString(x: r.x + 1, y: r.y, text: String(repeating: h, count: r.w - 2), fg: fg, bg: bg)
					}
					s.putString(x: r.x + r.w - 1, y: r.y, text: tr, fg: fg, bg: bg)
				}
			}
		}
		
		// Bottom edge
		if clip.intersects(Rect(r.x, r.y + r.h - 1, r.w, 1)) {
			if r.w >= 1 {
				s.putString(x: r.x, y: r.y + r.h - 1, text: bl, fg: fg, bg: bg)
				if r.w >= 2 {
					if r.w > 2 {
						s.putString(x: r.x + 1, y: r.y + r.h - 1, text: String(repeating: h, count: r.w - 2), fg: fg, bg: bg)
					}
					s.putString(x: r.x + r.w - 1, y: r.y + r.h - 1, text: br, fg: fg, bg: bg)
				}
			}
		}
		
		// Left/right edges (only if there is vertical room inside)
		if r.h >= 3 {
			let inner = r.h - 2
			// Left
			if clip.intersects(Rect(r.x, r.y + 1, 1, inner)) {
				for yy in 0..<inner { s.put(r.x, r.y + 1 + yy, .init(v, fg: fg, bg: bg)) }
			}
			// Right
			if clip.intersects(Rect(r.x + r.w - 1, r.y + 1, 1, inner)) {
				for yy in 0..<inner { s.put(r.x + r.w - 1, r.y + 1 + yy, .init(v, fg: fg, bg: bg)) }
			}
		}
		
		// Title over top border (trim to fit)
		if r.w >= 6 && r.contains(r.x + 2, r.y) {
			let mark = hasFocus ? "[*] " : "[ ] "
			let text = mark + title
			let visible = String(text.prefix(max(0, r.w - 4)))
			if !visible.isEmpty {
				s.putString(x: r.x + 2, y: r.y, text: visible, fg: fg, bg: bg)
			}
		}
	}
}
