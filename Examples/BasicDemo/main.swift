import SwiftTerminalKit
import Foundation

do {
    let console = try Console()
    console.setTitle("SwiftTerminalKit – BasicDemo")
    console.clear()
	console.write("SwiftTerminalKit Basic Demo", at: (2, 2),
				  fg: Console.PaletteColor.named(.brightGreen),
				  bg: Console.PaletteColor.gray(level: 3))
	
	console.write("Hex color demo", at: (2, 3),
				  fg: Console.PaletteColor.hex("#1f77b4"),
				  bg: Console.PaletteColor.default)
	
    var running = true
    var y = 6
    while running {
        if let ev = console.pollEvent(timeoutMs: 200) {
            switch ev {
            case .key(let key, _):
                switch key {
                case .char("q"):
                    running = false
					case .up:
						console.write("↑", at: (2, y),
									  fg: Console.PaletteColor.named(.brightRed),
									  bg: nil); y += 1
					case .down:
						console.write("↓", at: (2, y),
									  fg: Console.PaletteColor.named(.brightGreen),
									  bg: nil); y += 1
					case .left:
						console.write("←", at: (2, y),
									  fg: Console.PaletteColor.named(.brightBlue),
									  bg: nil); y += 1
					case .right:
						console.write("→", at: (2, y),
									  fg: Console.PaletteColor.named(.brightYellow),
									  bg: nil); y += 1                default: break
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
