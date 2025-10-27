
//
//  MenuView.swift
//  SwiftTerminalKit
//
//  Created by Thierry on 2024-07-11.
//

import Foundation

/// A view that displays a menu item.
public class MenuView: View {
    public var title: String
	public var commandId: Int
	public var isEnabled: Bool = true
	public var isChecked: Bool = false
	public var subMenu: [MenuView]?

	public var normalFG: Console.PaletteColor = .default
	public var normalBG: Console.PaletteColor = .default
	public var highlightFG: Console.PaletteColor = .named(.black)
	public var highlightBG: Console.PaletteColor = .named(.white)
	public var disabledFG: Console.PaletteColor = .gray(level: 8)
	public var disabledBG: Console.PaletteColor = .default
	public var selectedSubIndex: Int? = nil

	public var hasDropDown: Bool { !(subMenu?.isEmpty ?? true) }

    public init(x: Int, y: Int, title: String, commandId: Int, subMenu: [MenuView]? = nil) {
        self.title = title
        self.commandId = commandId
        self.subMenu = subMenu
        super.init(frame: Rect(x, y, title.count + 2, 1))
        isFocusable = true
    }

	    public override func draw(into surface: Surface, clip: Rect) {
	        let displayTitle = " \(title) "
		let fgColor: Console.PaletteColor
		let bgColor: Console.PaletteColor
		if isEnabled {
			if hasFocus {
				fgColor = highlightFG
				bgColor = highlightBG
			} else {
				fgColor = normalFG
				bgColor = normalBG
			}
		} else {
			fgColor = disabledFG
			bgColor = disabledBG
		}

	        surface.putString(x: frame.x, y: frame.y, text: displayTitle, fg: fgColor, bg: bgColor)

	        if isChecked {
	            // Draw a checkmark or similar indicator
	            surface.putString(x: frame.x + frame.w - 2, y: frame.y, text: "✓", fg: fgColor, bg: bgColor)
	        }

		if hasFocus, let entries = subMenu, !entries.isEmpty {
			drawDropDown(entries, into: surface, clip: clip)
		}
	    }

	public func clearSelection() {
		selectedSubIndex = nil
	}

	public func focusFirstItem() -> Bool {
		guard let entries = subMenu, !entries.isEmpty else {
			selectedSubIndex = nil
			return false
		}
		selectedSubIndex = 0
		return true
	}

	public func adjustSelection(by delta: Int, wrap: Bool = true) -> Bool {
		guard let entries = subMenu, !entries.isEmpty else {
			selectedSubIndex = nil
			return false
		}
		let count = entries.count
		if count == 0 { return false }
		let current = selectedSubIndex ?? 0
		var next = current + delta
		if wrap {
			next = (next % count + count) % count
		} else {
			next = min(max(next, 0), count - 1)
		}
		selectedSubIndex = next
		return true
	}

	public func currentSubItem() -> MenuView? {
		guard let idx = selectedSubIndex,
		      let entries = subMenu,
		      idx >= 0, idx < entries.count else { return nil }
		return entries[idx]
	}

	private func drawDropDown(_ entries: [MenuView], into surface: Surface, clip: Rect) {
		let baseX = frame.x
		let baseY = frame.y + 1
		let maximal = entries.map { $0.title.count + 4 }.max() ?? 0
		let availableWidth = max(0, surface.width - baseX)
		let dropWidth = min(max(frame.w, maximal), availableWidth)
		if dropWidth <= 0 { return }

		for (idx, entry) in entries.enumerated() {
			let y = baseY + idx
			if y >= surface.height { break }
			if y < clip.y || y >= clip.y + clip.h { continue }

			let isSelected = (selectedSubIndex == idx)
			let fg = isSelected ? highlightFG : normalFG
			let bg = isSelected ? highlightBG : normalBG
			let padded = " " + entry.title.padding(toLength: dropWidth - 2, withPad: " ", startingAt: 0) + " "
			let rowRect = Rect(baseX, y, dropWidth, 1)
			let intersect = rowRect.intersection(clip)
			if !intersect.isEmpty {
				surface.fill(intersect, cell: .init(" ", fg: fg, bg: bg))
				let visibleText = String(padded.prefix(intersect.w))
				surface.putString(x: intersect.x, y: intersect.y, text: visibleText, fg: fg, bg: bg)
			}
		}
	}
}
