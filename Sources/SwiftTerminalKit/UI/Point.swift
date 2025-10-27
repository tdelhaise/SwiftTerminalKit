
//
//  Point.swift
//  SwiftTerminalKit
//
//  Created by Thierry on 2024-07-11.
//

import Foundation

/// Represents a point in a 2D coordinate system.
public struct Point: Equatable {
    /// The x-coordinate of the point.
    public var x: Int
    /// The y-coordinate of the point.
    public var y: Int

    /// Initializes a new point with the specified coordinates.
    /// - Parameters:
    ///   - x: The x-coordinate.
    ///   - y: The y-coordinate.
    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    /// A point with both coordinates set to zero.
    public static var zero: Point {
        return Point(x: 0, y: 0)
    }
}
