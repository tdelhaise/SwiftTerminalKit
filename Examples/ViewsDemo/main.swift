import SwiftTerminalKit
import Foundation

do {
    let console = try Console()
    console.clear()
    console.setTitle("SwiftTerminalKit - Views Demo")

    let screen = Screen(console: console)
    var cols = console.size.cols
    var rows = console.size.rows

    let left  = Panel(frame: Rect(2, 2, max(20, cols/2 - 3), max(6, rows - 4)), zIndex: 0, title: "Left panel",  color: .brightGreen)
    let right = Panel(frame: Rect(cols/2, 4, max(24, cols/2 - 4), max(8, rows - 8)), zIndex: 1, title: "Right panel", color: .brightYellow)
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
                right.frame = Rect(c/2, 4, max(24, c/2 - 4), max(8, r - 8)); right.invalidate()
                left.frame  = Rect(2, 2, max(20, c/2 - 3), max(6, r - 4));   left.invalidate()
                screen.render()
            case .key(let k, _):
                switch k {
                case .char("q"): running = false
                case .tab:
                    // toggle focus
                    if left.hasFocus { screen.setFocus(right) } else { screen.setFocus(left) }
                    screen.render()
                case .left:  right.frame.x = max(1, right.frame.x - 1); right.invalidate(); screen.render()
                case .right: right.frame.x = min(cols - 3, right.frame.x + 1); right.invalidate(); screen.render()
                case .up:    right.frame.y = max(1, right.frame.y - 1); right.invalidate(); screen.render()
                case .down:  right.frame.y = min(rows - 3, right.frame.y + 1); right.invalidate(); screen.render()
                default: break
                }
            default: break
            }
        }
    }
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}
