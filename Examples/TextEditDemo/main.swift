import SwiftTerminalKit
import Foundation

final class EditorView: View {
    private var lines: [[Character]] = [[]]
    public var cx = 0, cy = 0
    private let theme: TVEditTheme
    private let windowTitle = " SwiftTerminalKit TextEdit "
    private let statusHint = " Ctrl+S Save  Ctrl+Q Quit "

    init(frame: Rect, zIndex: Int = 0, theme: TVEditTheme) {
        self.theme = theme
        super.init(frame: frame, zIndex: zIndex)
        fg = theme.editorForeground
        bg = theme.editorBackground
    }

    public override func draw(into surface: Surface, clip: Rect) {
        let r = frame
        surface.fill(clip, cell: .init(" ", fg: theme.editorForeground, bg: theme.editorBackground))
        drawBorder(into: surface, clip: clip)

        let textHeight = max(0, r.h - 3)
        let displayCount = min(lines.count, textHeight)
        for row in 0..<displayCount {
            let y = r.y + 1 + row
            if y < clip.y || y >= clip.y + clip.h { continue }
            let line = String(lines[row])
            let visible = String(line.prefix(max(0, r.w - 2)))
            surface.putString(x: r.x + 1, y: y, text: visible, fg: theme.editorForeground, bg: theme.editorBackground)
        }

        if r.h >= 3 {
            let infoY = r.y + r.h - 2
            if infoY >= clip.y && infoY < clip.y + clip.h {
                let available = max(0, r.w - 2)
                if available > 0 {
                    var hint = statusHint
                    if hint.count > available {
                        hint = String(hint.prefix(available))
                    } else if hint.count < available {
                        hint = hint.padding(toLength: available, withPad: " ", startingAt: 0)
                    }
                    surface.putString(x: r.x + 1, y: infoY, text: hint, fg: theme.editorForeground, bg: theme.editorBackground)
                }
            }
        }
    }

    private func drawBorder(into surface: Surface, clip: Rect) {
        let r = frame
        guard r.w >= 2, r.h >= 2 else { return }

        let topRect = Rect(r.x, r.y, r.w, 1)
        if !clip.intersection(topRect).isEmpty {
            let topLine = "+" + String(repeating: "-", count: max(0, r.w - 2)) + "+"
            surface.putString(x: r.x, y: r.y, text: topLine, fg: theme.editorBorder, bg: theme.editorBackground)

            if r.w > 4 {
                let title = windowTitle.count > r.w - 2 ? String(windowTitle.prefix(r.w - 2)) : windowTitle
                let start = r.x + max(1, (r.w - title.count) / 2)
                surface.putString(x: start, y: r.y, text: title, fg: theme.editorBorder, bg: theme.editorBackground)
            }
        }

        let bottomRect = Rect(r.x, r.y + r.h - 1, r.w, 1)
        if !clip.intersection(bottomRect).isEmpty {
            let bottomLine = "+" + String(repeating: "-", count: max(0, r.w - 2)) + "+"
            surface.putString(x: r.x, y: r.y + r.h - 1, text: bottomLine, fg: theme.editorBorder, bg: theme.editorBackground)
        }

        if r.h > 2 {
            let leftRect = Rect(r.x, r.y + 1, 1, r.h - 2)
            if clip.intersects(leftRect) {
                for y in max(r.y + 1, clip.y)..<min(r.y + r.h - 1, clip.y + clip.h) {
                    surface.putString(x: r.x, y: y, text: "|", fg: theme.editorBorder, bg: theme.editorBackground)
                }
            }
            let rightRect = Rect(r.x + r.w - 1, r.y + 1, 1, r.h - 2)
            if clip.intersects(rightRect) {
                for y in max(r.y + 1, clip.y)..<min(r.y + r.h - 1, clip.y + clip.h) {
                    surface.putString(x: r.x + r.w - 1, y: y, text: "|", fg: theme.editorBorder, bg: theme.editorBackground)
                }
            }
        }
    }

    func insert(_ c: Character) {
        ensureRow(cy)
        lines[cy].insert(c, at: cx)
        cx += 1
        invalidate(frame)
    }

    func backspace() {
        ensureRow(cy)
        if cx > 0 {
            lines[cy].remove(at: cx - 1)
            cx -= 1
        } else if cy > 0 {
            let tail = lines[cy]
            cy -= 1
            cx = lines[cy].count
            lines[cy].append(contentsOf: tail)
            lines.remove(at: cy + 1)
        }
        invalidate(frame)
    }

    func newline() {
        ensureRow(cy)
        let tail = Array(lines[cy].dropFirst(cx))
        lines[cy] = Array(lines[cy].prefix(cx))
        cy += 1
        cx = 0
        lines.insert(tail, at: cy)
        invalidate(frame)
    }

    func moveLeft() {
        if cx > 0 {
            cx -= 1
        } else if cy > 0 {
            cy -= 1
            cx = lines[cy].count
        }
        invalidate(frame)
    }

    func moveRight() {
        ensureRow(cy)
        if cx < lines[cy].count {
            cx += 1
        } else if cy + 1 < lines.count {
            cy += 1
            cx = 0
        }
        invalidate(frame)
    }

    func moveUp() {
        if cy > 0 {
            cy -= 1
            cx = min(cx, lines[cy].count)
        }
        invalidate(frame)
    }

    func moveDown() {
        if cy + 1 < lines.count {
            cy += 1
            cx = min(cx, lines[cy].count)
        }
        invalidate(frame)
    }

    func save(to path: String) throws {
        let text = lines.map { String($0) }.joined(separator: "\n")
        try text.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
    }

    private func ensureRow(_ y: Int) {
        while y >= lines.count { lines.append([]) }
    }

    public func handle(event: KeyEvent) -> Bool {
        let mods = event.mods
        switch event.keyCode {
        case .char(let ch):
            if mods.contains(.ctrl) || mods.contains(.meta) { return false }
            if ch == "\n" || ch == "\r" { newline(); return true }
            if ch == "\u{8}" || ch == "\u{7F}" { backspace(); return true }
            if ch.isNewline { newline(); return true }
            if ch >= " " { insert(ch) }
            return true
        case .left:
            moveLeft(); return true
        case .right:
            moveRight(); return true
        case .up:
            moveUp(); return true
        case .down:
            moveDown(); return true
        case .home:
            cx = 0
            invalidate(frame)
            return true
        case .end:
            ensureRow(cy)
            cx = lines[cy].count
            invalidate(frame)
            return true
        case .pageUp:
            cy = max(0, cy - max(1, frame.h - 3))
            ensureRow(cy)
            cx = min(cx, lines[cy].count)
            invalidate(frame)
            return true
        case .pageDown:
            cy = min(lines.count - 1, cy + max(1, frame.h - 3))
            ensureRow(cy)
            cx = min(cx, lines[cy].count)
            invalidate(frame)
            return true
        case .insert, .delete:
            return false
        case .backspace:
            backspace(); return true
        case .tab:
            if mods.contains(.shift) { return false }
            insert("\t"); return true
        case .enter:
            newline(); return true
        default:
            return false
        }
    }
}


do {
    let console = try Console()
    defer { console.shutdown() }
    console.clear()
    console.setTitle("SwiftTerminalKit - TextEdit Demo")

    let screen = Screen(console: console)

    let app = TextEditApp(console: console, screen: screen)
    console.statusHook = { message in
        app.statusLine.updateMessage(message)
    }

    let loop = STKRunLoop(console: console, screen: screen)

    _ = loop.runSync { ev in
        _ = app.handleEvent(ev) // Pass event to the app
        return !app.quit // Continue loop unless app signals to quit
    }
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}
