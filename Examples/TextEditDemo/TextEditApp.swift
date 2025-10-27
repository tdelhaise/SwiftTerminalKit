//
//  TextEditApp.swift
//  TextEditDemo
//
//  Created by Thierry on 2024-07-11.
//

import Foundation
import SwiftTerminalKit

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

class TextEditApp: View, MenuCommandDelegate {
    let theme: TVEditTheme
    let editor: EditorView
    let menuBar: MenuBar
    let statusLine: StatusLine
    private let topMenus: [MenuView]

    var console: Console
    var screen: Screen
    var quit: Bool = false

    init(console: Console, screen: Screen, theme: TVEditTheme = .tvClassic) {
        self.console = console
        self.screen = screen
        self.theme = theme

        let editorFrame = Rect(0, 1, console.size.cols, console.size.rows - 2)
        self.editor = EditorView(frame: editorFrame, zIndex: 0, theme: theme)

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
        self.topMenus = [fileMenu, editMenu, searchMenu]
        self.menuBar = MenuBar(menuItems: topMenus)
        self.menuBar.frame = Rect(0, 0, console.size.cols, 1)

        self.statusLine = StatusLine(width: console.size.cols)
        statusLine.frame = Rect(0, console.size.rows - 1, console.size.cols, 1)

        super.init(frame: Rect(0, 0, console.size.cols, console.size.rows))

        self.menuBar.delegate = self

        addSubview(menuBar)
        addSubview(editor)
        addSubview(statusLine)

        applyTheme()

        screen.addView(self) // Add the app itself as the root view
        screen.setFocus(editor)
    }

    func handleMenuCommand(_ commandId: Int) -> Bool {
        switch commandId {
        case 1: print("New")
        case 2: print("Open")
        case 3: print("Save")
        case 4: print("Save As")
        case 5: quit = true; return false
        case 6: print("Cut")
        case 7: print("Copy")
        case 8: print("Paste")
        case 9: print("Undo")
        case 10: print("Redo")
        case 11: print("Find")
        case 12: print("Replace")
        default: break
        }
        return true
    }

    func handleEvent(_ event: InputEvent) -> Bool {
        switch event {
        case .resize(let c, let r):
            resize(cols: c, rows: r)
            return true
        case .key(let k):
            switch processMenuKey(k) {
            case .handledContinue:
                return true
            case .handledStop:
                return false
            case .notHandled:
                break
            }

            if k.mods.contains(.ctrl) {
                if case .char(let ch) = k.keyCode {
                    if ch == "q" || ch == "Q" {
                        quit = true
                        return false
                    }
                    if ch == "s" || ch == "S" {
                        do {
                            try editor.save(to: "textedit.txt")
                            statusLine.updateMessage("File saved.")
                        } catch {
                            statusLine.updateMessage("Error saving file: \(error.localizedDescription)")
                        }
                        return true
                    }
                }
            }

            if menuBar.isActive {
                // Menu bar consumed this key; do not forward to editor.
                return true
            }

            if screen.focusedView === editor {
                if editor.handle(event: k) {
                    statusLine.updateCursorInfo(line: editor.cy + 1, col: editor.cx + 1)
                    return true
                }
            }
            return true
        default:
            return true
        }
    }

    func resize(cols: Int, rows: Int) {
        frame = Rect(0, 0, cols, rows)
        editor.frame = Rect(0, 1, cols, rows - 2)
        statusLine.frame = Rect(0, rows - 1, cols, 1)
        menuBar.frame = Rect(0, 0, cols, 1)
        editor.invalidate()
        menuBar.invalidate()
        statusLine.invalidate()
        invalidate()
    }

    private func applyTheme() {
        screen.backgroundFG = theme.editorForeground
        screen.backgroundBG = theme.desktopBackground

        editor.fg = theme.editorForeground
        editor.bg = theme.editorBackground
        editor.invalidate()

        menuBar.foregroundColor = theme.menuForeground
        menuBar.backgroundColor = theme.menuBackground
        menuBar.invalidate()
        for menu in topMenus {
            applyTheme(to: menu)
        }

        statusLine.foregroundColor = theme.statusForeground
        statusLine.backgroundColor = theme.statusBackground
        statusLine.updateMessage("Ready")
        statusLine.updateCursorInfo(line: editor.cy + 1, col: editor.cx + 1)
        statusLine.invalidate()
    }

    private enum MenuHandlingResult {
        case notHandled
        case handledContinue
        case handledStop
    }
    
    private func processMenuKey(_ key: KeyEvent) -> MenuHandlingResult {
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
                activateMenuBar(startingAt: index)
                return .handledContinue
            }
        }

        guard menuBar.isActive else { return .notHandled }

        switch key.keyCode {
        case .left:
            if let next = menuBar.focusPrevious() {
                editor.invalidate()
                next.clearSelection()
                screen.setFocus(next)
                updateStatus(for: next)
            }
            return .handledContinue
        case .right:
            if let next = menuBar.focusNext() {
                editor.invalidate()
                next.clearSelection()
                screen.setFocus(next)
                updateStatus(for: next)
            }
            return .handledContinue
        case .tab, .escape:
            deactivateMenuBar(restoreReadyMessage: true)
            return .handledContinue
        case .down:
            if let menu = menuBar.currentMenu() {
                if menu.ensureSelection() {
                    menu.invalidate()
                    editor.invalidate()
                    updateStatus(for: menu)
                    return .handledContinue
                } else {
                    let keepRunning = triggerCurrentMenu()
                    deactivateMenuBar(restoreReadyMessage: keepRunning)
                    return keepRunning ? .handledContinue : .handledStop
                }
            }
            return .handledContinue
        case .up:
            if let menu = menuBar.currentMenu(), menu.moveSelection(delta: -1) {
                menu.invalidate()
                editor.invalidate()
                updateStatus(for: menu)
            }
            return .handledContinue
        case .enter:
            let keepRunning = triggerCurrentMenu()
            deactivateMenuBar(restoreReadyMessage: keepRunning)
            return keepRunning ? .handledContinue : .handledStop
        case .char(let ch):
            if let (index, menu) = menuBar.menu(mnemonic: ch) {
                editor.invalidate()
                _ = menuBar.activate(at: index)
                screen.setFocus(menu)
                updateStatus(for: menu)
            }
            return .handledContinue
        default:
            return .handledContinue
        }
    }

    private func activateMenuBar(startingAt index: Int? = nil) {
        guard let menu = menuBar.activate(at: index) else { return }
        editor.invalidate()
        menuBar.invalidate()
        menu.invalidate()
        screen.setFocus(menu)
        updateStatus(for: menu)
    }

    private func deactivateMenuBar(restoreReadyMessage: Bool) {
        menuBar.deactivate()
        menuBar.invalidate()
        editor.invalidate()
        screen.setFocus(editor)
        statusLine.updateCursorInfo(line: editor.cy + 1, col: editor.cx + 1)
        if restoreReadyMessage {
            statusLine.updateMessage("Ready")
        }
    }

    private func triggerCurrentMenu() -> Bool {
        guard let menu = menuBar.currentMenu() else { return true }
        if let item = menu.currentSubItem() {
            statusLine.updateMessage(item.title)
            return handleMenuCommand(item.commandId)
        } else {
            statusLine.updateMessage(menu.title)
            return handleMenuCommand(menu.commandId)
        }
    }

    private func updateStatus(for menu: MenuView) {
        if let item = menu.currentSubItem() {
            statusLine.updateMessage(item.title)
        } else {
            statusLine.updateMessage(menu.title)
        }
    }

    private func applyTheme(to menu: MenuView) {
        menu.normalFG = theme.menuForeground
        menu.normalBG = theme.menuBackground
        menu.highlightFG = theme.menuHighlightForeground
        menu.highlightBG = theme.menuHighlightBackground
        menu.disabledFG = .gray(level: 12)
        menu.disabledBG = theme.menuBackground
        menu.invalidate()
        if let children = menu.subMenu {
            for item in children {
                applyTheme(to: item)
            }
        }
    }
}
