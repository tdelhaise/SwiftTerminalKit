# SwiftTerminalKit UI Components — Usage Guide

## Overview

This guide demonstrates how to use the newly implemented UI dialog and form components in SwiftTerminalKit.

---

## Components Summary

| Component | File | Purpose |
|-----------|------|---------|
| **FileOpenDialog** | `FileOpenDialog.swift` | Browse and select files to open |
| **FileSaveDialog** | `FileSaveDialog.swift` | Enter filename and save with confirmation |
| **Checkbox** | `Checkbox.swift` | Toggle boolean option with label |
| **RadioButton** | `RadioButton.swift` | Mutually exclusive option group |

---

## FileOpenDialog — Browse Files

### Quick Example
```swift
let dialog = FileOpenDialog(frame: Rect(10, 5, 50, 12), path: ".")
dialog.present(on: screen) { url in
    if let url = url {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            // Use loaded content
            print("Loaded: \(url.lastPathComponent)")
        } catch {
            print("Error: \(error)")
        }
    } else {
        print("Cancelled")
    }
}
```

### Keyboard Interaction
```
↑ / ↓       Navigate file list
Enter       Select and open file
Esc         Cancel dialog
```

### API Reference
```swift
public init(frame: Rect, path: String = ".")
public func present(on screen: Screen, completion: @escaping (URL?) -> Void)
```

---

## FileSaveDialog — Save Files

### Quick Example
```swift
let dialog = FileSaveDialog(frame: Rect(10, 5, 50, 10), defaultName: "output.txt")
dialog.present(on: screen) { url in
    if let url = url {
        do {
            try "Hello, World!".write(to: url, atomically: true, encoding: .utf8)
            print("Saved to: \(url.path)")
        } catch {
            print("Error: \(error)")
        }
    }
}
```

### Keyboard Interaction
```
Type text       Enter filename
Backspace       Delete character
Enter           Save (or confirm overwrite)
Y               Yes, overwrite existing file
N               No, cancel overwrite
Esc             Cancel dialog
```

### Overwrite Handling
If you try to save a file that already exists:
```
┌─────────────────────────┐
│ Save File              │
├─────────────────────────┤
│ Filename: report.txt    │
│                         │
│ File exists. Overwrite? │
│ (Y/N)                   │
│                         │
│ [ Save ]     [ Cancel ] │
└─────────────────────────┘
```

Press `Y` to overwrite, `N` to return to editing.

### API Reference
```swift
public init(frame: Rect, defaultName: String = "untitled.txt")
public func present(on screen: Screen, completion: @escaping (URL?) -> Void)
```

---

## Checkbox — Boolean Toggle

### Quick Example
```swift
let checkbox = Checkbox(x: 5, y: 3, text: "Enable dark mode", isChecked: false)
checkbox.onToggle = { isChecked in
    print("Dark mode: \(isChecked)")
}
screen.addView(checkbox)
screen.setFocus(checkbox)
```

### Keyboard Interaction
```
Space / Enter   Toggle checkbox
Tab             Move to next control
```

### Display
```
[ ] Enable dark mode    (unchecked)
[x] Enable dark mode    (checked)
```

### API Reference
```swift
public var isChecked: Bool
public var onToggle: ((Bool) -> Void)?
public func toggle()
public func handle(event: KeyEvent) -> Bool
```

---

## RadioButton — Mutually Exclusive Options

### Quick Example
```swift
// Create a group of radio buttons (groupId = 1)
let radio1 = RadioButton(x: 5, y: 3, label: "Light theme", groupId: 1, isSelected: true)
let radio2 = RadioButton(x: 5, y: 4, label: "Dark theme", groupId: 1, isSelected: false)
let radio3 = RadioButton(x: 5, y: 5, label: "Auto", groupId: 1, isSelected: false)

// Callback fires when any button in group is selected
radio1.onSelect = { groupId in
    print("Theme group selected: \(groupId)")
}

// Add all to screen
screen.addView(radio1)
screen.addView(radio2)
screen.addView(radio3)
```

### Behavior
- Only one button per group can be selected at a time
- Selecting one automatically deselects others in the same group
- Different `groupId` values create independent groups

### Display
```
( ) Light theme    (unselected)
(●) Dark theme     (selected)
( ) Auto           (unselected)
```

### API Reference
```swift
public var groupId: Int
public var isSelected: Bool
public var onSelect: ((Int) -> Void)?
public func select()
public func handle(event: KeyEvent) -> Bool
```

---

## Integration Example — TextEditDemo

In `TextEditDemo/TextEditDemoApp.swift`, dialogs are presented from menu commands:

```swift
case 2:  // File → Open
    let size = screen.size
    let dlgFrame = Rect((size.cols - 50) / 2, (size.rows - 12) / 2, 50, 12)
    let openDialog = FileOpenDialog(frame: dlgFrame, path: ".")
    openDialog.present(on: screen) { [weak self] url in
        guard let self = self else { return }
        self.screen.removeView(openDialog)  // Remove dialog
        self.screen.setFocus(self.editor)   // Restore focus to editor
        
        if let url = url {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                self.editor.load(text: content)
                self.showStatus("Opened: \(url.lastPathComponent)", permanent: true)
            } catch {
                self.showStatus("Open failed: \(error.localizedDescription)")
            }
        } else {
            self.restoreDefaultStatus()
        }
    }
    return true

case 4:  // File → Save As
    let size = screen.size
    let dlgFrame = Rect((size.cols - 50) / 2, (size.rows - 10) / 2, 50, 10)
    let saveDialog = FileSaveDialog(frame: dlgFrame, defaultName: "textedit.txt")
    saveDialog.present(on: screen) { [weak self] url in
        guard let self = self else { return }
        self.screen.removeView(saveDialog)
        self.screen.setFocus(self.editor)
        
        if let url = url {
            do {
                try self.editor.contents().write(to: url, atomically: true, encoding: .utf8)
                self.showStatus("Saved: \(url.lastPathComponent)", permanent: true)
            } catch {
                self.showStatus("Save failed: \(error.localizedDescription)")
            }
        } else {
            self.restoreDefaultStatus()
        }
    }
    return true
```

---

## Modal Dialog Pattern

All dialogs follow the same modal pattern:

1. **Create**: Initialize dialog with frame and initial values
2. **Present**: Call `present(on: screen, completion:)` to show
3. **Interact**: User navigates and confirms/cancels
4. **Cleanup**: Caller removes dialog and restores focus in completion handler
5. **Action**: Perform I/O or update UI based on user selection

```swift
// 1. Create
let dialog = FileOpenDialog(frame: dialogRect, path: ".")

// 2. Present
dialog.present(on: screen) { [weak self] url in
    guard let self = self else { return }
    
    // 3. Interact (done by user at terminal)
    
    // 4. Cleanup
    self.screen.removeView(dialog)
    self.screen.setFocus(self.mainView)
    
    // 5. Action
    if let url = url {
        // Do something with selection
    }
}
```

---

## Design Patterns

### Avoid Memory Leaks
Always use `[weak self]` in completion handlers:
```swift
dialog.present(on: screen) { [weak self] url in
    guard let self = self else { return }
    // Safe to use self
}
```

### Proper Focus Management
Always restore focus after dialog:
```swift
self.screen.removeView(dialog)
self.screen.setFocus(previousFocus)  // Restore!
```

### Error Handling
Display errors to user in status line or alert:
```swift
do {
    try editor.contents().write(to: url, atomically: true, encoding: .utf8)
} catch {
    showStatus("Save failed: \(error.localizedDescription)")
}
```

---

## Testing Your Implementation

### Manual Test Checklist
- [ ] Create FileOpenDialog, navigate to a file, open it
- [ ] Create FileSaveDialog, type a filename, save
- [ ] Test overwrite prompt by saving over existing file
- [ ] Test cancel (Esc) on both dialogs
- [ ] Test Checkbox toggle with Space and Enter
- [ ] Test RadioButton mutual exclusivity (select one, verify others deselect)
- [ ] Verify status messages appear after each action
- [ ] Verify focus returns to editor after dialog closes

### Run TextEditDemo
```bash
swift run TextEditDemo
```

Then use menu: **F10 → File → Open** / **Save As**

---

## Performance Notes

- **FileOpenDialog** lists files synchronously; large directories may pause UI
- **FileSaveDialog** checks file existence synchronously
- Consider adding async I/O wrapper for future production use
- Current implementation suitable for small-to-medium files

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Dialog not appearing | Check frame coordinates; adjust for screen size |
| Keys not responding | Verify dialog has focus: `screen.setFocus(dialog)` |
| Focus stuck in dialog | Call `screen.removeView(dialog)` and `screen.setFocus(other)` |
| File read fails | Check file permissions and path validity |
| Dialog overlapping | Use `Rect(x, y, w, h)` math: `(cols - w) / 2`, `(rows - h) / 2` |

---

## API Reference — Quick Lookup

### FileOpenDialog
| Method | Signature |
|--------|-----------|
| Init | `init(frame: Rect, path: String = ".") → FileOpenDialog` |
| Present | `func present(on: Screen, completion: (URL?) → Void)` |
| Handle Key | `func handle(event: KeyEvent) → Bool` |

### FileSaveDialog
| Method | Signature |
|--------|-----------|
| Init | `init(frame: Rect, defaultName: String = "untitled.txt") → FileSaveDialog` |
| Present | `func present(on: Screen, completion: (URL?) → Void)` |
| Handle Key | `func handle(event: KeyEvent) → Bool` |

### Checkbox
| Property | Type | Notes |
|----------|------|-------|
| `isChecked` | `Bool` | Automatically calls `onToggle` if changed |
| `onToggle` | `((Bool) → Void)?` | Optional callback |

### RadioButton
| Property | Type | Notes |
|----------|------|-------|
| `groupId` | `Int` | Buttons with same ID are mutually exclusive |
| `isSelected` | `Bool` | Only one per group can be true |
| `onSelect` | `((Int) → Void)?` | Fires with groupId when selected |

---

**Document**: SwiftTerminalKit UI Components Usage Guide  
**Last Updated**: November 11, 2025  
**Status**: ✅ Complete
