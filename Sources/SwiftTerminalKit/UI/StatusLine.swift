
//
//  StatusLine.swift
//  SwiftTerminalKit
//
//  Created by Thierry on 2024-07-11.
//

import Foundation

/// A view that displays status information at the bottom of the screen.
public class StatusLine: View {
    private var message: String = ""
    private var cursorInfo: String = ""

    public init(width: Int) {
        super.init(frame: Rect(0, 0, width, 1))
        // Status line is typically at the bottom of the screen
        // Its y-coordinate will be set by the main application view
    }

    public func updateMessage(_ message: String) {
        self.message = message
        invalidate()
    }

    public func updateCursorInfo(line: Int, col: Int) {
        self.cursorInfo = "L:\(line) C:\(col)"
        invalidate()
	}

	public override func draw(into surface: Surface, clip: Rect) {
		let fg = foregroundColor
		let bg = backgroundColor

		// Fill background
		surface.fill(frame, cell: .init(" ", fg: fg, bg: bg))

		// Draw message on the left
		surface.putString(x: frame.x + 1, y: frame.y, text: message, fg: fg, bg: bg)

		// Draw cursor info on the right
		let infoWidth = cursorInfo.count
		surface.putString(x: frame.x + frame.w - infoWidth - 1, y: frame.y, text: cursorInfo, fg: fg, bg: bg)
	}
}
