import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import CShims

public struct Modifiers: OptionSet {
	public let rawValue: Int
	public init(rawValue: Int) { self.rawValue = rawValue }
	public static let shift = Modifiers(rawValue: 1 << 0)
	public static let ctrl  = Modifiers(rawValue: 1 << 1)
	public static let alt   = Modifiers(rawValue: 1 << 2)
	public static let meta  = Modifiers(rawValue: 1 << 3)
}

public enum Key: Equatable {
	case char(Character)
	case enter, backspace, tab, shiftTab, esc
	case up, down, left, right
	case home, end, pageUp, pageDown
	case insert, deleteKey
	case function(Int)
	case unknown
}

public enum MouseButton { case left, middle, right, wheelUp, wheelDown, none }
public enum MouseEventType { case down, up, move, drag, wheel }

public struct MouseEvent {
	public let x: Int
	public let y: Int
	public let button: MouseButton
	public let type: MouseEventType
	public let modifiers: Modifiers
	public init(x: Int, y: Int, button: MouseButton, type: MouseEventType, modifiers: Modifiers) {
		self.x = x; self.y = y; self.button = button; self.type = type; self.modifiers = modifiers
	}
}

public enum Event {
	case key(Key, Modifiers)
	case mouse(MouseEvent)
	case paste(String)
	case focusGained, focusLost
	case resize(cols: Int, rows: Int)
}

public protocol TerminalIO {
	func initRawMode() throws
	func restoreMode()
	func write(_ bytes: [UInt8])
	func read(into buffer: inout [UInt8], timeoutMs: Int) -> Int
	var size: (cols: Int, rows: Int) { get }
	func flush()
}

public final class Console {
	private let io: TerminalIO
	private var parser: VTParser
	public let caps: TerminalCaps
	private(set) public var size: (cols: Int, rows: Int)
	private let useTrueColor: Bool
	
	private var isShutdown = false
	private var altScreenActive = false
	private var mouseReportingActive = false
	private var bracketedPasteActive = false
	private var focusEventsActive = false
	private let capsDebugEnabled: Bool
	private let capsDebugLine: String?
	
	public init() throws {
#if os(Windows)
		self.capsDebugEnabled = false
		self.capsDebugLine = nil
		throw NSError(domain: "SwiftTerminalKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Windows not yet implemented"])
#else
		self.io = POSIXIO()
		try self.io.initRawMode()
		self.parser = VTParser()
		self.caps = TerminalCaps.detect()
		self.size = self.io.size
		self.useTrueColor = (caps.color == .truecolor)
		let env = ProcessInfo.processInfo.environment
		self.capsDebugEnabled = Console.shouldLogCaps(env: env)
		self.capsDebugLine = Console.buildCapsDebugLine(for: caps, env: env)
		enableDefaultModes()
#endif
	}
	
	deinit {
		shutdown()
	}
	
	private func enableDefaultModes() {
		if caps.supportsAltScreen {
			enterAltScreen()
			altScreenActive = true
		}
		hideCursor(true)
		if caps.supportsMouse {
			enableMouseSGR(true)
			mouseReportingActive = true
		}
		if caps.supportsBracketedPaste {
			enableBracketedPaste(true)
			bracketedPasteActive = true
		}
		if caps.supportsFocusEvents {
			enableFocusEvents(true)
			focusEventsActive = true
		}
		clear()
		present()
		if let line = capabilitySummary {
			statusHook?(line)
		}
	}
	
	public func shutdown() {
		guard !isShutdown else { return }
		if mouseReportingActive { enableMouseSGR(false) }
		if bracketedPasteActive { enableBracketedPaste(false) }
		if focusEventsActive { enableFocusEvents(false) }
		showCursor(true)
		if altScreenActive { leaveAltScreen() }
		io.restoreMode()
		isShutdown = true
	}
	
	// MARK: Output primitives
	
	public func enterAltScreen() {
		writeEsc("[?1049h")
		altScreenActive = true
	}
	
	public func leaveAltScreen() {
		writeEsc("[?1049l")
		altScreenActive = false
	}
	
	public func clear() {
		writeEsc("[2J"); writeEsc("[H")
	}
	
	public func moveTo(x: Int, y: Int) {
		writeEsc("[\(y);\(x)H")
	}
	
	public func hideCursor(_ hidden: Bool) {
		writeEsc(hidden ? "[?25l" : "[?25h")
	}
	
	public func showCursor(_ shown: Bool) {
		hideCursor(!shown)
	}
	
	// MARK: Legacy low-level color API (kept but deprecated)
	public enum Color {
		case index(Int)         // 0..255
		case rgb(UInt8, UInt8, UInt8)
		case defaultColor
	}
	
	@available(*, deprecated, message: "Use the PaletteColor overload of write(_:at:fg:bg:) instead.")
	public func setColor(fg: Color?, bg: Color?) {
		var parts: [String] = []
		if let fg = fg {
			switch fg {
				case .index(let n): parts += ["38","5","\(n)"]
				case .rgb(let r, let g, let b):
					if useTrueColor {
						parts += ["38","2","\(r)","\(g)","\(b)"]
					} else {
						parts += ["38","5","\(rgbToXtermIndex(r, g, b))"]
					}
				case .defaultColor: parts += ["39"]
			}
		}
		if let bg = bg {
			switch bg {
				case .index(let n): parts += ["48","5","\(n)"]
				case .rgb(let r, let g, let b):
					if useTrueColor {
						parts += ["48","2","\(r)","\(g)","\(b)"]
					} else {
						parts += ["48","5","\(rgbToXtermIndex(r, g, b))"]
					}
				case .defaultColor: parts += ["49"]
			}
		}
		if !parts.isEmpty { writeEsc("[" + parts.joined(separator: ";") + "m") }
	}
	
	// MARK: Preferred color API (unambiguous)
	
	public enum NamedColor: CaseIterable {
		case black, red, green, yellow, blue, magenta, cyan, white
		case brightBlack, brightRed, brightGreen, brightYellow, brightBlue, brightMagenta, brightCyan, brightWhite
		
		var index: Int {
			switch self {
				case .black: return 0
				case .red: return 1
				case .green: return 2
				case .yellow: return 3
				case .blue: return 4
				case .magenta: return 5
				case .cyan: return 6
				case .white: return 7
				case .brightBlack: return 8
				case .brightRed: return 9
				case .brightGreen: return 10
				case .brightYellow: return 11
				case .brightBlue: return 12
				case .brightMagenta: return 13
				case .brightCyan: return 14
				case .brightWhite: return 15
			}
		}
	}
	
	public enum PaletteColor {
		case named(NamedColor)
		case gray(level: Int) // 0..23 -> 232..255
		case index(Int)       // 0..255
		case rgb(UInt8, UInt8, UInt8)
		case `default`
	}
	
	private func sgrParts(for color: PaletteColor, isForeground: Bool) -> [String] {
		let base = isForeground ? "38" : "48"
		switch color {
			case .default:
				return [isForeground ? "39" : "49"]
			case .named(let n):
				return [base, "5", "\(n.index)"]
			case .gray(let level):
				let lvl = max(0, min(23, level))
				return [base, "5", "\(232 + lvl)"]
			case .index(let n):
				let idx = max(0, min(255, n))
				return [base, "5", "\(idx)"]
			case .rgb(let r, let g, let b):
				if useTrueColor {
					return [base, "2", "\(r)", "\(g)", "\(b)"]
				} else {
					return [base, "5", "\(rgbToXtermIndex(r, g, b))"]
				}
		}
	}
	
	public func setColor(fg: PaletteColor?, bg: PaletteColor?) {
		var parts: [String] = []
		if let fg = fg {
			parts += sgrParts(for: fg, isForeground: true)
		}
		if let bg = bg {
			parts += sgrParts(for: bg, isForeground: false)
		}
		if !parts.isEmpty {
			writeEsc("[" + parts.joined(separator: ";") + "m")
		}
	}
	
	public func write(_ s: String) {
		io.write(Array(s.utf8))
	}
	
	@available(*, deprecated, message: "Use the PaletteColor overload of write(_:at:fg:bg:) instead.")
	public func write(_ s: String, at pos: (x:Int, y:Int), fg: Color? = nil, bg: Color? = nil) {
		moveTo(x: pos.x, y: pos.y);
		setColor(fg: fg, bg: bg);
		write(s);
		setColor(fg: .defaultColor, bg: .defaultColor)
	}
	
	public func write(_ s: String, at pos: (x:Int, y:Int), fg: PaletteColor?, bg: PaletteColor?) {
		moveTo(x: pos.x, y: pos.y);
		setColor(fg: fg, bg: bg);
		write(s);
		setColor(fg: .default, bg: .default)
	}
	
	public func present() {
		io.flush()
	}
	
	public func setTitle(_ title: String) {
		io.write([0x1b, 0x5d] + Array("0;\(title)".utf8) + [0x1b, 0x5c])
	}
	
	public func enableMouseSGR(_ on: Bool) {
		writeEsc(on ? "[?1002h" : "[?1002l"); writeEsc(on ? "[?1006h" : "[?1006l")
		mouseReportingActive = on
	}
	
	public func enableBracketedPaste(_ on: Bool) {
		writeEsc(on ? "[?2004h" : "[?2004l")
		bracketedPasteActive = on
	}
	
	public func enableFocusEvents(_ on: Bool) {
		writeEsc(on ? "[?1004h" : "[?1004l")
		focusEventsActive = on
	}
	
	// Hook used by demos to consume startup messages instead of stderr.
	public var statusHook: ((String) -> Void)?
	
	public var capabilitySummary: String? {
		guard capsDebugEnabled, let line = capsDebugLine else { return nil }
		return line
	}
	
	private func writeEsc(_ s: String) {
		io.write([0x1b] + Array(s.utf8))
	}
	
	// MARK: Truecolor detection + RGB→256 fallback
	
	private func rgbToXtermIndex(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> Int {
		@inline(__always) func to6(_ v: UInt8) -> Int {
			let steps: [Int] = [0, 95, 135, 175, 215, 255]
			var best = 0, bestd = Int.max
			for (i, s) in steps.enumerated() {
				let d = abs(Int(v) - s)
				if d < bestd { bestd = d; best = i }
			}
			return best
		}
		let rr = to6(r), gg = to6(g), bb = to6(b)
		let cubeIdx = 16 + 36*rr + 6*gg + bb
		
		let grayLevel = Int((Int(r) + Int(g) + Int(b)) / 3)
		let grayIdx = 232 + max(0, min(23, (grayLevel - 8) / 10))
		let steps: [Int] = [0, 95, 135, 175, 215, 255]
		let cubeRGB = (steps[rr], steps[gg], steps[bb])
		let grayVal = max(8, min(238, 8 + 10 * (grayIdx - 232)))
		let cubeDist = abs(Int(r) - cubeRGB.0) + abs(Int(g) - cubeRGB.1) + abs(Int(b) - cubeRGB.2)
		let grayDist = abs(Int(r) - grayVal) + abs(Int(g) - grayVal) + abs(Int(b) - grayVal)
		return (grayDist < cubeDist) ? grayIdx : cubeIdx
	}
	
	// MARK: Events
	
	public func pollEvent(timeoutMs: Int = -1) -> Event? {
		let newSize = io.size
		if newSize.cols != size.cols || newSize.rows != size.rows {
			size = newSize
			return .resize(cols: newSize.cols, rows: newSize.rows)
		}
		
		// Check if parser has already-parsed events before blocking on I/O
		if let event = parser.nextEvent() {
			return event
		}
		
		var buf = [UInt8](repeating: 0, count: 4096)
		let n = io.read(into: &buf, timeoutMs: timeoutMs)
		if n <= 0 {
			return nil
		}
		parser.feed(buf[0..<n])
		return parser.nextEvent()
	}
}



private extension Console {
    static func shouldLogCaps(env: [String: String]) -> Bool {
        guard let raw = env["SWIFTERMINALKIT_DEBUG_CAPS"] else { return false }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value == "1" || value == "true" || value == "yes" || value == "on"
    }

    static func buildCapsDebugLine(for caps: TerminalCaps, env: [String: String]) -> String? {
        var parts: [String] = []
        parts.append("color=" + caps.color.rawValue)
        parts.append("altScreen=" + String(caps.supportsAltScreen))
        parts.append("mouse=" + String(caps.supportsMouse))
        parts.append("bracketedPaste=" + String(caps.supportsBracketedPaste))
        parts.append("focusEvents=" + String(caps.supportsFocusEvents))
        let base = parts.joined(separator: " ")

        var envParts: [String] = []
        if let term = env["TERM"], !term.isEmpty { envParts.append("TERM=" + term) }
        if let termProgram = env["TERM_PROGRAM"], !termProgram.isEmpty { envParts.append("TERM_PROGRAM=" + termProgram) }
        if let colorterm = env["COLORTERM"], !colorterm.isEmpty { envParts.append("COLORTERM=" + colorterm) }
        let envSummary = envParts.joined(separator: " ")

        if envSummary.isEmpty {
            return "[SwiftTerminalKit] caps " + base
        } else {
            return "[SwiftTerminalKit] caps " + base + " (" + envSummary + ")"
        }
    }
}

// MARK: - Extensions at file scope

// Legacy Color factories renamed to avoid ambiguity with PaletteColor .named/.gray
public extension Console.Color {
	/// Prefer Console.PaletteColor.named(...) in new code.
	static func named256(_ n: Console.NamedColor) -> Console.Color { .index(n.index) }
	/// Prefer Console.PaletteColor.gray(level:) in new code.
	static func gray256(level: Int) -> Console.Color {
		let lvl = max(0, min(23, level))
		return .index(232 + lvl)
	}
}

// Hex helper for the new PaletteColor API
public extension Console.PaletteColor {
	static func hex(_ s: String) -> Console.PaletteColor {
		func hexVal(_ ch: Character) -> Int? {
			switch ch {
				case "0"..."9":
					return Int(ch.asciiValue! - Character("0").asciiValue!)
				case "a"..."f":
					return 10 + Int(ch.asciiValue! - Character("a").asciiValue!)
				case "A"..."F":
					return 10 + Int(ch.asciiValue! - Character("A").asciiValue!)
				default:
					return nil
			}
		}
		func parse2(_ hi: Character, _ lo: Character) -> UInt8? {
			guard let h = hexVal(hi), let l = hexVal(lo) else { return nil }
			return UInt8(h*16 + l)
		}
		var str = s.trimmingCharacters(in: .whitespacesAndNewlines)
		if str.hasPrefix("#") { str = String(str.dropFirst()) }
		if str.lowercased().hasPrefix("0x") { str = String(str.dropFirst(2)) }
		if str.count == 6 {
			let a = Array(str)
			guard let r = parse2(a[0], a[1]), let g = parse2(a[2], a[3]), let b = parse2(a[4], a[5]) else {
				return .default
			}
			return .rgb(r, g, b)
		} else if str.count == 3 {
			let a = Array(str)
			guard let rH = hexVal(a[0]), let gH = hexVal(a[1]), let bH = hexVal(a[2]) else {
				return .default
			}
			return .rgb(UInt8(rH*17), UInt8(gH*17), UInt8(bH*17))
		} else {
			return .default
		}
	}
}
