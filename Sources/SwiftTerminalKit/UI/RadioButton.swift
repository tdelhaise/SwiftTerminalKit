
//
//  RadioButton.swift
//  SwiftTerminalKit
//
//  Created by Thierry on 2025-11-11.
//

import Foundation

/// A radio button control with a label and group identification.
public class RadioButton: View {
    public var groupId: Int
    public var isSelected: Bool {
        didSet {
            if isSelected != oldValue {
                invalidate()
                if isSelected {
                    onSelect?(groupId)
                }
            }
        }
    }

    public var onSelect: ((Int) -> Void)?
    private let label: Label
    private static var groups: [Int: [RadioButton]] = [:]

    /// Initializes a new radio button with the specified label and group.
    /// - Parameters:
    ///   - x: The x-coordinate of the button's origin.
    ///   - y: The y-coordinate of the button's origin.
    ///   - label: The label text to display next to the button.
    ///   - groupId: The group ID (radio buttons with same groupId are mutually exclusive).
    ///   - isSelected: Initial selected state.
    public init(x: Int, y: Int, label: String, groupId: Int, isSelected: Bool = false) {
        self.groupId = groupId
        self.isSelected = isSelected
        self.label = Label(x: 4, y: 0, text: label)
        super.init(frame: Rect(x, y, label.count + 6, 1))
        isFocusable = true
        addSubview(self.label)
        
        // Register this button with its group
        if RadioButton.groups[groupId] == nil {
            RadioButton.groups[groupId] = []
        }
        RadioButton.groups[groupId]?.append(self)
    }

    public override func draw(into surface: Surface, clip: Rect) {
        let radio = isSelected ? "(●)" : "( )"
        surface.putString(x: frame.x, y: frame.y, text: radio, fg: foregroundColor, bg: backgroundColor)
        
        // Draw label
        label.draw(into: surface, clip: clip)
    }

    public override func handle(event: KeyEvent) -> Bool {
        switch event.keyCode {
        case .char(" "), .enter:
            select()
            return true
        default:
            return false
        }
    }

    public func select() {
        // Deselect all others in the same group
        if let group = RadioButton.groups[groupId] {
            for button in group {
                if button !== self {
                    button.isSelected = false
                }
            }
        }
        isSelected = true
    }
}
