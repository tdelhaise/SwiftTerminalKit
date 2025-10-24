import Foundation

// Modificateurs unifiés (côté API publique)
public struct KeyMods: OptionSet {
	public let rawValue: Int
	public init(rawValue: Int) { self.rawValue = rawValue }
	public static let shift = KeyMods(rawValue: 1 << 0)
	public static let ctrl  = KeyMods(rawValue: 1 << 1)
	public static let alt   = KeyMods(rawValue: 1 << 2)
	public static let meta  = KeyMods(rawValue: 1 << 3)
}

// Code de touche unifié (NE PAS entrer en collision avec Terminal.Key)
public enum KeyCode {
	case char(Character)
	case left, right, up, down
	case home, end, pageUp, pageDown
	case insert, delete, backspace
	case tab, enter, escape
	case function(Int)
}

// Événement clavier unifié
public struct KeyEvent {
	public let keyCode: KeyCode
	public let mods: KeyMods
	public let utf8: [UInt8]    // charge utile brute si texte
	public init(_ key: KeyCode, mods: KeyMods = [], utf8: [UInt8] = []) {
		self.keyCode = key; self.mods = mods; self.utf8 = utf8
	}
}

// Evénements d'entrée unifiés exposés par SwiftTerminalKit
public enum InputEvent {
	case key(KeyEvent)
	case mouse(x: Int, y: Int, button: MouseButton, type: MouseEventType, mods: KeyMods)
	case resize(cols: Int, rows: Int)
	case paste(Data)
	case focusGained
	case focusLost
}
