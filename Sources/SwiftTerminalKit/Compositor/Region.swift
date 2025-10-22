import Foundation

public struct Region {
    public private(set) var rects: [Rect] = []

    public init() {}

    public mutating func add(_ r: Rect) {
        guard !r.isEmpty else { return }
        rects.append(r)
        if rects.count > 48 { normalize() }
    }

    public mutating func add(_ rs: [Rect]) { for r in rs { add(r) } }

    public mutating func clear() { rects.removeAll(keepingCapacity: false) }

    public var isEmpty: Bool { rects.isEmpty }

    public mutating func normalize() {
        var out: [Rect] = []
        for r in rects {
            var merged = false
            for i in out.indices {
                let a = out[i]
                if a.y == r.y && a.h == r.h && (a.x + a.w == r.x || r.x + r.w == a.x) {
                    out[i] = Rect(min(a.x, r.x), a.y, a.w + r.w, a.h)
                    merged = true; break
                }
                if a.x == r.x && a.w == r.w && (a.y + a.h == r.y || r.y + r.h == a.y) {
                    out[i] = Rect(a.x, min(a.y, r.y), a.w, a.h + r.h)
                    merged = true; break
                }
            }
            if !merged { out.append(r) }
        }
        rects = out
    }
}
