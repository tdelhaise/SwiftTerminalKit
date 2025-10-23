import SwiftTerminalKit
import Foundation

do {
	let console = try Console()
	console.clear()
	console.setTitle("SwiftTerminalKit - Views Demo (RunLoop)")
	
	let screen = Screen(console: console)
	screen.backgroundBG = .gray(level: 1)
	var cols = console.size.cols
	var rows = console.size.rows
	
	let left  = Panel(
		frame: Rect(2, 2, max(20, cols/2 - 3), max(6, rows - 4)),
		zIndex: 0,
		title: "Left panel",
		color: .brightGreen,
		border: .double
	)
	let right = Panel(
		frame: Rect(cols/2, 4, max(24, cols/2 - 4), max(8, rows - 8)),
		zIndex: 1,
		title: "Right panel",
		color: .brightYellow,
		border: .single
	)
	screen.addView(left)
	screen.addView(right)
	screen.setFocus(right)
	screen.render()
	
	let loop = STKRunLoop(console: console, screen: screen)
	
	_ = loop.runSync { ev in
		switch ev {
			case .resize(let c, let r):
				cols = c; rows = r
				screen.resizeToConsole()
				right.frame = Rect(c/2, 4, max(24, c/2 - 4), max(8, r - 8))
				left.frame  = Rect(2, 2, max(20, c/2 - 3), max(6, r - 4))
				return true
				
			case .key(let k):
				switch k.keyCode {
					case .char("q"): return false
					case .tab:
						screen.setFocus(left.hasFocus ? right : left)
						return true
					case .shiftTab:
						screen.setFocus(right.hasFocus ? left : right)
						return true
					case .left:
						right.frame.x = max(1, right.frame.x - 1)
						return true
					case .right:
						right.frame.x = min(cols - 3, right.frame.x + 1)
						return true
					case .up:
						right.frame.y = max(1, right.frame.y - 1)
						return true
					case .down:
						right.frame.y = min(rows - 3, right.frame.y + 1)
						return true
					default:
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
