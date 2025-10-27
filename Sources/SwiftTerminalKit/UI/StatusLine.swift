
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
    private var persistentPrefix: String = ""

    public init(width: Int) {
        super.init(frame: Rect(0, 0, width, 1))
        // Status line is typically at the bottom of the screen
        // Its y-coordinate will be set by the main application view
    }

    public func setPersistentPrefix(_ prefix: String) {
        persistentPrefix = prefix
        invalidate()
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

        surface.fill(clip, cell: .init(" ", fg: fg, bg: bg))

        let row = frame.y
        guard row >= clip.y && row < clip.y + clip.h else { return }

        let leftMargin = 1
        let rightMargin = 1
        let totalWidth = frame.w
        guard totalWidth > leftMargin + rightMargin else { return }

        let cursorText = cursorInfo
        let cursorLen = cursorText.count
        let reservedForCursor = cursorLen == 0 ? 0 : cursorLen + 1
        let usableWidth = max(0, totalWidth - leftMargin - rightMargin)
        let messageBudget = max(0, usableWidth - reservedForCursor)

        var composedMessage = persistentPrefix + message
        if composedMessage.count > messageBudget {
            composedMessage = String(composedMessage.prefix(messageBudget))
        }

        if messageBudget > 0 {
            let messageX = frame.x + leftMargin
            let msgRect = Rect(messageX, row, messageBudget, 1).intersection(clip)
            if msgRect.w > 0 {
                let offset = msgRect.x - messageX
                if offset < composedMessage.count {
                    let startIndex = composedMessage.index(composedMessage.startIndex, offsetBy: offset)
                    let visible = String(composedMessage[startIndex...].prefix(msgRect.w))
                    surface.putString(x: msgRect.x, y: row, text: visible, fg: fg, bg: bg)
                }
            }
        }

        if cursorLen > 0 {
            let cursorX = frame.x + totalWidth - rightMargin - cursorLen
            let cursorRect = Rect(cursorX, row, cursorLen, 1).intersection(clip)
            if cursorRect.w > 0 {
                let offset = cursorRect.x - cursorX
                if offset < cursorText.count {
                    let start = cursorText.index(cursorText.startIndex, offsetBy: offset)
                    let visible = String(cursorText[start...].prefix(cursorRect.w))
                    surface.putString(x: cursorRect.x, y: row, text: visible, fg: fg, bg: bg)
                }
            }
        }
	}
}
