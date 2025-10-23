import Foundation

/// Cross-platform modifier mask used by SwiftTerminalKit.
public struct KeyMods: OptionSet, Codable, Hashable {
	public let rawValue: Int
	public init(rawValue: Int) { self.rawValue = rawValue }
	public static let shift = KeyMods(rawValue: 1<<0)
	public static let ctrl  = KeyMods(rawValue: 1<<1)
	public static let alt   = KeyMods(rawValue: 1<<2)
	public static let meta  = KeyMods(rawValue: 1<<3)
}

/// Virtual key codes + text channel (utf8) à la Turbo Vision.
public enum KeyCode: Equatable, Hashable {
	case char(Character)       // printable or control-as-char
	case enter, esc, backspace, tab, shiftTab
	case up, down, left, right
	case home, end, pageUp, pageDown
	case insert, delete
	case f(Int)                // F1..F12
}

public struct KeyEvent: Equatable, Hashable {
	public var keyCode: KeyCode
	public var mods: KeyMods
	/// up to 4 bytes of utf8 for text input (printable)
	public var utf8: [UInt8]
	public init(_ keyCode: KeyCode, mods: KeyMods = [], utf8: [UInt8] = []) {
		self.keyCode = keyCode; self.mods = mods; self.utf8 = utf8
	}
}

/// Événements d’entrée “unifiés” côté SwiftTerminalKit.
public enum InputEvent: Equatable {
	case key(KeyEvent)
	case paste(String)  // aligne sur Event.paste(String)
	case mouse(x: Int, y: Int, button: MouseButton, type: MouseEventType, mods: KeyMods)
	case resize(cols: Int, rows: Int)
}

public extension KeyEvent {
	/// Adaptateur depuis ton `Event` global (défini dans Terminal.swift).
	static func fromConsoleEvent(_ ev: Event) -> KeyEvent? {
		switch ev {
			case .key(let k, let m):
				var mods = modsFromConsole(m)
				
				switch k {
					case .char("\t"):
						if mods.contains(.shift) {
							mods.remove(.shift)
							return KeyEvent(.shiftTab, mods: mods, utf8: [0x09])
						}
						return KeyEvent(.tab, mods: mods, utf8: [0x09])
						
					case .tab:
						if mods.contains(.shift) {
							mods.remove(.shift)
							return KeyEvent(.shiftTab, mods: mods, utf8: [0x09])
						}
						return KeyEvent(.tab, mods: mods, utf8: [0x09])
						
					case .enter:
						return KeyEvent(.enter, mods: mods, utf8: [0x0D])
						
					case .backspace:
						return KeyEvent(.backspace, mods: mods, utf8: [0x08])
						
					case .esc:
						return KeyEvent(.esc, mods: mods, utf8: [0x1B])
						
					case .char(let c):
						var modsNorm = mods
						if let u = c.unicodeScalars.first {
							let v = u.value
							// ASCII control: 1..26  => ^A..^Z
							if (1...26).contains(v) {
								let base = Character(UnicodeScalar(UInt32(96) + v)!) // 96 = '`' => a..z
								modsNorm.insert(.ctrl)
								return KeyEvent(.char(base), mods: modsNorm, utf8: [UInt8(v)])
							}
						}
						// Sinon, chemin normal : lettre avec (ou sans) modifieurs
						// (On peut normaliser en minuscule si tu préfères)
						let u8 = Array(String(c).utf8)
						return KeyEvent(.char(c), mods: modsNorm, utf8: u8)

					case .up:    return KeyEvent(.up, mods: mods)
					case .down:  return KeyEvent(.down, mods: mods)
					case .left:  return KeyEvent(.left, mods: mods)
					case .right: return KeyEvent(.right, mods: mods)
						
						// Décommente si ton `Key` expose ces cas :
						// case .home:     return KeyEvent(.home, mods: mods)
						// case .end:      return KeyEvent(.end, mods: mods)
						// case .pageUp:   return KeyEvent(.pageUp, mods: mods)
						// case .pageDown: return KeyEvent(.pageDown, mods: mods)
						// case .insert:   return KeyEvent(.insert, mods: mods)
						// case .delete:   return KeyEvent(.delete, mods: mods)
						// case .f(let n): return KeyEvent(.f(n), mods: mods)
						
					default:
						return nil
				}
				
			case .resize, .paste, .mouse, .focusGained, .focusLost:
				// Ces événements sont gérés plus haut (EventQueue) ou ignorés.
				return nil
		}
	}
	
	/// Mappe `Modifiers` (lib interne) vers `KeyMods` (API publique STK).
	static func modsFromConsole(_ m: Modifiers) -> KeyMods {
		var out: KeyMods = []
		if m.contains(.shift) { out.insert(.shift) }
		if m.contains(.ctrl)  { out.insert(.ctrl)  }
		if m.contains(.alt)   { out.insert(.alt)   }
		if m.contains(.meta)  { out.insert(.meta)  }
		return out
	}
}
