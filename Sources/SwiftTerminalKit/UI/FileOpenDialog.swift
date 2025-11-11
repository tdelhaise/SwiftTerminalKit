
//
//  FileOpenDialog.swift
//  SwiftTerminalKit
//
//  Created by Thierry on 2025-11-11.
//

import Foundation

/// A modal dialog for selecting a file to open.
public class FileOpenDialog: Dialog {
    private var fileList: [String] = []
    private var selectedIndex: Int = 0
    private var currentPath: String
    private var completion: ((URL?) -> Void)?

    /// Initializes a new file open dialog.
    /// - Parameters:
    ///   - frame: The position and size of the dialog.
    ///   - path: The initial directory path to list.
    public init(frame: Rect, path: String = ".") {
        self.currentPath = path
        super.init(frame: frame, title: "Open File")
        isFocusable = true
        loadFiles()
    }

    private func loadFiles() {
        do {
            fileList = try FileManager.default.contentsOfDirectory(atPath: currentPath)
                .sorted()
                .prefix(frame.h - 4) // Leave room for title, status, buttons
                .map { String($0) }
        } catch {
            fileList = []
        }
        selectedIndex = 0
        invalidate()
    }

    public override func draw(into surface: Surface, clip: Rect) {
        super.draw(into: surface, clip: clip)

        let innerX = frame.x + 1
        let innerY = frame.y + 2
        let innerW = frame.w - 2
        let innerH = frame.h - 5

        // Draw file list
        for (index, file) in fileList.enumerated() {
            if index >= innerH { break }
            let y = innerY + index
            let isSelected = (index == selectedIndex)
            let displayText = String(file.prefix(innerW - 1).padding(toLength: innerW - 1, withPad: " ", startingAt: 0))
            let fg = isSelected ? Console.PaletteColor.named(.black) : foregroundColor
            let bg = isSelected ? Console.PaletteColor.named(.brightWhite) : backgroundColor
            surface.putString(x: innerX, y: y, text: displayText, fg: fg, bg: bg)
        }

        // Draw buttons
        let buttonY = frame.y + frame.h - 2
        let openBtn = "[ Open ]"
        let cancelBtn = "[ Cancel ]"
        surface.putString(x: innerX, y: buttonY, text: openBtn, fg: foregroundColor, bg: backgroundColor)
        surface.putString(x: innerX + innerW - cancelBtn.count, y: buttonY, text: cancelBtn, fg: foregroundColor, bg: backgroundColor)

        // Draw instructions
        let instrY = frame.y + frame.h - 1
        let instr = "↑↓ Select  Enter Open  Esc Cancel"
        let instrClipped = String(instr.prefix(frame.w - 2).padding(toLength: frame.w - 2, withPad: " ", startingAt: 0))
        surface.putString(x: innerX, y: instrY, text: instrClipped, fg: .gray(level: 12), bg: backgroundColor)
    }

    public func handle(event: KeyEvent) -> Bool {
        switch event.keyCode {
        case .up:
            if selectedIndex > 0 {
                selectedIndex -= 1
                invalidate()
            }
            return true
        case .down:
            if selectedIndex < fileList.count - 1 {
                selectedIndex += 1
                invalidate()
            }
            return true
        case .enter:
            if selectedIndex < fileList.count {
                let selected = fileList[selectedIndex]
                let fullPath = (currentPath as NSString).appendingPathComponent(selected)
                completion?(URL(fileURLWithPath: fullPath))
            }
            return true
        case .escape:
            completion?(nil)
            return true
        default:
            return false
        }
    }

    /// Presents the dialog modally and calls the completion handler.
    public func present(on screen: Screen, completion: @escaping (URL?) -> Void) {
        self.completion = completion
        screen.addView(self)
        screen.setFocus(self)
        invalidate()
    }
}
