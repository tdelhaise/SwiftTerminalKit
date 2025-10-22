import SwiftTerminalKit
import Foundation

do {
    let console = try Console()
    console.clear()
    console.setTitle("SwiftTerminalKit - Views Demo")

    let screen = Screen(console: console)
	screen.backgroundBG = .gray(level: 1)
    var cols = console.size.cols
    var rows = console.size.rows

	let left  = Panel(frame: Rect(2, 2, max(20, cols/2 - 3), max(6, rows - 4)), zIndex: 0, title: "Left panel",  color: .brightGreen, border: .single)
	let right = Panel(frame: Rect(cols/2, 4, max(24, cols/2 - 4), max(8, rows - 8)), zIndex: 1, title: "Right panel", color: .brightYellow, border: .double)
    screen.addView(left)
    screen.addView(right)
    screen.setFocus(right)
    screen.render()

    var running = true
    while running {
        if let ev = console.pollEvent(timeoutMs: 50) {
            switch ev {
				case .resize(let c, let r):
					cols = c; rows = r
					screen.resizeToConsole()
					right.frame = Rect(c/2, 4, max(24, c/2 - 4), max(8, r - 8))
					right.invalidate()
					left.frame  = Rect(2, 2, max(20, c/2 - 3), max(6, r - 4))
					left.invalidate()
					screen.render()
				case .key(let k, _):
					switch k {
						case .char("q"):
							running = false
						case .char("f"), .tab:
							// toggle focus
							if left.hasFocus {
								fputs("focus will be set on right\n", stderr)
								screen.setFocus(right)
							} else {
								fputs("focus will be set on left\n", stderr)
								screen.setFocus(left)
							}
						case .left:
							let focusPanel = left.hasFocus ? left : right
							focusPanel.frame.x = max(1, focusPanel.frame.x - 1)
						case .right:
							let focusPanel = left.hasFocus ? left : right
							focusPanel.frame.x = min(cols - 3, focusPanel.frame.x + 1)
						case .up:
							let focusPanel = left.hasFocus ? left : right
							focusPanel.frame.y = max(1, focusPanel.frame.y - 1)
						case .down:
							let focusPanel = left.hasFocus ? left : right
							focusPanel.frame.y = min(rows - 3, focusPanel.frame.y + 1)
						default:
							break
					}
					screen.render()
				default:
					break
            }
        }
    }
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}
