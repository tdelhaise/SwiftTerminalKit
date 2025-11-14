
//
//  FileOpenDialog.swift
//  SwiftTerminalKit
//
//  Created by Thierry on 2025-11-11.
//

import Foundation

/// A modal dialog for selecting a file to open.
public class FileOpenDialog: Dialog {
    private enum FocusableElement {
        case fileList, openButton, cancelButton
    }

    private var fileList: [String] = []
    private var selectedIndex: Int = 0
    private var currentPath: String
    private var completion: ((URL?) -> Void)?
    private var internalFocus: FocusableElement = .fileList

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
        let listHeight = frame.h - 5

        // Draw file list
        for (index, file) in fileList.enumerated() {
            if index >= listHeight { break }
            let y = innerY + index
            
            let isSelected = (index == selectedIndex)
            let hasListFocus = (internalFocus == .fileList)
            
            var fg = foregroundColor
            var bg = backgroundColor

            if isSelected {
                fg = hasListFocus ? backgroundColor : .gray(level: 18)
                bg = hasListFocus ? foregroundColor : backgroundColor
            }

            let displayText = String(file.prefix(innerW - 1).padding(toLength: innerW - 1, withPad: " ", startingAt: 0))
            surface.putString(x: innerX, y: y, text: displayText, fg: fg, bg: bg)
        }

        // Draw buttons
        let buttonY = frame.y + frame.h - 2
        let openBtnText = "[ Open ]"
        let cancelBtnText = "[ Cancel ]"
        
        let isOpenFocused = (internalFocus == .openButton)
        surface.putString(x: innerX, y: buttonY, text: openBtnText, 
                          fg: isOpenFocused ? backgroundColor : foregroundColor, 
                          bg: isOpenFocused ? foregroundColor : backgroundColor)

        let isCancelFocused = (internalFocus == .cancelButton)
        surface.putString(x: innerX + innerW - cancelBtnText.count, y: buttonY, text: cancelBtnText, 
                          fg: isCancelFocused ? backgroundColor : foregroundColor, 
                          bg: isCancelFocused ? foregroundColor : backgroundColor)
    }

    public override func handle(event: KeyEvent) -> Bool {
        switch event.keyCode {
        case .tab:
            if event.mods.contains(.shift) { // Shift+Tab, cycle backwards
                switch internalFocus {
                case .fileList: internalFocus = .cancelButton
                case .openButton: internalFocus = .fileList
                case .cancelButton: internalFocus = .openButton
                }
            } else { // Tab, cycle forwards
                switch internalFocus {
                case .fileList: internalFocus = .openButton
                case .openButton: internalFocus = .cancelButton
                case .cancelButton: internalFocus = .fileList
                }
            }
            invalidate()
            return true

        case .up:
            if internalFocus == .fileList, selectedIndex > 0 {
                selectedIndex -= 1
                invalidate()
            }
            return true
        case .down:
            if internalFocus == .fileList, selectedIndex < fileList.count - 1 {
                selectedIndex += 1
                invalidate()
            }
            return true

        case .enter:
            switch internalFocus {
            case .fileList, .openButton:
                if selectedIndex < fileList.count {
                    let selected = fileList[selectedIndex]
                    let fullPath = (currentPath as NSString).appendingPathComponent(selected)
                    completion?(URL(fileURLWithPath: fullPath))
                }
            case .cancelButton:
                completion?(nil)
            }
            return true

        case .escape:
            completion?(nil)
            return true
            
        default:
            // Consume all other keys to enforce modality
            return true
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
