import SwiftTerminalKit
import Foundation

// Draw a filled cell using background color
func fill(_ console: Console, x: Int, y: Int, width: Int, color: Console.PaletteColor) {
    console.setColor(fg: .default, bg: color)
    console.moveTo(x: x, y: y)
    console.write(String(repeating: " ", count: width))
    console.setColor(fg: .default, bg: .default)
}

do {
    let c = try Console()
    c.setTitle("SwiftTerminalKit – ColorPaletteDemo")
    c.clear()

    var row = 2
    c.write("ANSI named (0–15)", at: (2, row), fg: .named(.brightGreen), bg: .default)
    row += 1

    // 0..15 (named) as background swatches
    for i in 0..<16 {
        fill(c, x: 2 + i*3, y: row, width: 3, color: .index(i))
    }
    row += 2

    // 6x6x6 cube (16..231)
    c.write("Color cube (16–231)", at: (2, row), fg: .named(.brightGreen), bg: .default)
    row += 1
    // 6 hues rows, each row: 6*6 = 36 blocks
    for rr in 0..<6 {
        var x = 2
        for gg in 0..<6 {
            for bb in 0..<6 {
                let idx = 16 + 36*rr + 6*gg + bb
                fill(c, x: x, y: row, width: 2, color: .index(idx))
                x += 2
            }
            x += 2 // small gap between groups
        }
        row += 1
    }
    row += 1

    // Grayscale (232..255)
    c.write("Grayscale (232–255)", at: (2, row), fg: .named(.brightGreen), bg: .default)
    row += 1
    for i in 232...255 {
        fill(c, x: 2 + (i-232)*2, y: row, width: 2, color: .index(i))
    }
    row += 2

    // TrueColor demo (auto-fallback via your Console)
    c.write("TrueColor gradient (auto-falls back to 256)", at: (2, row), fg: .named(.brightGreen), bg: .default)
    row += 1

    let width = max(60, c.size.cols - 4)
    for x in 0..<width {
        // Smooth hue-ish gradient across width (simple siney RGB)
        let t = Double(x) / Double(max(1,width-1))
        let r = UInt8((sin((t + 0.00) * .pi) * 127 + 128).rounded())
        let g = UInt8((sin((t + 0.33) * .pi) * 127 + 128).rounded())
        let b = UInt8((sin((t + 0.66) * .pi) * 127 + 128).rounded())
        fill(c, x: 2 + x, y: row, width: 1, color: .rgb(r, g, b))
    }
    row += 2

    c.write("Press 'q' to quit.", at: (2, row), fg: .named(.brightYellow), bg: .default)
    c.present()

    var running = true
    while running {
        if let ev = c.pollEvent(timeoutMs: 200) {
            if case let .key(k, _) = ev, k == .char("q") { running = false }
        }
    }
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}
