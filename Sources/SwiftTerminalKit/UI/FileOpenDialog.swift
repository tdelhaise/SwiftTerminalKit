import Foundation

public final class FileOpenDialog: Dialog {
    private enum FocusableElement: CaseIterable {
        case nameField
        case fileList
        case directoryList
        case openButton
        case cancelButton
    }

    private enum Selection {
        case file(String)
        case directory(String)
    }

    private struct LayoutMetrics {
        let contentX: Int
        let contentWidth: Int
        let nameLabelY: Int
        let filterFieldX: Int
        let filterFieldY: Int
        let filterFieldWidth: Int
        let filesLabelY: Int
        let listY: Int
        let listHeight: Int
        let fileColumnWidth: Int
        let directoryColumnWidth: Int
        let dividerX: Int
        let directoryColumnX: Int
        let buttonY: Int
        let openButtonX: Int
        let openButtonWidth: Int
        let cancelButtonX: Int
        let cancelButtonWidth: Int
        let statusY1: Int
        let statusY2: Int
    }

    private let dropDownIndicatorWidth = 2
    private var files: [String] = []
    private var directories: [String] = []
    private var selectedFileIndex = 0
    private var selectedDirectoryIndex = 0
    private var fileScrollOffset = 0
    private var directoryScrollOffset = 0

    private var filterText: String
    private var filterCursor: Int
    private var filterViewOffset: Int = 0
    private var filterRegex: NSRegularExpression?

    private var currentPath: String
    private var completion: ((URL?) -> Void)?
    private var internalFocus: FocusableElement = .fileList
    private var selection: Selection?
    private var statusPathLine: String = ""
    private var statusDetailLine: String = ""

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, yyyy  hh:mma"
        return formatter
    }()

    public init(frame: Rect, path: String = ".", initialPattern: String = "*.*") {
        self.currentPath = URL(fileURLWithPath: path).standardizedFileURL.path
        self.filterText = initialPattern
        self.filterCursor = initialPattern.count
        super.init(frame: frame, title: "Open file")
        backgroundColor = .gray(level: 18)
        foregroundColor = .named(.brightWhite)
        isFocusable = true
        updateFilterRegex()
        reloadContents(resetSelection: true)
    }

    public override func draw(into surface: Surface, clip: Rect) {
        super.draw(into: surface, clip: clip)
        let layout = computeLayout()
        ensureSelectionVisible(layout: layout)
        drawNameSection(layout, into: surface)
        drawLists(layout, into: surface)
        drawStatus(layout, into: surface)
    }

    public override func cursorPosition() -> (x: Int, y: Int)? {
        guard hasFocus, internalFocus == .nameField else { return nil }
        let layout = computeLayout()
        let textWidth = max(1, layout.filterFieldWidth - dropDownIndicatorWidth)
        adjustFilterViewOffset(visibleWidth: textWidth)
        let visibleCursor = min(textWidth - 1, max(0, filterCursor - filterViewOffset))
        let cursorX = layout.filterFieldX + visibleCursor
        return (cursorX, layout.filterFieldY)
    }

    public override func handle(event: KeyEvent) -> Bool {
        switch event.keyCode {
        case .tab:
            cycleFocus(forward: !event.mods.contains(.shift))
            return true

        case .up:
            moveSelection(delta: -1)
            return true
        case .down:
            moveSelection(delta: 1)
            return true
        case .pageUp:
            let height = computeLayout().listHeight
            moveSelection(delta: -max(1, height))
            return true
        case .pageDown:
            let height = computeLayout().listHeight
            moveSelection(delta: max(1, height))
            return true
        case .home:
            jumpToEdge(start: true)
            return true
        case .end:
            jumpToEdge(start: false)
            return true

        case .left:
            handleHorizontalMovement(left: true)
            return true
        case .right:
            handleHorizontalMovement(left: false)
            return true

        case .enter:
            handleEnterKey()
            return true

        case .escape:
            completion?(nil)
            return true

        case .backspace:
            if internalFocus == .nameField {
                deleteBackward()
            }
            return true
        case .delete:
            if internalFocus == .nameField {
                deleteForward()
            }
            return true

        case .char(let ch):
            if internalFocus == .nameField &&
                !event.mods.contains(.ctrl) &&
                !event.mods.contains(.alt) &&
                !event.mods.contains(.meta) {
                insertCharacter(ch)
            }
            return true

        default:
            return true
        }
    }

    public func present(on screen: Screen, completion: @escaping (URL?) -> Void) {
        self.completion = completion
        screen.addView(self)
        screen.setFocus(self)
        invalidate()
    }

    // MARK: - Drawing helpers

    private func drawNameSection(_ layout: LayoutMetrics, into surface: Surface) {
        surface.putString(
            x: layout.contentX,
            y: layout.nameLabelY,
            text: "Name",
            fg: .named(.brightWhite),
            bg: backgroundColor
        )
        drawFilterField(layout, into: surface)
        drawButtons(layout, into: surface)
    }

    private func drawFilterField(_ layout: LayoutMetrics, into surface: Surface) {
        let textWidth = max(1, layout.filterFieldWidth - dropDownIndicatorWidth)
        adjustFilterViewOffset(visibleWidth: textWidth)
        let fieldFG: Console.PaletteColor = .named(.brightWhite)
        let fieldBG: Console.PaletteColor = internalFocus == .nameField ? .named(.blue) : .named(.brightBlue)
        let textRect = Rect(layout.filterFieldX, layout.filterFieldY, textWidth, 1)
        surface.fill(textRect, cell: .init(" ", fg: fieldFG, bg: fieldBG))

        let startIndex = filterText.index(filterText.startIndex, offsetBy: min(filterViewOffset, filterText.count))
        let endIndex = filterText.index(startIndex, offsetBy: min(textWidth, filterText.count - filterViewOffset), limitedBy: filterText.endIndex) ?? filterText.endIndex
        var visible = String(filterText[startIndex..<endIndex])
        if visible.count < textWidth {
            visible += String(repeating: " ", count: textWidth - visible.count)
        } else if visible.count > textWidth {
            visible = String(visible.prefix(textWidth))
        }
        surface.putString(x: layout.filterFieldX, y: layout.filterFieldY, text: visible, fg: fieldFG, bg: fieldBG)

        // Draw small drop-down indicator
        let arrowX = layout.filterFieldX + textWidth
        let arrowBG: Console.PaletteColor = internalFocus == .nameField ? .named(.green) : .named(.brightGreen)
        let arrowRect = Rect(arrowX, layout.filterFieldY, dropDownIndicatorWidth, 1)
        surface.fill(arrowRect, cell: .init(" ", fg: .named(.black), bg: arrowBG))
        surface.putString(x: arrowX + max(0, dropDownIndicatorWidth - 1), y: layout.filterFieldY, text: "v", fg: .named(.black), bg: arrowBG)
    }

    private func drawButtons(_ layout: LayoutMetrics, into surface: Surface) {
        drawButton(
            into: surface,
            text: "Open",
            x: layout.openButtonX,
            y: layout.buttonY,
            width: layout.openButtonWidth,
            focused: internalFocus == .openButton
        )
        drawButton(
            into: surface,
            text: "Cancel",
            x: layout.cancelButtonX,
            y: layout.buttonY,
            width: layout.cancelButtonWidth,
            focused: internalFocus == .cancelButton
        )
    }

    private func drawButton(into surface: Surface, text: String, x: Int, y: Int, width: Int, focused: Bool) {
        guard width > 0 else { return }
        let bg: Console.PaletteColor = focused ? .named(.brightGreen) : .named(.green)
        let fg: Console.PaletteColor = .named(.black)
        var label = " \(text) "
        if label.count < width {
            label += String(repeating: " ", count: width - label.count)
        } else if label.count > width {
            label = String(label.prefix(width))
        }

        surface.putString(x: x, y: y, text: label, fg: fg, bg: bg)

        // Simple drop shadow
        if x + width < frame.x + frame.w - 1 {
            surface.putString(x: x + width, y: y, text: " ", fg: .named(.black), bg: .named(.black))
        }
        if y + 1 < frame.y + frame.h - 1 {
            let available = max(0, frame.x + frame.w - 1 - x)
            if available > 0 {
                let shadow = String(repeating: " ", count: min(width, available))
                surface.putString(x: x, y: y + 1, text: shadow, fg: .named(.black), bg: .named(.black))
            }
        }
    }

    private func drawLists(_ layout: LayoutMetrics, into surface: Surface) {
        surface.putString(
            x: layout.contentX,
            y: layout.filesLabelY,
            text: "Files",
            fg: .named(.brightWhite),
            bg: backgroundColor
        )
        drawFileColumn(layout, into: surface)
        drawDirectoryColumn(layout, into: surface)
        drawDivider(layout, into: surface)
    }

    private func drawFileColumn(_ layout: LayoutMetrics, into surface: Surface) {
        let baseBG: Console.PaletteColor = .named(.cyan)
        let fileRect = Rect(layout.contentX, layout.listY, layout.fileColumnWidth, layout.listHeight)
        surface.fill(fileRect, cell: .init(" ", fg: .named(.black), bg: baseBG))
        for row in 0..<layout.listHeight {
            let index = fileScrollOffset + row
            guard files.indices.contains(index) else { continue }
            let name = padded(files[index], width: layout.fileColumnWidth)
            let isSelected = index == selectedFileIndex
            let hasFocus = (internalFocus == .fileList)
            let colors = colorsForRow(
                isSelected: isSelected,
                focused: hasFocus,
                baseFG: .named(.black),
                baseBG: baseBG
            )
            surface.putString(
                x: layout.contentX,
                y: layout.listY + row,
                text: name,
                fg: colors.fg,
                bg: colors.bg
            )
        }
    }

    private func drawDirectoryColumn(_ layout: LayoutMetrics, into surface: Surface) {
        let baseBG: Console.PaletteColor = .named(.brightCyan)
        let dirRect = Rect(layout.directoryColumnX, layout.listY, layout.directoryColumnWidth, layout.listHeight)
        surface.fill(dirRect, cell: .init(" ", fg: .named(.black), bg: baseBG))
        for row in 0..<layout.listHeight {
            let index = directoryScrollOffset + row
            guard directories.indices.contains(index) else { continue }
            let displayName = directories[index]
            let raw = displayName + "\\"
            let name = padded(raw, width: layout.directoryColumnWidth)
            let isSelected = index == selectedDirectoryIndex
            let hasFocus = (internalFocus == .directoryList)
            let colors = colorsForRow(
                isSelected: isSelected,
                focused: hasFocus,
                baseFG: .named(.black),
                baseBG: baseBG
            )
            surface.putString(
                x: layout.directoryColumnX,
                y: layout.listY + row,
                text: name,
                fg: colors.fg,
                bg: colors.bg
            )
        }
    }

    private func drawDivider(_ layout: LayoutMetrics, into surface: Surface) {
        let dividerRect = Rect(layout.dividerX, layout.listY, 1, layout.listHeight)
        surface.fill(dividerRect, cell: .init("│", fg: .named(.brightBlack), bg: backgroundColor))
    }

    private func drawStatus(_ layout: LayoutMetrics, into surface: Surface) {
        let statusFG: Console.PaletteColor = .named(.brightWhite)
        let statusBG: Console.PaletteColor = .named(.blue)

        let firstRect = Rect(layout.contentX, layout.statusY1, layout.contentWidth, 1)
        surface.fill(firstRect, cell: .init(" ", fg: statusFG, bg: statusBG))
        let pathText = ellipsized(statusPathLine, width: layout.contentWidth)
        surface.putString(x: layout.contentX, y: layout.statusY1, text: pathText, fg: statusFG, bg: statusBG)

        let secondRect = Rect(layout.contentX, layout.statusY2, layout.contentWidth, 1)
        surface.fill(secondRect, cell: .init(" ", fg: statusFG, bg: statusBG))
        let detailText = ellipsized(statusDetailLine, width: layout.contentWidth)
        surface.putString(x: layout.contentX, y: layout.statusY2, text: detailText, fg: statusFG, bg: statusBG)
    }

    // MARK: - Layout

    private func computeLayout() -> LayoutMetrics {
        let contentMargin = 2
        let contentX = frame.x + contentMargin
        let contentWidth = max(32, frame.w - contentMargin * 2)
        let nameLabelY = frame.y + 2
        let filterFieldY = nameLabelY + 1
        let buttonY = filterFieldY
        let filesLabelY = filterFieldY + 2
        let listY = filesLabelY + 1
        let statusY2 = frame.y + frame.h - 2
        let statusY1 = statusY2 - 1
        let listHeight = max(1, statusY1 - listY)

        let labelWidth = 6
        let labelGap = 1
        let filterFieldX = contentX + labelWidth + labelGap

        let openButtonWidth = max(10, "Open".count + 4)
        let cancelButtonWidth = max(10, "Cancel".count + 4)
        let buttonSpacing = 2
        var filterFieldWidth = max(12, contentWidth - (filterFieldX - contentX) - openButtonWidth - cancelButtonWidth - buttonSpacing)
        var openButtonX = filterFieldX + filterFieldWidth + 1
        var cancelButtonX = openButtonX + openButtonWidth + buttonSpacing
        let maxX = contentX + contentWidth
        if cancelButtonX + cancelButtonWidth > maxX {
            let overflow = cancelButtonX + cancelButtonWidth - maxX
            filterFieldWidth = max(8, filterFieldWidth - overflow)
            openButtonX = filterFieldX + filterFieldWidth + 1
            cancelButtonX = openButtonX + openButtonWidth + buttonSpacing
        }

        let dividerThickness = 1
        var directoryWidth = max(12, contentWidth / 3)
        var fileWidth = contentWidth - directoryWidth - dividerThickness
        if fileWidth < 12 {
            let deficit = 12 - fileWidth
            directoryWidth = max(8, directoryWidth - deficit)
            fileWidth = contentWidth - directoryWidth - dividerThickness
        }
        let dividerX = contentX + fileWidth
        let directoryX = dividerX + dividerThickness

        return LayoutMetrics(
            contentX: contentX,
            contentWidth: contentWidth,
            nameLabelY: nameLabelY,
            filterFieldX: filterFieldX,
            filterFieldY: filterFieldY,
            filterFieldWidth: filterFieldWidth,
            filesLabelY: filesLabelY,
            listY: listY,
            listHeight: listHeight,
            fileColumnWidth: fileWidth,
            directoryColumnWidth: directoryWidth,
            dividerX: dividerX,
            directoryColumnX: directoryX,
            buttonY: buttonY,
            openButtonX: openButtonX,
            openButtonWidth: openButtonWidth,
            cancelButtonX: cancelButtonX,
            cancelButtonWidth: cancelButtonWidth,
            statusY1: statusY1,
            statusY2: statusY2
        )
    }

    // MARK: - Selection management

    private func moveSelection(delta: Int) {
        switch internalFocus {
        case .fileList:
            guard !files.isEmpty else { return }
            selectedFileIndex = max(0, min(files.count - 1, selectedFileIndex + delta))
            selection = .file(files[selectedFileIndex])
        case .directoryList:
            guard !directories.isEmpty else { return }
            selectedDirectoryIndex = max(0, min(directories.count - 1, selectedDirectoryIndex + delta))
            selection = .directory(directories[selectedDirectoryIndex])
        default:
            return
        }
        ensureSelectionVisible()
        updateStatusLines()
        invalidate()
    }

    private func jumpToEdge(start: Bool) {
        switch internalFocus {
        case .fileList:
            guard !files.isEmpty else { return }
            selectedFileIndex = start ? 0 : files.count - 1
            selection = .file(files[selectedFileIndex])
        case .directoryList:
            guard !directories.isEmpty else { return }
            selectedDirectoryIndex = start ? 0 : directories.count - 1
            selection = .directory(directories[selectedDirectoryIndex])
        default:
            return
        }
        ensureSelectionVisible()
        updateStatusLines()
        invalidate()
    }

    private func handleHorizontalMovement(left: Bool) {
        switch internalFocus {
        case .nameField:
            moveFilterCursor(by: left ? -1 : 1)
        case .fileList where !left:
            if !directories.isEmpty {
                internalFocus = .directoryList
                updateSelectionFromCurrentFocus()
            }
        case .directoryList where left:
            if !files.isEmpty {
                internalFocus = .fileList
                updateSelectionFromCurrentFocus()
            }
        case .openButton:
            if left {
                internalFocus = directories.isEmpty ? .fileList : .directoryList
            } else {
                internalFocus = .cancelButton
            }
        case .cancelButton:
            if left {
                internalFocus = .openButton
            }
        default:
            break
        }
        invalidate()
    }

    private func handleEnterKey() {
        switch internalFocus {
        case .nameField:
            if filterText.contains("*") || filterText.contains("?") {
                internalFocus = files.isEmpty ? .directoryList : .fileList
                updateSelectionFromCurrentFocus()
                invalidate()
            } else {
                openTypedEntryIfPossible()
            }
        case .fileList, .openButton:
            openSelection()
        case .directoryList:
            openSelection()
        case .cancelButton:
            completion?(nil)
        }
    }

    private func openSelection() {
        guard let selection else { return }
        switch selection {
        case .file(let name):
            let url = URL(fileURLWithPath: currentPath).appendingPathComponent(name)
            completion?(url)
        case .directory(let name):
            changeDirectory(named: name)
        }
    }

    private func openTypedEntryIfPossible() {
        let trimmed = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let fullPath = (currentPath as NSString).appendingPathComponent(trimmed)
        if FileManager.default.fileExists(atPath: fullPath) {
            completion?(URL(fileURLWithPath: fullPath))
        }
    }

    private func changeDirectory(named name: String) {
        var nextPath: String
        if name == ".." {
            nextPath = (currentPath as NSString).deletingLastPathComponent
            if nextPath.isEmpty { nextPath = "/" }
        } else {
            nextPath = (currentPath as NSString).appendingPathComponent(name)
        }
        currentPath = URL(fileURLWithPath: nextPath).standardizedFileURL.path
        reloadContents(resetSelection: true)
    }

    private func ensureSelectionVisible(layout: LayoutMetrics? = nil) {
        let metrics = layout ?? computeLayout()
        let height = max(1, metrics.listHeight)
        if !files.isEmpty {
            if selectedFileIndex < fileScrollOffset { fileScrollOffset = selectedFileIndex }
            if selectedFileIndex >= fileScrollOffset + height {
                fileScrollOffset = selectedFileIndex - height + 1
            }
            let maxOffset = max(0, files.count - height)
            fileScrollOffset = min(fileScrollOffset, maxOffset)
        } else {
            fileScrollOffset = 0
        }

        if !directories.isEmpty {
            if selectedDirectoryIndex < directoryScrollOffset { directoryScrollOffset = selectedDirectoryIndex }
            if selectedDirectoryIndex >= directoryScrollOffset + height {
                directoryScrollOffset = selectedDirectoryIndex - height + 1
            }
            let maxOffset = max(0, directories.count - height)
            directoryScrollOffset = min(directoryScrollOffset, maxOffset)
        } else {
            directoryScrollOffset = 0
        }
    }

    private func colorsForRow(
        isSelected: Bool,
        focused: Bool,
        baseFG: Console.PaletteColor,
        baseBG: Console.PaletteColor
    ) -> (fg: Console.PaletteColor, bg: Console.PaletteColor) {
        if isSelected {
            if focused {
                return (.named(.yellow), .named(.blue))
            } else {
                return (.named(.brightYellow), .gray(level: 14))
            }
        }
        return (baseFG, baseBG)
    }

    private func cycleFocus(forward: Bool) {
        guard let currentIndex = FocusableElement.allCases.firstIndex(of: internalFocus) else {
            internalFocus = .nameField
            return
        }
        let count = FocusableElement.allCases.count
        var nextIndex = currentIndex
        for _ in 0..<count {
            nextIndex = (nextIndex + (forward ? 1 : -1) + count) % count
            let candidate = FocusableElement.allCases[nextIndex]
            if candidate == .fileList && files.isEmpty { continue }
            if candidate == .directoryList && directories.isEmpty { continue }
            internalFocus = candidate
            break
        }
        updateSelectionFromCurrentFocus()
        invalidate()
    }

    private func updateSelectionFromCurrentFocus() {
        switch internalFocus {
        case .fileList:
            if files.indices.contains(selectedFileIndex) {
                selection = .file(files[selectedFileIndex])
            } else {
                selection = files.first.map { .file($0) }
            }
        case .directoryList:
            if directories.indices.contains(selectedDirectoryIndex) {
                selection = .directory(directories[selectedDirectoryIndex])
            } else {
                selection = directories.first.map { .directory($0) }
            }
        default:
            if selection == nil {
                if let file = files.first {
                    selection = .file(file)
                } else if let dir = directories.first {
                    selection = .directory(dir)
                }
            }
        }
        updateStatusLines()
    }

    // MARK: - Filter editing

    private func insertCharacter(_ ch: Character) {
        let idx = filterText.index(filterText.startIndex, offsetBy: filterCursor)
        filterText.insert(ch, at: idx)
        filterCursor += 1
        filterDidChange()
    }

    private func deleteBackward() {
        guard filterCursor > 0 else { return }
        let idx = filterText.index(filterText.startIndex, offsetBy: filterCursor)
        let prev = filterText.index(before: idx)
        filterText.remove(at: prev)
        filterCursor -= 1
        filterDidChange()
    }

    private func deleteForward() {
        guard filterCursor < filterText.count else { return }
        let idx = filterText.index(filterText.startIndex, offsetBy: filterCursor)
        filterText.remove(at: idx)
        filterDidChange()
    }

    private func moveFilterCursor(by delta: Int) {
        let next = max(0, min(filterText.count, filterCursor + delta))
        guard next != filterCursor else { return }
        filterCursor = next
        invalidate()
    }

    private func filterDidChange() {
        filterCursor = max(0, min(filterCursor, filterText.count))
        updateFilterRegex()
        reloadContents(resetSelection: true)
    }

    private func adjustFilterViewOffset(visibleWidth: Int) {
        guard visibleWidth > 0 else {
            filterViewOffset = 0
            return
        }
        if filterCursor < filterViewOffset {
            filterViewOffset = filterCursor
        } else if filterCursor > filterViewOffset + visibleWidth {
            filterViewOffset = filterCursor - visibleWidth
        }
        let maxOffset = max(0, filterText.count - visibleWidth)
        filterViewOffset = min(filterViewOffset, maxOffset)
    }

    private func updateFilterRegex() {
        let pattern = filterText.isEmpty ? "*" : filterText
        var regexPattern = "^"
        for ch in pattern {
            switch ch {
            case "*":
                regexPattern += ".*"
            case "?":
                regexPattern += "."
            default:
                regexPattern += NSRegularExpression.escapedPattern(for: String(ch))
            }
        }
        regexPattern += "$"
        filterRegex = try? NSRegularExpression(pattern: regexPattern, options: [.caseInsensitive])
    }

    // MARK: - Data loading

    private func reloadContents(resetSelection: Bool) {
        let directoryURL = URL(fileURLWithPath: currentPath)
        var loadedFiles: [String] = []
        var loadedDirs: [String] = []
        if let contents = try? FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.isDirectoryKey], options: []) {
            for url in contents {
                let name = url.lastPathComponent
                var isDir: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                if exists && isDir.boolValue {
                    loadedDirs.append(name)
                } else if exists && matchesFilter(name) {
                    loadedFiles.append(name)
                }
            }
        }
        loadedFiles.sort()
        loadedDirs.sort()
        directories = loadedDirs + [".."]
        files = loadedFiles
        if resetSelection {
            selectedFileIndex = 0
            selectedDirectoryIndex = 0
            fileScrollOffset = 0
            directoryScrollOffset = 0
            selection = nil
        }
        if files.isEmpty && internalFocus == .fileList {
            internalFocus = .directoryList
        }
        updateSelectionFromCurrentFocus()
        updateStatusLines()
        ensureSelectionVisible()
        invalidate()
    }

    private func matchesFilter(_ name: String) -> Bool {
        guard let regex = filterRegex else { return true }
        let range = NSRange(location: 0, length: name.utf16.count)
        return regex.firstMatch(in: name, options: [], range: range) != nil
    }

    // MARK: - Status lines

    private func updateStatusLines() {
        let displayPattern = filterText.isEmpty ? "*" : filterText
        statusPathLine = (currentPath as NSString).appendingPathComponent(displayPattern)
        guard let selection else {
            statusDetailLine = "Select a file to open"
            return
        }
        switch selection {
        case .file(let name):
            statusDetailLine = detailText(forFile: name)
        case .directory(let name):
            if name == ".." {
                statusDetailLine = "..\\  <DIR>"
            } else {
                statusDetailLine = "\(name)\\  <DIR>"
            }
        }
    }

    private func detailText(forFile name: String) -> String {
        let path = (currentPath as NSString).appendingPathComponent(name)
        if let attributes = try? FileManager.default.attributesOfItem(atPath: path) {
            let sizeValue = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
            let date = attributes[.modificationDate] as? Date
            var dateText = ""
            if let date {
                dateText = Self.dateFormatter.string(from: date)
                dateText = dateText
                    .replacingOccurrences(of: "AM", with: "a")
                    .replacingOccurrences(of: "PM", with: "p")
            }
            if dateText.isEmpty {
                return "\(name)  \(sizeValue) bytes"
            } else {
                return "\(name)  \(sizeValue)  \(dateText)"
            }
        }
        return name
    }

    // MARK: - String helpers

    private func padded(_ text: String, width: Int) -> String {
        guard width > 0 else { return "" }
        if text.count >= width {
            return String(text.prefix(width))
        }
        return text + String(repeating: " ", count: width - text.count)
    }

    private func ellipsized(_ text: String, width: Int) -> String {
        guard width > 0 else { return "" }
        if text.count <= width {
            let padding = width - text.count
            return text + String(repeating: " ", count: padding)
        }
        if width <= 3 {
            return String(text.suffix(width))
        }
        return "..." + String(text.suffix(width - 3))
    }
}
