
//
//  MenuBar.swift
//  SwiftTerminalKit
//
//  Created by Thierry on 2024-07-11.
//

import Foundation

/// A menu bar view that displays top-level menu items.
public class MenuBar: View {
    private var menuItems: [MenuView]
    private var activeIndex: Int? = nil
    private var dropDownOpen: Bool = false
    
    public var isActive: Bool { activeIndex != nil }
    public var isDropDownOpen: Bool { dropDownOpen }

    public var delegate: MenuCommandDelegate? // The view that will handle menu commands

    public init(menuItems: [MenuView]) {
        self.menuItems = menuItems
        let totalWidth = menuItems.reduce(0) { $0 + $1.frame.w }
        super.init(frame: Rect(0, 0, totalWidth, 1))

        var currentX = 0
        for item in menuItems {
            item.frame.x = currentX
            addSubview(item)
            currentX += item.frame.w
        }
    }

    public override func draw(into surface: Surface, clip: Rect) {
        surface.fill(clip, cell: .init(" ", fg: foregroundColor, bg: backgroundColor))

        for item in menuItems {
            let itemClip = clip
            if !itemClip.isEmpty {
                item.draw(into: surface, clip: itemClip)
            }
        }
    }

    @discardableResult
    public func activate(at index: Int? = nil, openDropDown: Bool = false) -> MenuView? {
        guard !menuItems.isEmpty else { return nil }
        let resolved = index ?? activeIndex ?? 0
        let clamped = (resolved >= 0 && resolved < menuItems.count) ? resolved : 0
        activeIndex = clamped
        let menu = menuItems[clamped]
        for (i, item) in menuItems.enumerated() where i != clamped {
            item.clearSelection()
        }
        dropDownOpen = openDropDown && menu.hasDropDown
        applyDropDownState(to: menu)
        return menu
    }
    
    public func deactivate() {
        dropDownOpen = false
        activeIndex = nil
        for menu in menuItems { menu.clearSelection() }
    }
    
    public func currentMenu() -> MenuView? {
        guard let idx = activeIndex, menuItems.indices.contains(idx) else { return nil }
        return menuItems[idx]
    }
    
    @discardableResult
    public func focusNext(openDropDown: Bool? = nil) -> MenuView? {
        guard let menu = moveSelection(by: 1) else { return nil }
        if let open = openDropDown { dropDownOpen = open }
        applyDropDownState(to: menu)
        return menu
    }

    @discardableResult
    public func focusPrevious(openDropDown: Bool? = nil) -> MenuView? {
        guard let menu = moveSelection(by: -1) else { return nil }
        if let open = openDropDown { dropDownOpen = open }
        applyDropDownState(to: menu)
        return menu
    }
    
    public func menu(mnemonic: Character) -> (index: Int, menu: MenuView)? {
        guard let target = String(mnemonic).uppercased().first else { return nil }
        for (index, item) in menuItems.enumerated() {
            guard let first = item.title.first else { continue }
            if let itemFirst = String(first).uppercased().first, itemFirst == target {
                return (index, item)
            }
        }
        return nil
    }

    @discardableResult
    public func openCurrentDropDown() -> MenuView? {
        guard let menu = currentMenu(), menu.hasDropDown else {
            dropDownOpen = false
            return nil
        }
        dropDownOpen = true
        _ = menu.focusFirstItem()
        return menu
    }

    public func closeCurrentDropDown() {
        dropDownOpen = false
        currentMenu()?.clearSelection()
    }
    
    private func moveSelection(by delta: Int) -> MenuView? {
        guard let idx = activeIndex, !menuItems.isEmpty else { return nil }
        let count = menuItems.count
        let next = (idx + delta + count) % count
        activeIndex = next
        let menu = menuItems[next]
        for (i, item) in menuItems.enumerated() where i != next {
            item.clearSelection()
        }
        menu.clearSelection()
        return menu
    }

    private func applyDropDownState(to menu: MenuView) {
        if dropDownOpen && menu.hasDropDown {
            _ = menu.focusFirstItem()
        } else {
            dropDownOpen = dropDownOpen && menu.hasDropDown
            menu.clearSelection()
        }
    }
}
