import SwiftTerminalKit
import Foundation

final class EditorView: View {
	private var lines: [[Character]] = [[]]
	private var cx = 0, cy = 0
	
	public override func draw(into s: Surface, clip: Rect) {
		s.fill(clip, cell: .init(" ", fg: .named(.brightWhite), bg: .gray(level: 2)))
		let r = frame
		
		let maxY = min(lines.count, r.h - 2)
		for row in 0..<maxY {
			let y = r.y + 1 + row
			if y < clip.y || y >= clip.y + clip.h { continue }
			let text = String(lines[row])
			let visible = String(text.prefix(max(0, r.w - 2)))
			s.putString(x: r.x + 1, y: y, text: visible, fg: .named(.brightWhite), bg: .gray(level: 2))
		}
		
		let status = "  Ctrl+S save  Ctrl+Q quit  [\(cx+1),\(cy+1)]  "
		let bar = String(status.prefix(max(0, r.w)))
		s.putString(x: r.x, y: r.y + r.h - 1, text: bar, fg: .named(.brightBlack), bg: .gray(level: 3))
	}
	
	func insert(_ c: Character) {
		ensureRow(cy)
		lines[cy].insert(c, at: cx)
		cx += 1; invalidate(frame)
	}
	func backspace() {
		ensureRow(cy)
		if cx > 0 { lines[cy].remove(at: cx-1); cx -= 1 }
		else if cy > 0 {
			let tail = lines[cy]
			cy -= 1; cx = lines[cy].count
			lines[cy].append(contentsOf: tail)
			lines.remove(at: cy+1)
		}
		invalidate(frame)
	}
	func newline() {
		ensureRow(cy)
		let tail = Array(lines[cy].dropFirst(cx))
		lines[cy] = Array(lines[cy].prefix(cx))
		cy += 1; cx = 0
		lines.insert(tail, at: cy)
		invalidate(frame)
	}
	func moveLeft()  { if cx > 0 { cx -= 1 } else if cy > 0 { cy -= 1; cx = lines[cy].count }; invalidate(frame) }
	func moveRight() { ensureRow(cy); if cx < lines[cy].count { cx += 1 } else if cy+1 < lines.count { cy += 1; cx = 0 }; invalidate(frame) }
	func moveUp()    { if cy > 0 { cy -= 1; cx = min(cx, lines[cy].count) }; invalidate(frame) }
	func moveDown()  { if cy+1 < lines.count { cy += 1; cx = min(cx, lines[cy].count) }; invalidate(frame) }
	
	func save(to path: String) throws {
		let text = lines.map{ String($0) }.joined(separator: "\n")
		try text.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
	}
	
	private func ensureRow(_ y: Int) {
		while y >= lines.count { lines.append([]) }
	}
}

// Affiche un log sur la dernière ligne sans casser l'écran
func logAtBottom(_ console: Console, _ text: String) {
	let cols = console.size.cols
	let rows = console.size.rows
	let msg  = String(text.prefix(max(0, cols))) // évite de dépasser
	
	// Sauver la position du curseur
	console.write("\u{001B}[s")
	// Aller au début de la dernière ligne
	console.moveTo(x: 1, y: rows)
	// Effacer toute la ligne
	console.write("\u{001B}[2K")
	// Couleurs du log (optionnel)
	console.setColor(fg: .named(.brightYellow), bg: .gray(level: 3))
	console.write(msg)
	// Reset couleurs
	console.setColor(fg: .default, bg: .default)
	// Restaurer la position du curseur
	console.write("\u{001B}[u")
}


do {
	let console = try Console()
	console.clear()
	console.setTitle("SwiftTerminalKit - TextEdit Demo")
	
	let screen = Screen(console: console)
	screen.backgroundBG = .gray(level: 1)
	
	var cols = console.size.cols
	var rows = console.size.rows
	
	let editor = EditorView(frame: Rect(2, 2, max(20, cols-4), max(6, rows-4)), zIndex: 0)
	editor.fg = .named(.brightWhite)
	editor.bg = .gray(level: 2)
	editor.borderStyle = .single
	screen.addView(editor)
	screen.setFocus(editor)
	screen.render()
	
	let loop = STKRunLoop(console: console, screen: screen)
	
	_ = loop.runSync { ev in
		switch ev {
			case .resize(let c, let r):
				cols = c; rows = r
				editor.frame = Rect(2, 2, max(20, c-4), max(6, r-4))
				return true
				
			case .key(let k):
				if case .char(let ch) = k.keyCode {
					let scal = ch.unicodeScalars.first!.value
					logAtBottom(console, "KEY char=\(ch) U+\(String(format: "%04X", scal)) mods=\(k.mods.rawValue)")
				}
				switch k.keyCode {
					case .char(let ch):
						if ch == "$" {
							return false
						}
						if k.mods.contains(.ctrl) {
							if ch == "q" || ch == "Q" {
								return false
							}
							if ch == "s" || ch == "S" {
								do {
									try editor.save(to: "textedit.txt")
								} catch {
									
								}
								return true
							}
						}
						if ch == "\n" || ch == "\r" {
							editor.newline();
							return true
						}
						if ch == "\u{8}" || ch == "\u{7F}" {
							editor.backspace();
							return true
						}
						if ch.isNewline {
							editor.newline();
							return true
						}
						if ch >= " " {
							editor.insert(ch)
						}
						return true
					case .left:
						editor.moveLeft();
						return true
					case .right:
						editor.moveRight();
						return true
					case .up:
						editor.moveUp();
						return true
					case .down:
						editor.moveDown();
						return true
					case .tab:
						editor.insert("\t");
						return true
					default:
						logAtBottom(console, "KEY \(k.keyCode) mods=\(k.mods.rawValue)")
						return true
				}
			default:
				return true
		}
	}
} catch {
	fputs("Error: \(error)\n", stderr)
	exit(1)
}
