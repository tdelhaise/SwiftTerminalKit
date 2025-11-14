
//
//  Dialog.swift
//  SwiftTerminalKit
//
//  Created by Thierry on 2024-07-11.
//

import Foundation

/// A modal view that presents information and requires user interaction.
public class Dialog: View {
    private var titleLabel: Label

    /// Initializes a new dialog with the specified frame and title.
    /// - Parameters:
    ///   - frame: The position and size of the dialog.
    ///   - title: The title to display in the dialog's border.
    public init(frame: Rect, title: String) {
        self.titleLabel = Label(x: 2, y: 0, text: title)
        super.init(frame: frame)
        borderStyle = .single
        addSubview(titleLabel)
    }

    public override func draw(into surface: Surface, clip: Rect) {
        // The default View.draw will fill the background and draw subviews.
        super.draw(into: surface, clip: clip)

        // Draw the border on top of the background fill.
        drawBorder(into: surface, clip: clip)
    }

    private func drawBorder(into surface: Surface, clip: Rect) {
        guard borderStyle != .none else { return }

        let borderRect = frame
        guard clip.intersects(borderRect) else { return }

        // Use box-drawing characters for a cleaner look
        let vertical = "│"
        let horizontal = "─"
        let topLeft = "┌", topRight = "┐", bottomLeft = "└", bottomRight = "┘"

        // Draw corners
        surface.putString(x: borderRect.x, y: borderRect.y, text: topLeft, fg: foregroundColor, bg: backgroundColor)
        surface.putString(x: borderRect.x + borderRect.w - 1, y: borderRect.y, text: topRight, fg: foregroundColor, bg: backgroundColor)
        surface.putString(x: borderRect.x, y: borderRect.y + borderRect.h - 1, text: bottomLeft, fg: foregroundColor, bg: backgroundColor)
        surface.putString(x: borderRect.x + borderRect.w - 1, y: borderRect.y + borderRect.h - 1, text: bottomRight, fg: foregroundColor, bg: backgroundColor)

        // Draw sides
        for y in (borderRect.y + 1)..<(borderRect.y + borderRect.h - 1) {
            surface.putString(x: borderRect.x, y: y, text: vertical, fg: foregroundColor, bg: backgroundColor)
            surface.putString(x: borderRect.x + borderRect.w - 1, y: y, text: vertical, fg: foregroundColor, bg: backgroundColor)
        }
        for x in (borderRect.x + 1)..<(borderRect.x + borderRect.w - 1) {
            surface.putString(x: x, y: borderRect.y, text: horizontal, fg: foregroundColor, bg: backgroundColor)
            surface.putString(x: x, y: borderRect.y + borderRect.h - 1, text: horizontal, fg: foregroundColor, bg: backgroundColor)
        }
    }
}
