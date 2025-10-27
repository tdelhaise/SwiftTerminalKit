
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
    
    public var isActive: Bool { activeIndex != nil }

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
        // Draw background for the entire menu bar
		surface.fill(frame, cell: .init(" ", fg: foregroundColor, bg: backgroundColor))

        // Draw each menu item
        super.draw(into: surface, clip: clip)
    }

    public func activate(at index: Int? = nil) -> MenuView? {
        guard !menuItems.isEmpty else { return nil }
        let resolved = index ?? activeIndex ?? 0
        let clamped = (resolved >= 0 && resolved < menuItems.count) ? resolved : 0
        activeIndex = clamped
        let menu = menuItems[clamped]
        menu.resetSelection()
        return menu
    }
    
    public func deactivate() {
        activeIndex = nil
        for menu in menuItems { menu.clearSelection() }
    }
    
    public func currentMenu() -> MenuView? {
        guard let idx = activeIndex, menuItems.indices.contains(idx) else { return nil }
        return menuItems[idx]
    }
    
    public func focusNext() -> MenuView? {
        return moveSelection(by: 1)
    }
    
    public func focusPrevious() -> MenuView? {
        return moveSelection(by: -1)
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
    
    private func moveSelection(by delta: Int) -> MenuView? {
        guard let idx = activeIndex, !menuItems.isEmpty else { return nil }
        let count = menuItems.count
        let next = (idx + delta + count) % count
        activeIndex = next
        let menu = menuItems[next]
        menu.clearSelection()
        return menu
    }
}
