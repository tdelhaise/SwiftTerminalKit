import Foundation
import Darwin
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
    case enter, backspace, tab, esc
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
    private(set) public var size: (cols: Int, rows: Int)

    public init() throws {
        #if os(Windows)
        throw NSError(domain: "SwiftTerminalKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Windows not yet implemented"])
        #else
        self.io = POSIXIO()
        try self.io.initRawMode()
        self.parser = VTParser()
        self.size = self.io.size
        enableDefaultModes()
        #endif
    }

    deinit {
        leaveAltScreen()
        io.restoreMode()
        showCursor(true)
        enableMouseSGR(false)
        enableBracketedPaste(false)
        enableFocusEvents(false)
    }

    private func enableDefaultModes() {
        enterAltScreen()
        hideCursor(true)
        enableMouseSGR(true)
        enableBracketedPaste(true)
        enableFocusEvents(true)
        clear()
        present()
    }

    // MARK: Output primitives

    public func enterAltScreen() { writeEsc("[?1049h") }
    public func leaveAltScreen() { writeEsc("[?1049l") }
    public func clear() { writeEsc("[2J"); writeEsc("[H") }
    public func moveTo(x: Int, y: Int) { writeEsc("[\(y);\(x)H") }
    public func hideCursor(_ hidden: Bool) { writeEsc(hidden ? "[?25l" : "[?25h") }
    public func showCursor(_ shown: Bool) { hideCursor(!shown) }

    // Legacy low-level color API
    public enum Color {
        case index(Int)         // 0..255
        case rgb(UInt8, UInt8, UInt8)
        case defaultColor
    }

    public func setColor(fg: Color?, bg: Color?) {
        var parts: [String] = []
        if let fg = fg {
            switch fg {
            case .index(let n): parts += ["38","5","\(n)"]
            case .rgb(let r, let g, let b): parts += ["38","2","\(r)","\(g)","\(b)"]
            case .defaultColor: parts += ["39"]
            }
        }
        if let bg = bg {
            switch bg {
            case .index(let n): parts += ["48","5","\(n)"]
            case .rgb(let r, let g, let b): parts += ["48","2","\(r)","\(g)","\(b)"]
            case .defaultColor: parts += ["49"]
            }
        }
        if !parts.isEmpty { writeEsc("[" + parts.joined(separator: ";") + "m") }
    }

    // MARK: - Palette (named + grayscale)

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
            return [base, "2", "\(r)", "\(g)", "\(b)"]
        }
    }

    public func setColor(fg: PaletteColor?, bg: PaletteColor?) {
        var parts: [String] = []
        if let fg = fg { parts += sgrParts(for: fg, isForeground: true) }
        if let bg = bg { parts += sgrParts(for: bg, isForeground: false) }
        if !parts.isEmpty { writeEsc("[" + parts.joined(separator: ";") + "m") }
    }

    public func write(_ s: String) { io.write(Array(s.utf8)) }
    public func write(_ s: String, at pos: (x:Int, y:Int), fg: Color? = nil, bg: Color? = nil) {
        moveTo(x: pos.x, y: pos.y); setColor(fg: fg, bg: bg); write(s); setColor(fg: .defaultColor, bg: .defaultColor)
    }
    public func write(_ s: String, at pos: (x:Int, y:Int), fg: PaletteColor?, bg: PaletteColor?) {
        moveTo(x: pos.x, y: pos.y); setColor(fg: fg, bg: bg); write(s); setColor(fg: .default, bg: .default)
    }
    public func present() { io.flush() }
    public func setTitle(_ title: String) {
        io.write([0x1b, 0x5d] + Array("0;\(title)".utf8) + [0x1b, 0x5c])
    }
    public func enableMouseSGR(_ on: Bool) { writeEsc(on ? "[?1002h" : "[?1002l"); writeEsc(on ? "[?1006h" : "[?1006l") }
    public func enableBracketedPaste(_ on: Bool) { writeEsc(on ? "[?2004h" : "[?2004l") }
    public func enableFocusEvents(_ on: Bool) { writeEsc(on ? "[?1004h" : "[?1004l") }

    private func writeEsc(_ s: String) { io.write([0x1b] + Array(s.utf8)) }

    // MARK: Events

    public func pollEvent(timeoutMs: Int = -1) -> Event? {
        let newSize = io.size
        if newSize.cols != size.cols || newSize.rows != size.rows {
            size = newSize
            return .resize(cols: newSize.cols, rows: newSize.rows)
        }
        var buf = [UInt8](repeating: 0, count: 4096)
        let n = io.read(into: &buf, timeoutMs: timeoutMs)
        if n <= 0 { return nil }
        parser.feed(buf[0..<n])
        return parser.nextEvent()
    }
}
