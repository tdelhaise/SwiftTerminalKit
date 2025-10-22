import Foundation

public final class Panel: View {
    public let title: String

    public init(frame: Rect, zIndex: Int, title: String, color: Console.NamedColor) {
        self.title = title
        super.init(frame: frame, zIndex: zIndex)
        self.bg = .gray(level: 2)
        self.fg = .named(color)
        self.isFocusable = true
    }

    public override func draw(into s: Surface, clip: Rect) {
        s.fill(clip, cell: .init(" ", fg: fg, bg: bg))

        let r = self.frame
        func hline(y: Int, x0: Int, x1: Int) {
            let y = max(r.y, min(r.y + r.h - 1, y))
            let x0 = max(r.x, x0), x1 = min(r.x + r.w - 1, x1)
            if x0 <= x1 {
                s.putString(x: x0, y: y, text: String(repeating: "-", count: x1 - x0 + 1), fg: fg, bg: bg)
            }
        }
        func vline(x: Int, y0: Int, y1: Int) {
            let x = max(r.x, min(r.x + r.w - 1, x))
            let y0 = max(r.y, y0), y1 = min(r.y + r.h - 1, y1)
            for y in y0...y1 { s.put(x, y, .init("|", fg: fg, bg: bg)) }
        }

        if clip.intersects(Rect(r.x, r.y, r.w, 1)) { hline(y: r.y, x0: r.x, x1: r.x + r.w - 1) }
        if clip.intersects(Rect(r.x, r.y + r.h - 1, r.w, 1)) { hline(y: r.y + r.h - 1, x0: r.x, x1: r.x + r.w - 1) }
        if clip.intersects(Rect(r.x, r.y, 1, r.h)) { vline(x: r.x, y0: r.y, y1: r.y + r.h - 1) }
        if clip.intersects(Rect(r.x + r.w - 1, r.y, 1, r.h)) { vline(x: r.x + r.w - 1, y0: r.y, y1: r.y + r.h - 1) }

        if r.contains(r.x + 2, r.y) && clip.intersects(Rect(r.x + 2, r.y, max(0, title.count + 4), 1)) {
            let mark = hasFocus ? "[*] " : "[ ] "
            s.putString(x: r.x + 2, y: r.y, text: mark + title, fg: fg, bg: bg)
        }
    }
}
