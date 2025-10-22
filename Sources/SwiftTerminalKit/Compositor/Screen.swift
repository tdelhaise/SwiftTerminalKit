import Foundation

public final class Screen {
    private let console: Console
    private var surface: Surface
    private var views: [View] = []
    private var focused: View? = nil

    public init(console: Console) {
        self.console = console
        let s = console.size
        self.surface = Surface(width: s.cols, height: s.rows)
    }

    public var size: (cols: Int, rows: Int) { console.size }

    public func addView(_ v: View) { views.append(v); sortViews() }
    public func removeView(_ v: View) {
        if let i = views.firstIndex(where: { $0 === v }) { views.remove(at: i) }
        if focused === v { focused = nil }
    }

    public func setFocus(_ v: View?) {
        focused?.hasFocus = false
        focused = v
        focused?.hasFocus = true
        focused?.invalidate()
    }

    public func resizeToConsole() {
        let s = console.size
        surface.resize(s.cols, s.rows)
        invalidateAll()
    }
    public func invalidateAll() { for v in views { v.invalidate() } }

    public func render() {
        var damage = Region()
        for v in views {
            let rs = v.takeInvalidRegion()
            if !rs.isEmpty { damage.add(rs) }
        }
        if damage.isEmpty { return }
        damage.normalize()

        let ordered = views.sorted { $0.zIndex < $1.zIndex }
        for rect in damage.rects {
            for v in ordered {
                let clip = v.frame.intersection(rect)
                if !clip.isEmpty { v.draw(into: surface, clip: clip) }
            }
        }
        console.hideCursor(true)
        surface.present(to: console, only: damage.rects)
        console.hideCursor(false)
    }

    private func sortViews() { views.sort { $0.zIndex < $1.zIndex } }
}
