import Foundation

public final class Surface {
	public struct Cell {
		public var ch: String
		public var fg: Console.PaletteColor
		public var bg: Console.PaletteColor
		public init(_ ch: String = " ", fg: Console.PaletteColor = .default, bg: Console.PaletteColor = .default) {
			self.ch = ch; self.fg = fg; self.bg = bg
		}
	}
	
	public private(set) var width: Int
	public private(set) var height: Int
	private var cur: [Cell]
	private var prev: [Cell]
	
	public init(width: Int, height: Int) {
		self.width = max(1, width)
		self.height = max(1, height)
		self.cur = Array(repeating: Cell(), count: self.width * self.height)
		self.prev = cur
	}
	
	@inline(__always) private func idx(_ x: Int, _ y: Int) -> Int {
		y * width + x
	}
	
	// ---- NEW: structural equality helpers (no Equatable requirement) ----
	@inline(__always) private func paletteEqual(_ a: Console.PaletteColor, _ b: Console.PaletteColor) -> Bool {
		switch (a, b) {
			case (.named(let n1), .named(let n2)):
				return n1 == n2
			case (.gray(let g1), .gray(let g2)):
				return g1 == g2
			case (.index(let i1), .index(let i2)):
				return i1 == i2
			case (.rgb(let r1, let g1, let b1), .rgb(let r2, let g2, let b2)):
				return r1 == r2 && g1 == g2 && b1 == b2
			case (.default, .default):
				return true
			default:
				return false
		}
	}
	
	@inline(__always) private func cellEqual(_ a: Cell, _ b: Cell) -> Bool {
		return a.ch == b.ch && paletteEqual(a.fg, b.fg) && paletteEqual(a.bg, b.bg)
	}
	// --------------------------------------------------------------------
	
	public func resize(_ w: Int, _ h: Int) {
		let nw = max(1, w), nh = max(1, h)
		if nw == width && nh == height { return }
		var next = Array(repeating: Cell(), count: nw * nh)
		let cw = min(nw, width), ch = min(nh, height)
		for y in 0..<ch {
			for x in 0..<cw {
				next[y * nw + x] = cur[y * width + x]
			}
		}
		width = nw; height = nh; cur = next; prev = Array(repeating: Cell(), count: nw * nh)
	}
	
	public func put(_ x: Int, _ y: Int, _ c: Cell) {
		guard x >= 0, y >= 0, x < width, y < height else {
			return
		}
		cur[idx(x, y)] = c
	}
	
	public func putString(x: Int, y: Int, text: String, fg: Console.PaletteColor = .default, bg: Console.PaletteColor = .default) {
		guard y >= 0, y < height, x < width else {
			return
		}
		var cx = max(0, x)
		for g in text {
			if cx >= width {
				break
			}
			put(cx, y, Cell(String(g), fg: fg, bg: bg));
			cx += 1
		}
	}
	
	public func fill(_ r: Rect, cell: Cell) {
		let x0 = max(0, r.x), y0 = max(0, r.y)
		let x1 = min(width, r.x + r.w), y1 = min(height, r.y + r.h)
		guard x0 < x1 && y0 < y1 else { return }
		for y in y0..<y1 {
			var i = idx(x0, y)
			for _ in x0..<x1 {
				cur[i] = cell; i += 1
			}
		}
	}
	
	public func present(to console: Console, only regions: [Rect]) {
		guard !regions.isEmpty else {
			return
		}
		for r in regions {
			let x0 = max(0, r.x), y0 = max(0, r.y)
			let x1 = min(width, r.x + r.w), y1 = min(height, r.y + r.h)
			guard x0 < x1 && y0 < y1 else {
				continue
			}
			for y in y0..<y1 {
				var x = x0
				while x < x1 {
					// skip identical cells
					while x < x1 && cellEqual(cur[idx(x,y)], prev[idx(x,y)]) {
						x += 1
					}
					if x >= x1 {
						break
					}
					
					let start = x
					let first = cur[idx(x,y)]
					let runFG = first.fg, runBG = first.bg
					x += 1
					while x < x1 {
						let c = cur[idx(x,y)], p = prev[idx(x,y)]
						if cellEqual(c, p) {
							break
						}
						if !paletteEqual(c.fg, runFG) || !paletteEqual(c.bg, runBG) {
							break
						}
						x += 1
					}
					
					console.moveTo(x: start + 1, y: y + 1)
					console.setColor(fg: runFG, bg: runBG)
					var s = String(); s.reserveCapacity(x - start)
					for xx in start..<x {
						s.append(cur[idx(xx,y)].ch)
					}
					console.write(s)
				}
			}
		}
		if prev.count != cur.count {
			prev = Array(repeating: Cell(), count: cur.count)
		}
		for i in 0..<cur.count {
			prev[i] = cur[i]
		}
		console.setColor(fg: .default, bg: .default)
		console.present()
	}
}
