import Foundation

// Evénements d'entrée unifiés exposés par SwiftTerminalKit
public enum InputEvent {
	case key(KeyEvent)
	case resize(cols: Int, rows: Int)
	case mouse(x: Int, y: Int, button: MouseButton, type: MouseEventType, mods: KeyMods)
	case paste(Data)
	case focusGained
	case focusLost
}
