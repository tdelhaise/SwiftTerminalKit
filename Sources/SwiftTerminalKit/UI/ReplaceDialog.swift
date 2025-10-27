
//
//  ReplaceDialog.swift
//  SwiftTerminalKit
//
//  Created by Thierry on 2024-07-11.
//

import Foundation

/// A dialog for finding and replacing text.
public class ReplaceDialog: Dialog {
    private var findInput: InputLine
    private var replaceInput: InputLine
    private var caseSensitiveCheckbox: Checkbox
    private var replaceButton: Button
    private var replaceAllButton: Button
    private var cancelButton: Button

    public var replaceAction: ((String, String, Bool) -> Void)?
    public var replaceAllAction: ((String, String, Bool) -> Void)?

    public init() {
        let dialogWidth = 50
        let dialogHeight = 7

        // Center the dialog
        // TODO: Get screen dimensions from somewhere
        let screenWidth = 80
        let screenHeight = 24
        let dialogX = (screenWidth - dialogWidth) / 2
        let dialogY = (screenHeight - dialogHeight) / 2

        self.findInput = InputLine(x: 2, y: 1, width: dialogWidth - 4, text: "")
        self.replaceInput = InputLine(x: 2, y: 2, width: dialogWidth - 4, text: "")
        self.caseSensitiveCheckbox = Checkbox(x: 2, y: 3, text: "Case sensitive")
        self.replaceButton = Button(x: dialogWidth - 34, y: 5, text: "Replace")
        self.replaceAllButton = Button(x: dialogWidth - 22, y: 5, text: "Replace All")
        self.cancelButton = Button(x: dialogWidth - 12, y: 5, text: "Cancel")

        super.init(frame: Rect(dialogX, dialogY, dialogWidth, dialogHeight), title: "Replace")

        addSubview(findInput)
        addSubview(replaceInput)
        addSubview(caseSensitiveCheckbox)
        addSubview(replaceButton)
        addSubview(replaceAllButton)
        addSubview(cancelButton)

        replaceButton.action = { [weak self] in
            guard let self = self else { return }
            self.replaceAction?(self.findInput.text, self.replaceInput.text, self.caseSensitiveCheckbox.isChecked)
        }

        replaceAllButton.action = { [weak self] in
            guard let self = self else { return }
            self.replaceAllAction?(self.findInput.text, self.replaceInput.text, self.caseSensitiveCheckbox.isChecked)
        }
    }
}
