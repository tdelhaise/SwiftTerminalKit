import SwiftTerminalKit
import Foundation

// MARK: - Config

/// Which Unicode blocks to showcase (mostly TUI-friendly glyphs).
private let BLOCKS: [(ClosedRange<UInt32>, String)] = [
    (0x0000...0x007F, "Basic Latin (ASCII 0x7F)"),
    (0x0080...0x00FF, "Latin-1 Supplement (0xFF)"),
    (0x2190...0x21FF, "Arrows (0x2190-0x21FF)"),
    (0x2500...0x257F, "Box Drawing (0x2500-0x257F)"),
    (0x2580...0x259F, "Block Elements (0x2580-0x25FF)"),
    (0x25A0...0x25FF, "Geometric Shapes (0x25A0-0x25FF)"),
    (0x2600...0x26FF, "Miscellaneous Symbols (0x2600-0x26FF)"),
    (0x2800...0x28FF, "Braille Patterns (0x2800-0x28FF)"),
]

/// Table layout
private let COLS = 16 // hex grid across
private let LEFT = 2  // left margin

// MARK: - Utilities

private func hexNibble(_ v: Int) -> String {
    let s = "0123456789ABCDEF"
    return String(s[s.index(s.startIndex, offsetBy: v & 0xF)])
}

private func isRenderable(_ scalar: UnicodeScalar) -> Bool {
    // Consider "renderable" if not control and not whitespace-only beyond a plain space.
    if CharacterSet.controlCharacters.contains(scalar) { return false }
    if CharacterSet.whitespacesAndNewlines.contains(scalar) && scalar != " " { return false }
    // Many glyphs exist but are zero-width or combining; keep them minimal
    // (combining marks typically render oddly in a grid)
    if scalar.properties.canonicalCombiningClass != .notReordered { return false }
    return true
}

private func renderGlyph(_ u: UInt32) -> String {
    if let scalar = UnicodeScalar(u) {
        if isRenderable(scalar) {
			return String(Character(scalar))
		}
        // Show a middle dot for non printable
        return "."
    }
    return " " // unassigned
}

// MARK: - Drawing

private func drawHeader(_ console: Console, title: String, range: ClosedRange<UInt32>, page: Int, total: Int, y: inout Int) {
	var outX = LEFT
	var outY = y
	
	console.write(title, at: (outX, outY), fg: .named(.brightGreen), bg: .default)
    let meta = "  [\(page+1)/\(total)] ← / → switch • q quit"
	outX = LEFT + title.count + 1
	console.write(meta, at: (outX, outY), fg: .named(.brightBlack), bg: .default)
    outY += 1

    // Column header 0..F
	outX = LEFT
	console.write("        ", at: (outX, outY), fg: .named(.brightBlack), bg: .default)
    for x in 0..<COLS {
		outX = LEFT + 8 + (x*2)
		console.write(" \(hexNibble(x))", at: (outX, outY), fg: .named(.brightBlack), bg: .default)
    }
    outY += 1
	y = outY
}

private func drawGrid(_ console: Console, range: ClosedRange<UInt32>, startY: inout Int) {
    let total = Int(range.count)
    let rows = (total + COLS - 1) / COLS

    var y = startY
    var u = Int(range.lowerBound)

	for _ in 0..<rows {
        // Left row label (e.g., "U+250x")
        let rowBase = u & ~0xF
        let rowLabel = String(format: "U+%04X", rowBase)
		console.write(rowLabel, at: (LEFT, y), fg: .named(.brightBlack), bg: .default)

        for x in 0..<COLS {
            let code = rowBase + x
            let xpos = LEFT + 4 + x*2
            if code >= Int(range.lowerBound) && code <= Int(range.upperBound) {
                let glyph = renderGlyph(UInt32(code))
				console.write(glyph, at: (xpos, y), fg: .default, bg: .default)
            } else {
				console.write(" ", at: (xpos, y), fg: .default, bg: .default)
            }
        }
        y += 1
        u = rowBase + 16
    }
    startY = y
}

private func drawFooter(_ console: Console, sampleCodePoint: UInt32, y: inout Int) {
    y += 1
    // Example line: how to print a specific character with SwiftTerminalKit
    let hint = "Example: print U+\(String(format: "%04X", sampleCodePoint)) → " +
               "console.write(String(UnicodeScalar(0x\(String(format: "%04X", sampleCodePoint)))!), at: (x, y))"
	console.write(hint, at: (LEFT, y), fg: .named(.brightYellow), bg: .default)
    y += 1
}

// MARK: - Demo

do {
    let console = try Console()
    console.setTitle("SwiftTerminalKit – UTF-8/Unicode Table Demo")
    console.clear()

    var page = 0

    func renderPage() {
        console.clear()
        var y = 10
        let (range, title) = BLOCKS[page]
        drawHeader(console, title: title, range: range, page: page, total: BLOCKS.count, y: &y)
        drawGrid(console, range: range, startY: &y)

        // Pick a representative code point in the current block (start)
        drawFooter(console, sampleCodePoint: range.lowerBound, y: &y)
        console.present()
    }

    renderPage()

    var running = true
    while running {
        if let ev = console.pollEvent(timeoutMs: 250) {
            switch ev {
            case .key(let k, _):
                switch k {
                case .char("q"): running = false
                case .left:
                    page = (page - 1 + BLOCKS.count) % BLOCKS.count
                    renderPage()
                case .right:
                    page = (page + 1) % BLOCKS.count
                    renderPage()
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

