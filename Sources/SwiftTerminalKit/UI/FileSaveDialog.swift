
import Foundation



/// A modal dialog for selecting a filename and location to save.

public class FileSaveDialog: Dialog {

    private enum FocusableElement {

        case inputField, saveButton, cancelButton

    }



    private var filename: String = ""

    private var completion: ((URL?) -> Void)?

    private var showOverwritePrompt: Bool = false

    private var internalFocus: FocusableElement = .inputField



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

        let isInputFocused = (internalFocus == .inputField)

        surface.putString(x: innerX, y: inputY, text: inputText, 

                          fg: isInputFocused ? backgroundColor : foregroundColor, 

                          bg: isInputFocused ? foregroundColor : backgroundColor)



        // Draw buttons

        let buttonY = frame.y + frame.h - 2

        let saveBtnText = "[ Save ]"

        let cancelBtnText = "[ Cancel ]"

        

        let isSaveFocused = (internalFocus == .saveButton)

        surface.putString(x: innerX, y: buttonY, text: saveBtnText, 

                          fg: isSaveFocused ? backgroundColor : foregroundColor, 

                          bg: isSaveFocused ? foregroundColor : backgroundColor)



        let isCancelFocused = (internalFocus == .cancelButton)

        surface.putString(x: innerX + innerW - cancelBtnText.count, y: buttonY, text: cancelBtnText, 

                          fg: isCancelFocused ? backgroundColor : foregroundColor, 

                          bg: isCancelFocused ? foregroundColor : backgroundColor)



        // Draw overwrite prompt if needed

        if showOverwritePrompt {

            let promptY = innerY + 3

            let prompt = "File exists. Overwrite? (Y/N)"

            surface.putString(x: innerX, y: promptY, text: prompt, fg: foregroundColor, bg: backgroundColor)

        }

    }



    private func performSave() {

        if FileManager.default.fileExists(atPath: filename) {

            showOverwritePrompt = true

            invalidate()

        } else {

            confirm()

        }

    }



    private func confirm() {

        let url = URL(fileURLWithPath: filename)

        completion?(url)

    }



    public override func handle(event: KeyEvent) -> Bool {

        // If showing overwrite prompt, it captures all input

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

                return true // Consume other keys

            }

        }



        switch event.keyCode {

        case .tab:

            if event.mods.contains(.shift) { // Shift+Tab, cycle backwards

                switch internalFocus {

                case .inputField: internalFocus = .cancelButton

                case .saveButton: internalFocus = .inputField

                case .cancelButton: internalFocus = .saveButton

                }

            } else { // Tab, cycle forwards

                switch internalFocus {

                case .inputField: internalFocus = .saveButton

                case .saveButton: internalFocus = .cancelButton

                case .cancelButton: internalFocus = .inputField

                }

            }

            invalidate()

            return true



        case .enter:

            switch internalFocus {

            case .inputField, .saveButton:

                performSave()

            case .cancelButton:

                completion?(nil)

            }

            return true



        case .escape:

            completion?(nil)

            return true



        // Character input only if input field is focused

        case .char(let ch):

            if internalFocus == .inputField {

                filename.append(ch)

                invalidate()

            }

            return true

        case .backspace, .delete:

            if internalFocus == .inputField, !filename.isEmpty {

                filename.removeLast()

                invalidate()

            }

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


