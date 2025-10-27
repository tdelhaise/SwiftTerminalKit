import SwiftTerminalKit
import Foundation

struct TVEditTheme {
    let desktopBackground: Console.PaletteColor
    let editorForeground: Console.PaletteColor
    let editorBackground: Console.PaletteColor
    let editorBorder: Console.PaletteColor
    let menuForeground: Console.PaletteColor
    let menuBackground: Console.PaletteColor
    let menuHighlightForeground: Console.PaletteColor
    let menuHighlightBackground: Console.PaletteColor
    let statusForeground: Console.PaletteColor
    let statusBackground: Console.PaletteColor

    static let tvClassic = TVEditTheme(
        desktopBackground: .named(.blue),
        editorForeground: .named(.brightWhite),
        editorBackground: .named(.blue),
        editorBorder: .named(.brightWhite),
        menuForeground: .named(.white),
        menuBackground: .named(.cyan),
        menuHighlightForeground: .named(.black),
        menuHighlightBackground: .named(.brightWhite),
        statusForeground: .named(.black),
        statusBackground: .gray(level: 20)
    )
}

final class TextEditDemoApp: Application, MenuCommandDelegate {
    private let theme: TVEditTheme = .tvClassic
    private var menuBar: MenuBar!
    private var statusLine: StatusLine!
    private var editor: EditorView!
    private var defaultStatusMessage: String = "Ready"
    private var topMenus: [MenuView] = []

    override func setup() throws {
        defaultStatusMessage = console.capabilitySummary ?? "Ready"

        screen.backgroundFG = .default
        screen.backgroundBG = theme.desktopBackground

        let size = screen.size

        menuBar = makeMenuBar(width: size.cols, height: size.rows)
        menuBar.delegate = self
        menuBar.zIndex = 10

        editor = EditorView(frame: Rect(0, 1, size.cols, size.rows - 2), zIndex: 0)
        editor.borderTitle = " SwiftTerminalKit TextEdit "
        editor.statusHint = " Ctrl+S Save  Ctrl+Q Quit "
        editor.foregroundColor = theme.editorForeground
        editor.backgroundColor = theme.editorBackground

        statusLine = StatusLine(width: size.cols)
        statusLine.frame = Rect(0, size.rows - 1, size.cols, 1)
        statusLine.zIndex = 20

        screen.addView(editor)
        screen.addView(menuBar)
        screen.addView(statusLine)
        screen.setFocus(editor)

        applyTheme()
        restoreDefaultStatus()
        statusLine.updateCursorInfo(line: editor.cursorY + 1, col: editor.cursorX + 1)
    }

    override func teardown() {
        statusLine = nil
        menuBar = nil
        editor = nil
    }

    override func statusDidUpdate(_ message: String) {
        super.statusDidUpdate(message)
        defaultStatusMessage = message
        statusLine?.updateMessage(message)
    }

    override func handle(event: InputEvent) -> Bool {
        switch event {
        case .resize(let cols, let rows):
            layoutForSize(cols: cols, rows: rows)
            return true
        case .key(let key):
            switch processMenuKey(key) {
            case .handledStop:
                return false
            case .handledContinue:
                return true
            case .notHandled:
                break
            }

            if case .function(let num) = key.keyCode {
                showStatus("F\(num)")
            }

            if key.mods.contains(.ctrl) {
                if case .char(let ch) = key.keyCode {
                    if ch == "q" || ch == "Q" {
                        requestExit()
                        return false
                    }
                    if ch == "s" || ch == "S" {
                        do {
                            try saveEditor()
                            showStatus("File saved.", permanent: true)
                        } catch {
                            showStatus("Save failed: \(error.localizedDescription)")
                        }
                        return true
                    }
                }
            }

            if menuBar.isActive {
                return true
            }

            if editor.handle(event: key) {
                statusLine.updateCursorInfo(line: editor.cursorY + 1, col: editor.cursorX + 1)
                restoreDefaultStatus()
            }
            return true
        default:
            return true
        }
    }

    private func showStatus(_ message: String, permanent: Bool = false) {
        statusLine.updateMessage(message)
        if permanent { defaultStatusMessage = message }
    }

    private func restoreDefaultStatus() {
        statusLine.updateMessage(defaultStatusMessage)
    }

    // MARK: - Menu handling

    private enum MenuResult { case notHandled, handledContinue, handledStop }

    private func processMenuKey(_ key: KeyEvent) -> MenuResult {
        if case .function(let number) = key.keyCode, number == 10 {
            if menuBar.isActive {
                deactivateMenuBar(restoreReadyMessage: true)
            } else {
                activateMenuBar()
            }
            return .handledContinue
        }

        if key.mods.contains(.alt), case .char(let ch) = key.keyCode {
            if let (index, _) = menuBar.menu(mnemonic: ch) {
                activateMenuBar(startingAt: index, openDropDown: true)
                return .handledContinue
            }
        }

        guard menuBar.isActive else { return .notHandled }

        switch key.keyCode {
        case .left:
            if let next = menuBar.focusPrevious(openDropDown: menuBar.isDropDownOpen) {
                editor.invalidate()
                menuBar.invalidate()
                screen.setFocus(next)
                next.invalidate()
                updateMenuBarFrame()
                updateStatus(for: next)
            }
            return .handledContinue
        case .right:
            if let next = menuBar.focusNext(openDropDown: menuBar.isDropDownOpen) {
                editor.invalidate()
                menuBar.invalidate()
                screen.setFocus(next)
                next.invalidate()
                updateMenuBarFrame()
                updateStatus(for: next)
            }
            return .handledContinue
        case .tab, .escape:
            deactivateMenuBar(restoreReadyMessage: true)
            return .handledContinue
        case .down:
            if !menuBar.isDropDownOpen {
                if let menu = menuBar.openCurrentDropDown() {
                    editor.invalidate()
                    menuBar.invalidate()
                    menu.invalidate()
                    updateMenuBarFrame()
                    updateStatus(for: menu)
                }
            } else if let menu = menuBar.currentMenu() {
                if menu.adjustSelection(by: 1) {
                    menu.invalidate()
                    menuBar.invalidate()
                    editor.invalidate()
                    updateStatus(for: menu)
                }
            }
            return .handledContinue
        case .up:
            if menuBar.isDropDownOpen, let menu = menuBar.currentMenu() {
                if menu.adjustSelection(by: -1) {
                    menu.invalidate()
                    menuBar.invalidate()
                    editor.invalidate()
                    updateStatus(for: menu)
                }
            }
            return .handledContinue
        case .enter:
            if !menuBar.isDropDownOpen {
                if let menu = menuBar.openCurrentDropDown() {
                    editor.invalidate()
                    menuBar.invalidate()
                    menu.invalidate()
                    updateMenuBarFrame()
                    updateStatus(for: menu)
                    return .handledContinue
                }
            }
            let keepRunning = triggerCurrentMenu()
            deactivateMenuBar(restoreReadyMessage: keepRunning)
            return keepRunning ? .handledContinue : .handledStop
        case .char(let ch):
            if let (index, _) = menuBar.menu(mnemonic: ch) {
                activateMenuBar(startingAt: index, openDropDown: true)
            }
            return .handledContinue
        default:
            return .handledContinue
        }
    }

    private func activateMenuBar(startingAt index: Int? = nil, openDropDown: Bool = false) {
        guard let menu = menuBar.activate(at: index, openDropDown: openDropDown) else { return }
        editor.invalidate()
        menuBar.invalidate()
        menu.invalidate()
        screen.setFocus(menu)
        updateMenuBarFrame()
        updateStatus(for: menu)
    }

    private func deactivateMenuBar(restoreReadyMessage: Bool) {
        menuBar.deactivate()
        menuBar.invalidate()
        updateMenuBarFrame()
        editor.invalidate()
        screen.setFocus(editor)
        statusLine.updateCursorInfo(line: editor.cursorY + 1, col: editor.cursorX + 1)
        if restoreReadyMessage {
            restoreDefaultStatus()
        }
    }

    private func triggerCurrentMenu() -> Bool {
        guard let menu = menuBar.currentMenu() else { return true }
        if let item = menu.currentSubItem() {
            showStatus(item.title)
            return handleMenuCommand(item.commandId)
        } else {
            showStatus(menu.title)
            return handleMenuCommand(menu.commandId)
        }
    }

    private func updateStatus(for menu: MenuView) {
        if let item = menu.currentSubItem() {
            showStatus(item.title)
        } else {
            showStatus(menu.title)
        }
    }

    // MARK: - MenuCommandDelegate

    func handleMenuCommand(_ commandId: Int) -> Bool {
        switch commandId {
        case 1: showStatus("New (not implemented)")
        case 2: showStatus("Open (not implemented)")
        case 3: do { try saveEditor(); showStatus("File saved.", permanent: true) } catch { showStatus("Save failed: \(error.localizedDescription)") }
        case 4: showStatus("Save As (not implemented)")
        case 5: requestExit(); return false
        case 6: showStatus("Cut (not implemented)")
        case 7: showStatus("Copy (not implemented)")
        case 8: showStatus("Paste (not implemented)")
        case 9: showStatus("Undo (not implemented)")
        case 10: showStatus("Redo (not implemented)")
        case 11: showStatus("Find (not implemented)")
        case 12: showStatus("Replace (not implemented)")
        default: break
        }
        return true
    }

    // MARK: - Helpers

    private func layoutForSize(cols: Int, rows: Int) {
        editor.frame = Rect(0, 1, cols, max(0, rows - 2))
        statusLine.frame = Rect(0, rows - 1, cols, 1)
        updateMenuBarFrame()
        editor.invalidate()
        statusLine.invalidate()
        menuBar.invalidate()
    }

    private func saveEditor() throws {
        let text = editor.contents()
        try text.write(to: URL(fileURLWithPath: "textedit.txt"), atomically: true, encoding: .utf8)
    }

    private func makeMenuBar(width: Int, height: Int) -> MenuBar {
        let fileMenu = MenuView(x: 0, y: 0, title: "File", commandId: 0, subMenu: [
            MenuView(x: 0, y: 0, title: "New", commandId: 1),
            MenuView(x: 0, y: 1, title: "Open...", commandId: 2),
            MenuView(x: 0, y: 2, title: "Save", commandId: 3),
            MenuView(x: 0, y: 3, title: "Save As...", commandId: 4),
            MenuView(x: 0, y: 4, title: "Quit", commandId: 5)
        ])
        let editMenu = MenuView(x: 0, y: 0, title: "Edit", commandId: 0, subMenu: [
            MenuView(x: 0, y: 0, title: "Cut", commandId: 6),
            MenuView(x: 0, y: 1, title: "Copy", commandId: 7),
            MenuView(x: 0, y: 2, title: "Paste", commandId: 8),
            MenuView(x: 0, y: 3, title: "Undo", commandId: 9),
            MenuView(x: 0, y: 4, title: "Redo", commandId: 10)
        ])
        let searchMenu = MenuView(x: 0, y: 0, title: "Search", commandId: 0, subMenu: [
            MenuView(x: 0, y: 0, title: "Find...", commandId: 11),
            MenuView(x: 0, y: 1, title: "Replace...", commandId: 12)
        ])
        topMenus = [fileMenu, editMenu, searchMenu]
        let bar = MenuBar(menuItems: topMenus)
        let height = menuBarHeight(forDropDownCount: 0)
        bar.frame = Rect(0, 0, width, height)
        bar.foregroundColor = theme.menuForeground
        bar.backgroundColor = theme.menuBackground
        return bar
    }

    private func applyTheme() {
        editor.foregroundColor = theme.editorForeground
        editor.backgroundColor = theme.editorBackground
        editor.borderTitle = " SwiftTerminalKit TextEdit "
        editor.statusHint = " Ctrl+S Save  Ctrl+Q Quit "
        editor.invalidate()

        menuBar.foregroundColor = theme.menuForeground
        menuBar.backgroundColor = theme.menuBackground
        for menu in topMenus {
            applyTheme(to: menu)
        }
        menuBar.invalidate()

        statusLine.foregroundColor = theme.statusForeground
        statusLine.backgroundColor = theme.statusBackground
        statusLine.invalidate()
    }

    private func applyTheme(to menu: MenuView) {
        menu.normalFG = theme.menuForeground
        menu.normalBG = theme.menuBackground
        menu.highlightFG = theme.menuHighlightForeground
        menu.highlightBG = theme.menuHighlightBackground
        menu.disabledFG = .gray(level: 12)
        menu.disabledBG = theme.menuBackground
        if let sub = menu.subMenu {
            for entry in sub { applyTheme(to: entry) }
        }
    }

    private func updateMenuBarFrame() {
        guard let menuBar = menuBar else { return }
        let dropCount = menuBar.isDropDownOpen ? (menuBar.currentMenu()?.subMenu?.count ?? 0) : 0
        let width = screen.size.cols
        let height = menuBarHeight(forDropDownCount: dropCount)
        if menuBar.frame.w != width || menuBar.frame.h != height {
            menuBar.frame = Rect(0, 0, width, height)
        }
    }

    private func menuBarHeight(forDropDownCount count: Int) -> Int {
        return max(1, min(screen.size.rows, count + 1))
    }
}
