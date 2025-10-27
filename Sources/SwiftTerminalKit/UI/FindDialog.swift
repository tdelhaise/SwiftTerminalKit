
//
//  FindDialog.swift
//  SwiftTerminalKit
//
//  Created by Thierry on 2024-07-11.
//

import Foundation

/// A dialog for finding text.
public class FindDialog: Dialog {
    private var findInput: InputLine
    private var caseSensitiveCheckbox: Checkbox
    private var findButton: Button
    private var cancelButton: Button

    public var findAction: ((String, Bool) -> Void)?

    public init() {
        let dialogWidth = 50
        let dialogHeight = 5

        // Center the dialog
        // TODO: Get screen dimensions from somewhere
        let screenWidth = 80
        let screenHeight = 24
        let dialogX = (screenWidth - dialogWidth) / 2
        let dialogY = (screenHeight - dialogHeight) / 2

        self.findInput = InputLine(x: 2, y: 1, width: dialogWidth - 4, text: "")
        self.caseSensitiveCheckbox = Checkbox(x: 2, y: 2, text: "Case sensitive")
        self.findButton = Button(x: dialogWidth - 22, y: 4, text: "Find")
        self.cancelButton = Button(x: dialogWidth - 12, y: 4, text: "Cancel")

        super.init(frame: Rect(dialogX, dialogY, dialogWidth, dialogHeight), title: "Find")

        addSubview(findInput)
        addSubview(caseSensitiveCheckbox)
        addSubview(findButton)
        addSubview(cancelButton)

        findButton.action = { [weak self] in
            guard let self = self else { return }
            self.findAction?(self.findInput.text, self.caseSensitiveCheckbox.isChecked)
        }
    }
}
