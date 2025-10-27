import Foundation

public struct Rect: Equatable {
    public var x: Int
    public var y: Int
    public var w: Int
    public var h: Int

    public init(_ x: Int, _ y: Int, _ w: Int, _ h: Int) {
        self.x = x
        self.y = y
        self.w = max(0, w)
        self.h = max(0, h)
    }

    public var isEmpty: Bool { w <= 0 || h <= 0 }

    public func contains(_ px: Int, _ py: Int) -> Bool {
        return px >= x && px < x + w && py >= y && py < y + h
    }

    public func intersects(_ other: Rect) -> Bool {
        return !(other.x >= x + w || other.x + other.w <= x || other.y >= y + h || other.y + other.h <= y)
    }

    public func intersection(_ b: Rect) -> Rect {
        let nx = max(x, b.x), ny = max(y, b.y)
        let rx = min(x + w, b.x + b.w), ry = min(y + h, b.y + b.h)
        return Rect(nx, ny, max(0, rx - nx), max(0, ry - ny))
    }

    public func translated(dx: Int, dy: Int) -> Rect {
        return Rect(x + dx, y + dy, w, h)
    }
}
