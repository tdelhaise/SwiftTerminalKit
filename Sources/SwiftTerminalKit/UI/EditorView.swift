import Foundation

public final class EditorView: View {
	private var lines: [[Character]] = [[]]
	public var cursorX = 0
	public var cursorY = 0
	
	public var borderTitle: String = ""
	public var statusHint: String = ""
	
	public override init(frame: Rect, zIndex: Int = 0) {
		super.init(frame: frame, zIndex: zIndex)
		backgroundColor = .named(.blue)
		foregroundColor = .named(.brightWhite)
	}
	
	public func load(text: String) {
		lines = text.split(separator: "\n", omittingEmptySubsequences: false).map { Array($0) }
		if lines.isEmpty { lines = [[]] }
		cursorX = 0; cursorY = 0
		invalidate()
	}
	
	public func contents() -> String {
		lines.map { String($0) }.joined(separator: "\n")
	}

    public override func cursorPosition() -> (x: Int, y: Int)? {
        guard hasFocus else { return nil }
        let innerWidth = max(0, frame.w - 2)
        let innerHeight = max(0, frame.h - 2)
        guard innerWidth > 0, innerHeight > 0 else { return nil }
        let clampedY = max(0, min(cursorY, innerHeight - 1))
        let clampedX = max(0, min(cursorX, innerWidth - 1))
        let screenX = frame.x + 1 + clampedX
        let screenY = frame.y + 1 + clampedY
        return (screenX, screenY)
    }
	
	public override func draw(into surface: Surface, clip: Rect) {
		let fg = foregroundColor
		let bg = backgroundColor
		surface.fill(clip, cell: .init(" ", fg: fg, bg: bg))
		drawBorder(into: surface, clip: clip)
		
		let textAreaHeight = max(0, frame.h - 2)
		let maxVisible = min(lines.count, textAreaHeight)
		for row in 0..<maxVisible {
			let y = frame.y + 1 + row
			if y < clip.y || y >= clip.y + clip.h { continue }
			let line = String(lines[row])
			let visible = String(line.prefix(max(0, frame.w - 2)))
			surface.putString(x: frame.x + 1, y: y, text: visible, fg: fg, bg: bg)
		}
	}
	
	private func drawBorder(into surface: Surface, clip: Rect) {
		let r = frame
		guard r.w >= 2, r.h >= 2 else { return }
		let fg = foregroundColor
		let bg = backgroundColor

        let topRect = Rect(r.x, r.y, r.w, 1)
        if !clip.intersection(topRect).isEmpty {
            let topLine = "┌" + String(repeating: "─", count: max(0, r.w - 2)) + "┐"
            surface.putString(x: r.x, y: r.y, text: topLine, fg: fg, bg: bg)
            if !borderTitle.isEmpty && r.w > 4 {
                var title = borderTitle
                if title.count > r.w - 2 {
                    title = String(title.prefix(r.w - 2))
                }
                let start = r.x + max(1, (r.w - title.count) / 2)
                surface.putString(x: start, y: r.y, text: title, fg: fg, bg: bg)
            }
        }

        let bottomRect = Rect(r.x, r.y + r.h - 1, r.w, 1)
        if !clip.intersection(bottomRect).isEmpty {
            let bottomLine = "└" + String(repeating: "─", count: max(0, r.w - 2)) + "┘"
            surface.putString(x: r.x, y: r.y + r.h - 1, text: bottomLine, fg: fg, bg: bg)
        }

        if r.h > 2 {
            let yStart = max(r.y + 1, clip.y)
            let yEnd = min(r.y + r.h - 1, clip.y + clip.h)
            if yStart < yEnd {
                for y in yStart..<yEnd {
                    if clip.contains(r.x, y) {
                        surface.putString(x: r.x, y: y, text: "│", fg: fg, bg: bg)
                    }
                    if clip.contains(r.x + r.w - 1, y) {
                        surface.putString(x: r.x + r.w - 1, y: y, text: "│", fg: fg, bg: bg)
                    }
                }
            }
        }
	}
	
	private func ensureRow(_ y: Int) {
		while y >= lines.count { lines.append([]) }
	}
	
	    public override func handle(event: KeyEvent) -> Bool {		let mods = event.mods
		switch event.keyCode {
			case .char(let ch):
				if mods.contains(.ctrl) || mods.contains(.meta) { return false }
				if ch == "\n" || ch == "\r" { newline(); return true }
				if ch == "\u{8}" || ch == "\u{7F}" { backspace(); return true }
				if ch.isNewline { newline(); return true }
				if ch >= " " { insert(ch) }
				return true
			case .left: moveLeft(); return true
			case .right: moveRight(); return true
			case .up: moveUp(); return true
			case .down: moveDown(); return true
			case .home:
				cursorX = 0
				invalidate(frame)
				return true
			case .end:
				ensureRow(cursorY)
				cursorX = lines[cursorY].count
				invalidate(frame)
				return true
			case .pageUp:
				cursorY = max(0, cursorY - max(1, frame.h - 3))
				ensureRow(cursorY)
				cursorX = min(cursorX, lines[cursorY].count)
				invalidate(frame)
				return true
			case .pageDown:
				cursorY = min(lines.count - 1, cursorY + max(1, frame.h - 3))
				ensureRow(cursorY)
				cursorX = min(cursorX, lines[cursorY].count)
				invalidate(frame)
				return true
			case .insert, .delete:
				return false
			case .backspace:
				backspace(); return true
			case .tab:
				if mods.contains(.shift) { return false }
				insert("\t"); return true
			case .enter:
				newline(); return true
			default:
				return false
		}
	}
	
	private func insert(_ c: Character) {
		ensureRow(cursorY)
		lines[cursorY].insert(c, at: cursorX)
		cursorX += 1
		invalidate(frame)
	}
	
	private func backspace() {
		ensureRow(cursorY)
		if cursorX > 0 {
			lines[cursorY].remove(at: cursorX - 1)
			cursorX -= 1
		} else if cursorY > 0 {
			let tail = lines[cursorY]
			cursorY -= 1
			cursorX = lines[cursorY].count
			lines[cursorY].append(contentsOf: tail)
			lines.remove(at: cursorY + 1)
		}
		invalidate(frame)
	}
	
	private func newline() {
		ensureRow(cursorY)
		let tail = Array(lines[cursorY].dropFirst(cursorX))
		lines[cursorY] = Array(lines[cursorY].prefix(cursorX))
		cursorY += 1
		cursorX = 0
		lines.insert(tail, at: cursorY)
		invalidate(frame)
	}
	
	private func moveLeft() {
		if cursorX > 0 {
			cursorX -= 1
		} else if cursorY > 0 {
			cursorY -= 1
			cursorX = lines[cursorY].count
		}
		invalidate(frame)
	}
	
	private func moveRight() {
		ensureRow(cursorY)
		if cursorX < lines[cursorY].count {
			cursorX += 1
		} else if cursorY + 1 < lines.count {
			cursorY += 1
			cursorX = 0
		}
		invalidate(frame)
	}
	
	private func moveUp() {
		if cursorY > 0 {
			cursorY -= 1
			cursorX = min(cursorX, lines[cursorY].count)
		}
		invalidate(frame)
	}
	
	private func moveDown() {
		if cursorY + 1 < lines.count {
			cursorY += 1
			cursorX = min(cursorX, lines[cursorY].count)
		}
		invalidate(frame)
	}
}
