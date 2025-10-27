
//
//  InputLine.swift
//  SwiftTerminalKit
//
//  Created by Thierry on 2024-07-11.
//

import Foundation

/// A single-line text input view.
public class InputLine: View {
    public var text: String
    private var cursorPosition: Int

    /// Initializes a new input line with the specified initial text.
    /// - Parameters:
    ///   - x: The x-coordinate of the input line's origin.
    ///   - y: The y-coordinate of the input line's origin.
    ///   - width: The width of the input line.
    ///   - text: The initial text.
    public init(x: Int, y: Int, width: Int, text: String = "") {
        self.text = text
        self.cursorPosition = text.count
        super.init(frame: Rect(x, y, width, 1))
        isFocusable = true
    }

    public override func draw(into surface: Surface, clip: Rect) {
        let clippedText = String(text.prefix(frame.w))
        surface.putString(x: frame.x, y: frame.y, text: clippedText, fg: .named(.black), bg: .gray(level: 20))
        if hasFocus {
            // TODO: Show cursor
        }
    }

    public func handle(key: KeyCode) -> Bool {
        switch key {
        case .char(let char):
            text.insert(char, at: text.index(text.startIndex, offsetBy: cursorPosition))
            cursorPosition += 1
            invalidate()
            return true
        case .delete:
            if cursorPosition > 0 {
                cursorPosition -= 1
                text.remove(at: text.index(text.startIndex, offsetBy: cursorPosition))
                invalidate()
            }
            return true
        case .left:
            if cursorPosition > 0 {
                cursorPosition -= 1
                invalidate()
            }
            return true
        case .right:
            if cursorPosition < text.count {
                cursorPosition += 1
                invalidate()
            }
            return true
        default:
            return false
        }
    }
}
