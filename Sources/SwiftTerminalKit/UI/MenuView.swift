
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

        let rowRect = Rect(frame.x, frame.y, frame.w, 1).intersection(clip)
        if rowRect.w > 0 {
            surface.fill(rowRect, cell: .init(" ", fg: fgColor, bg: bgColor))
            let padded = displayTitle.padding(toLength: frame.w, withPad: " ", startingAt: 0)
            let offset = rowRect.x - frame.x
            if offset < padded.count {
                let start = padded.index(padded.startIndex, offsetBy: offset)
                let visible = String(padded[start...].prefix(rowRect.w))
                surface.putString(x: rowRect.x, y: frame.y, text: visible, fg: fgColor, bg: bgColor)
            }
        }

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
        let maxTitle = entries.map { $0.title.count }.max() ?? 0
        let availableWidth = max(0, surface.width - baseX)
        guard availableWidth >= 3 else { return }

	        let desiredContent = max(frame.w - 2, maxTitle + 2)
	        let contentWidth = max(1, min(desiredContent, availableWidth - 2))
	        let totalWidth = contentWidth + 2

        let topRow = Rect(baseX, baseY, totalWidth, 1)
        let topClip = topRow.intersection(clip)
        if !topClip.isEmpty {
            surface.fill(topClip, cell: .init(" ", fg: normalFG, bg: normalBG))
            let topLine = "┌" + String(repeating: "─", count: contentWidth) + "┐"
            let startOffset = topClip.x - baseX
            if startOffset < topLine.count {
                let startIndex = topLine.index(topLine.startIndex, offsetBy: startOffset)
                let visible = String(topLine[startIndex...].prefix(topClip.w))
                surface.putString(x: topClip.x, y: baseY, text: visible, fg: normalFG, bg: normalBG)
            }
        }

        let bottomY = baseY + entries.count + 1
        if bottomY < surface.height {
            let bottomRect = Rect(baseX, bottomY, totalWidth, 1)
            let bottomClip = bottomRect.intersection(clip)
            if !bottomClip.isEmpty {
                surface.fill(bottomClip, cell: .init(" ", fg: normalFG, bg: normalBG))
                let bottomLine = "└" + String(repeating: "─", count: contentWidth) + "┘"
                let startOffset = bottomClip.x - baseX
                if startOffset < bottomLine.count {
                    let startIndex = bottomLine.index(bottomLine.startIndex, offsetBy: startOffset)
                    let visible = String(bottomLine[startIndex...].prefix(bottomClip.w))
                    surface.putString(x: bottomClip.x, y: bottomY, text: visible, fg: normalFG, bg: normalBG)
                }
            }
        }

        for (idx, entry) in entries.enumerated() {
            let y = baseY + 1 + idx
            if y >= surface.height { break }
            if y < clip.y || y >= clip.y + clip.h { continue }

            let isSelected = (selectedSubIndex == idx)
            let rowFG = isSelected ? highlightFG : normalFG
            let rowBG = isSelected ? highlightBG : normalBG

            var inner = " " + entry.title + " "
            if inner.count < contentWidth {
                inner = inner.padding(toLength: contentWidth, withPad: " ", startingAt: 0)
            } else if inner.count > contentWidth {
                inner = String(inner.prefix(contentWidth))
            }

            let interiorRect = Rect(baseX + 1, y, contentWidth, 1).intersection(clip)
            if interiorRect.w > 0 {
                surface.fill(interiorRect, cell: .init(" ", fg: rowFG, bg: rowBG))
                let offset = interiorRect.x - (baseX + 1)
                if offset < inner.count {
                    let start = inner.index(inner.startIndex, offsetBy: offset)
                    let visible = String(inner[start...].prefix(interiorRect.w))
                    surface.putString(x: interiorRect.x, y: y, text: visible, fg: rowFG, bg: rowBG)
                }
            }

            let borderFG = normalFG
            let borderBG = normalBG
            let leftClip = Rect(baseX, y, 1, 1).intersection(clip)
            if !leftClip.isEmpty {
                surface.fill(leftClip, cell: .init(" ", fg: borderFG, bg: borderBG))
                surface.putString(x: leftClip.x, y: y, text: "│", fg: borderFG, bg: borderBG)
            }
            let rightClip = Rect(baseX + totalWidth - 1, y, 1, 1).intersection(clip)
            if !rightClip.isEmpty {
                surface.fill(rightClip, cell: .init(" ", fg: borderFG, bg: borderBG))
                surface.putString(x: rightClip.x, y: y, text: "│", fg: borderFG, bg: borderBG)
            }
        }
	}
}
