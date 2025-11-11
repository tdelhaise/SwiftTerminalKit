
//
//  Checkbox.swift
//  SwiftTerminalKit
//
//  Created by Thierry on 2024-07-11.
//

import Foundation

/// A checkbox view.
public class Checkbox: View {
    private var label: Label
    public var isChecked: Bool {
        didSet {
            if isChecked != oldValue {
                invalidate()
                onToggle?(isChecked)
            }
        }
    }
    
    public var onToggle: ((Bool) -> Void)?

    /// Initializes a new checkbox with the specified text and initial state.
    /// - Parameters:
    ///   - x: The x-coordinate of the checkbox's origin.
    ///   - y: The y-coordinate of the checkbox's origin.
    ///   - text: The text to display next to the checkbox.
    ///   - isChecked: The initial state of the checkbox.
    public init(x: Int, y: Int, text: String, isChecked: Bool = false) {
        self.label = Label(x: 4, y: 0, text: text)
        self.isChecked = isChecked
        super.init(frame: Rect(x, y, text.count + 4, 1))
        isFocusable = true
        addSubview(label)
    }

    public override func draw(into surface: Surface, clip: Rect) {
        let check = isChecked ? "[x]" : "[ ]"
        let text = "\(check) \(label.text)"

        if hasFocus {
            surface.putString(x: frame.x, y: frame.y, text: text, fg: .named(.white), bg: .named(.blue))
        } else {
            surface.putString(x: frame.x, y: frame.y, text: text, fg: .default, bg: .default)
        }
    }

    public func handle(event: KeyEvent) -> Bool {
        switch event.keyCode {
        case .char(" "), .enter:
            toggle()
            return true
        default:
            return false
        }
    }

    public func toggle() {
        isChecked.toggle()
    }
}
