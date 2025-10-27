
//
//  Label.swift
//  SwiftTerminalKit
//
//  Created by Thierry on 2024-07-11.
//

import Foundation

/// A view that displays a string.
public class Label: View {
    public var text: String

    /// Initializes a new label with the specified text at a given position.
    /// - Parameters:
    ///   - x: The x-coordinate of the label's origin.
    ///   - y: The y-coordinate of the label's origin.
    ///   - text: The text to display.
    public init(x: Int, y: Int, text: String) {
        self.text = text
        super.init(frame: Rect(x, y, text.count, 1))
    }

    public override func draw(into surface: Surface, clip: Rect) {
        // For simplicity, we are not clipping the text for now
		surface.putString(x: frame.x, y: frame.y, text: text, fg: foregroundColor, bg: backgroundColor)
    }
}
