import SwiftTerminalKit
import Foundation

do {
    let console = try Console()
    console.setTitle("SwiftTerminalKit – BasicDemo")
    console.clear()
    console.write("SwiftTerminalKit Basic Demo", at: (2, 2), fg: .index(82))
    console.write("Press 'q' to quit. Try arrow keys. Resize the terminal.", at: (2, 4), fg: .index(33))

    var running = true
    var y = 6
    while running {
        if let ev = console.pollEvent(timeoutMs: 200) {
            switch ev {
            case .key(let key, _):
                switch key {
                case .char("q"):
                    running = false
                case .up:    console.write("↑", at: (2, y), fg: .index(160)); y += 1
                case .down:  console.write("↓", at: (2, y), fg: .index(34));  y += 1
                case .left:  console.write("←", at: (2, y), fg: .index(80));  y += 1
                case .right: console.write("→", at: (2, y), fg: .index(45));  y += 1
                default: break
                }
            case .resize(let cols, let rows):
                console.write("Resized to \(cols)x\(rows) at \(Date())        ", at: (2, 5), fg: .index(220))
            default: break
            }
            console.present()
        }
    }
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}
