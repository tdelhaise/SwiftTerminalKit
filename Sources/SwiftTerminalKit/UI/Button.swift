
//
//  Button.swift
//  SwiftTerminalKit
//
//  Created by Thierry on 2024-07-11.
//

import Foundation

/// A clickable button view.
public class Button: View {
    private var label: Label
    public var action: (() -> Void)?

    /// Initializes a new button with the specified text and action.
    /// - Parameters:
    ///   - x: The x-coordinate of the button's origin.
    ///   - y: The y-coordinate of the button's origin.
    ///   - text: The text to display on the button.
    ///   - action: The action to perform when the button is clicked.
    public init(x: Int, y: Int, text: String, action: (() -> Void)? = nil) {
        self.label = Label(x: 1, y: 0, text: text)
        self.action = action
        super.init(frame: Rect(x, y, text.count + 2, 1))
        isFocusable = true
        addSubview(label)
    }

    public override func draw(into surface: Surface, clip: Rect) {
        let buttonText = "[ \(label.text) ]"
        if hasFocus {
            surface.putString(x: frame.x, y: frame.y, text: buttonText, fg: .named(.white), bg: .named(.blue))
        } else {
            surface.putString(x: frame.x, y: frame.y, text: buttonText, fg: .named(.black), bg: .gray(level: 12))
        }
    }

    public func trigger() {
        action?()
    }
}
