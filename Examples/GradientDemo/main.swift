import SwiftTerminalKit
import Foundation

do {
	let c = try Console()
	c.setTitle("SwiftTerminalKit – GradientDemo")
	c.clear()
	
	let cols = c.size.cols
	let rows = c.size.rows
	
	let left = 2
	let top  = 2
	let w = max(60, cols - 4)
	let h = min(20, max(6, rows - 6))
	
	c.write("Smooth gradient rectangle (TrueColor with automatic 256-color fallback)",
			at: (left, top - 1), fg: .named(.brightGreen), bg: .default)
	
	for y in 0..<h {
		for x in 0..<w {
			let tx = Double(x) / Double(max(1, w - 1))
			let ty = Double(y) / Double(max(1, h - 1))
			
			let r = UInt8((255.0 * (0.2 + 0.8 * tx) * (0.6 + 0.4 * sin((tx + ty) * Double.pi))).clamped0to255)
			let g = UInt8((255.0 * (0.2 + 0.8 * ty) * (0.6 + 0.4 * sin((tx - ty) * Double.pi))).clamped0to255)
			let b = UInt8((255.0 * (0.8 - 0.6 * tx) * (0.6 + 0.4 * sin((tx * 2.0) * Double.pi))).clamped0to255)
			
			c.setColor(fg: .default, bg: .rgb(r, g, b))
			c.moveTo(x: left + x, y: top + y)
			c.write(" ")
		}
	}
	
	// reset
	c.setColor(fg: .default, bg: .default)
	
	c.write("Press 'q' to quit.", at: (left, top + h + 1), fg: .named(.brightYellow), bg: .default)
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

private extension Double {
	var clamped0to255: Double { min(255.0, max(0.0, self)) }
}
