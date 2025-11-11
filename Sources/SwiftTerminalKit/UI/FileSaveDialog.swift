
//
//  FileSaveDialog.swift
//  SwiftTerminalKit
//
//  Created by Thierry on 2025-11-11.
//

import Foundation

/// A modal dialog for selecting a filename and location to save.
public class FileSaveDialog: Dialog {
    private var filename: String = ""
    private var completion: ((URL?) -> Void)?
    private var showOverwritePrompt: Bool = false

    /// Initializes a new file save dialog.
    /// - Parameters:
    ///   - frame: The position and size of the dialog.
    ///   - defaultName: The default filename to suggest.
    public init(frame: Rect, defaultName: String = "untitled.txt") {
        self.filename = defaultName
        super.init(frame: frame, title: "Save File")
        isFocusable = true
    }

    public override func draw(into surface: Surface, clip: Rect) {
        super.draw(into: surface, clip: clip)

        let innerX = frame.x + 1
        let innerY = frame.y + 2
        let innerW = frame.w - 2

        // Draw label
        surface.putString(x: innerX, y: innerY, text: "Filename:", fg: foregroundColor, bg: backgroundColor)

        // Draw input field
        let inputY = innerY + 1
        let inputText = String(filename.prefix(innerW - 1).padding(toLength: innerW - 1, withPad: " ", startingAt: 0))
        surface.putString(x: innerX, y: inputY, text: inputText, fg: .named(.black), bg: .gray(level: 20))

        // Draw buttons
        let buttonY = frame.y + frame.h - 2
        let saveBtn = "[ Save ]"
        let cancelBtn = "[ Cancel ]"
        surface.putString(x: innerX, y: buttonY, text: saveBtn, fg: foregroundColor, bg: backgroundColor)
        surface.putString(x: innerX + innerW - cancelBtn.count, y: buttonY, text: cancelBtn, fg: foregroundColor, bg: backgroundColor)

        // Draw instructions
        let instrY = frame.y + frame.h - 1
        let instr = "Type filename  Enter Save  Esc Cancel"
        let instrClipped = String(instr.prefix(frame.w - 2).padding(toLength: frame.w - 2, withPad: " ", startingAt: 0))
        surface.putString(x: innerX, y: instrY, text: instrClipped, fg: .gray(level: 12), bg: backgroundColor)

        // Draw overwrite prompt if needed
        if showOverwritePrompt {
            let promptY = innerY + 3
            let prompt = "File exists. Overwrite? (Y/N)"
            surface.putString(x: innerX, y: promptY, text: prompt, fg: .named(.brightRed), bg: backgroundColor)
        }
    }

    public func handle(event: KeyEvent) -> Bool {
        // If showing overwrite prompt, handle Y/N
        if showOverwritePrompt {
            switch event.keyCode {
            case .char(let ch) where ch.lowercased() == "y":
                showOverwritePrompt = false
                confirm()
                return true
            case .char(let ch) where ch.lowercased() == "n":
                showOverwritePrompt = false
                invalidate()
                return true
            default:
                return false
            }
        }

        // Normal input handling
        switch event.keyCode {
        case .char(let ch):
            filename.append(ch)
            invalidate()
            return true
        case .backspace, .delete:
            if !filename.isEmpty {
                filename.removeLast()
                invalidate()
            }
            return true
        case .enter:
            // Check if file exists
            if FileManager.default.fileExists(atPath: filename) {
                showOverwritePrompt = true
                invalidate()
            } else {
                confirm()
            }
            return true
        case .escape:
            completion?(nil)
            return true
        default:
            return false
        }
    }

    private func confirm() {
        let url = URL(fileURLWithPath: filename)
        completion?(url)
    }

    /// Presents the dialog modally and calls the completion handler.
    public func present(on screen: Screen, completion: @escaping (URL?) -> Void) {
        self.completion = completion
        screen.addView(self)
        screen.setFocus(self)
        invalidate()
    }
}
