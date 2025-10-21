import SwiftTerminalKit
import Foundation

// MARK: - Config (ASCII-only to avoid encoding gotchas)

/// Unicode blocks to showcase (TUI-friendly glyphs).
private let BLOCKS: [(ClosedRange<UInt32>, String)] = [
	(0x0000...0x007F, "Basic Latin (ASCII 0x00..0x7F)"),
	(0x0080...0x00FF, "Latin-1 Supplement (0x80..0xFF)"),
	(0x2190...0x21FF, "Arrows (0x2190..0x21FF)"),
	(0x2500...0x257F, "Box Drawing (0x2500..0x257F)"),
	(0x2580...0x259F, "Block Elements (0x2580..0x259F)"),
	(0x25A0...0x25FF, "Geometric Shapes (0x25A0..0x25FF)"),
	(0x2600...0x26FF, "Misc Symbols (0x2600..0x26FF)"),
	(0x2800...0x28FF, "Braille Patterns (0x2800..0x28FF)"),
]

// Layout constants
private let LEFT = 2        // left margin
private let TOP  = 2        // header starts at this row
private let LABEL_W = 7     // "U+0000 " is 6 + 1 space
private let CELL_W  = 2     // 2 columns per glyph cell (glyph + spacer)

// MARK: - Utilities

private func hexNibble(_ v: Int) -> String {
	let s = "0123456789ABCDEF"
	return String(s[s.index(s.startIndex, offsetBy: v & 0xF)])
}

private func isRenderable(_ scalar: UnicodeScalar) -> Bool {
	if CharacterSet.controlCharacters.contains(scalar) { return false }
	if CharacterSet.whitespacesAndNewlines.contains(scalar) && scalar != " " { return false }
	if scalar.properties.canonicalCombiningClass != .notReordered { return false }
	return true
}

private func renderGlyph(_ u: UInt32) -> String {
	if let scalar = UnicodeScalar(u) {
		if isRenderable(scalar) { return String(Character(scalar)) }
		// Middle dot placeholder (escaped to keep file ASCII)
		return "\u{00B7}"
	}
	return " "
}

// MARK: - Drawing helpers

private func drawHeader(
	_ c: Console,
	title: String,
	pageInfo: String,
	colsShown: Int,
	startX: Int,
	y: inout Int
) {
	c.write(title, at: (LEFT, y), fg: .named(.brightGreen), bg: .default)
	c.write(pageInfo, at: (LEFT + title.count + 1, y), fg: .named(.brightBlack), bg: .default)
	y += 1
	
	// Column header 0..F (or truncated)
	c.write(String(repeating: " ", count: LABEL_W), at: (LEFT, y), fg: .named(.brightBlack), bg: .default)
	for x in 0..<colsShown {
		c.write(hexNibble(x), at: (startX + x * CELL_W, y), fg: .named(.brightBlack), bg: .default)
	}
	y += 1
}

private func drawGrid(
	_ c: Console,
	range: ClosedRange<UInt32>,
	rowOffset: Int,
	rowsShown: Int,
	colsShown: Int,
	startX: Int,
	startY: inout Int
) {
	var y = startY
	
	let totalCodes = Int(range.count)
	let totalRows = (totalCodes + 16 - 1) / 16
	
	for r in 0..<rowsShown {
		let logicalRow = rowOffset + r
		if logicalRow >= totalRows { break }
		
		let rowBase = Int(range.lowerBound) + logicalRow * 16
		let rowLabel = String(format: "U+%04X", rowBase) + " "
		c.write(rowLabel, at: (LEFT, y), fg: .named(.brightBlack), bg: .default)
		
		for x in 0..<colsShown {
			let code = rowBase + x
			if code <= Int(range.upperBound) {
				let g = renderGlyph(UInt32(code))
				// write glyph + space to occupy CELL_W = 2
				c.write(g + " ", at: (startX + x * CELL_W, y), fg: .default, bg: .default)
			} else {
				c.write("  ", at: (startX + x * CELL_W, y), fg: .default, bg: .default)
			}
		}
		y += 1
	}
	
	startY = y
}

private func drawFooter(
	_ c: Console,
	range: ClosedRange<UInt32>,
	rowOffset: Int,
	rowsShown: Int,
	y: inout Int
) {
	y += 1
	let totalCodes = Int(range.count)
	let totalRows = (totalCodes + 16 - 1) / 16
	let info = "Arrows: left/right block, up/down scroll rows   [rows \(rowOffset+1)..\(min(totalRows, rowOffset+rowsShown)) of \(totalRows)]   q to quit"
	c.write(info, at: (LEFT, y), fg: .named(.brightBlack), bg: .default)
	y += 1
	
	let sample = range.lowerBound
	let hint = "Example: console.write(String(UnicodeScalar(0x\(String(format: "%04X", sample)))!), at: (x, y))"
	c.write(hint, at: (LEFT, y), fg: .named(.brightYellow), bg: .default)
	y += 1
}

// MARK: - Demo

do {
	let console = try Console()
	console.setTitle("SwiftTerminalKit - UTF-8/Unicode Table Demo")
	console.clear()

	var blockIdx = 0           // which Unicode block
	var rowOffset = 0          // which grid row inside block (for vertical paging)

	func render() {
		console.clear()

		let (range, title) = BLOCKS[blockIdx]
		let size = console.size

		// Column layout fits the terminal:
		let startX = LEFT + LABEL_W
		let availableWidth = max(0, size.cols - startX)
		let colsShown = max(1, min(16, availableWidth / CELL_W))

		// Height layout:
		// lines used: TOP + header(2) + spacer(1) + footer(2) = TOP + 5
		let reserved = TOP + 5
		let availableHeight = max(1, size.rows - reserved)
		let rowsShown = availableHeight

		// Total rows in this block (groups of 16 code points)
		let totalCodes = Int(range.count)
		let totalRows = (totalCodes + 16 - 1) / 16

		// Clamp rowOffset
		if totalRows <= rowsShown {
			rowOffset = 0
		} else {
			rowOffset = max(0, min(rowOffset, totalRows - rowsShown))
		}

		var y = TOP
		let pageInfo = "  [\(blockIdx+1)/\(BLOCKS.count)]  <- / -> switch  q quit"
		drawHeader(console, title: title, pageInfo: pageInfo, colsShown: colsShown, startX: startX, y: &y)
		drawGrid(console, range: range, rowOffset: rowOffset, rowsShown: rowsShown, colsShown: colsShown, startX: startX, startY: &y)
		drawFooter(console, range: range, rowOffset: rowOffset, rowsShown: rowsShown, y: &y)

		console.present()
	}

	render()

	var running = true
	while running {
		if let ev = console.pollEvent(timeoutMs: 200) {
			switch ev {
			case .key(let k, _):
				switch k {
				case .char("q"):
					running = false
				case .left:
					blockIdx = (blockIdx - 1 + BLOCKS.count) % BLOCKS.count
					rowOffset = 0
					render()
				case .right:
					blockIdx = (blockIdx + 1) % BLOCKS.count
					rowOffset = 0
					render()
				case .up:
					rowOffset = max(0, rowOffset - 1)
					render()
				case .down:
					rowOffset += 1
					render()
				default:
					break
				}
			default:
				break
			}
		}
	}
} catch {
	fputs("Error: \(error)\n", stderr)
	exit(1)
}
