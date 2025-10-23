//
//  KeyModel.swift
//  SwiftTerminalKit
//

import Foundation

// MARK: - Modificateurs exposés côté Input

public struct KeyMods: OptionSet {
	public let rawValue: Int
	public init(rawValue: Int) { self.rawValue = rawValue }
	
	public static let shift = KeyMods(rawValue: 1 << 0)
	public static let ctrl  = KeyMods(rawValue: 1 << 1)
	public static let alt   = KeyMods(rawValue: 1 << 2)
	public static let meta  = KeyMods(rawValue: 1 << 3)
}

// MARK: - Codes de touches normalisés

public enum KeyCode: Equatable {
	case char(Character)   // y compris contrôle normalisé (ex: 'Q' avec .ctrl)
	case enter
	case tab
	case backspace
	
	case left, right, up, down
	case home, end, pageUp, pageDown
	case function(Int)
	
	case unknown
}

// MARK: - Evénement clavier

public struct KeyEvent: Equatable {
	public let keyCode: KeyCode
	public let mods: KeyMods
	public let utf8: [UInt8]   // charge utile brute utile en debug
	
	public init(_ keyCode: KeyCode, mods: KeyMods = [], utf8: [UInt8] = []) {
		self.keyCode = keyCode
		self.mods = mods
		self.utf8 = utf8
	}
}

// MARK: - Adaptation depuis ton Event haut-niveau

public extension KeyEvent {
	/// Convertit `Event` -> `KeyEvent` (si c’est un .key)
	static func fromEvent(_ ev: Event) -> KeyEvent? {
		switch ev {
			case .key(let k, let m):
				let mods = Self.modsFrom(m)
				
				switch k {
					case .char(let ch):
						// 1) Normalisation des contrôles C0 ^A..^Z
						if let (normCh, ctrlMod) = normalizeControlChar(ch) {
							var finalMods = mods
							if ctrlMod { finalMods.insert(.ctrl) }
							let u = normCh.unicodeScalars.first?.value
							let raw = u != nil ? [UInt8(u! & 0xFF)] : []
							return KeyEvent(.char(normCh), mods: finalMods, utf8: raw)
						}
						
						// 2) DEL 0x7F -> backspace (optionnel mais pratique)
						if isDel(ch) {
							return KeyEvent(.backspace, mods: mods, utf8: [0x7F])
						}
						
						// 3) Tab / Enter tels que caractères
						if ch == "\t" { return KeyEvent(.tab, mods: mods, utf8: [0x09]) }
						if ch == "\r" || ch == "\n" { return KeyEvent(.enter, mods: mods, utf8: [0x0D]) }
						
						// 4) ESC si livré comme caractère (pas de .escape dans ton Key)
						if isEscape(ch) {
							// on l’expose côté app comme char U+001B (si tu veux un case .escape, on pourra l’ajouter plus tard)
							return KeyEvent(.char(ch), mods: mods, utf8: [0x1B])
						}
						
						// 5) Texte imprimable
						let raw = String(ch).utf8.map { $0 }
						return KeyEvent(.char(ch), mods: mods, utf8: raw)
						
					case .enter:     return KeyEvent(.enter, mods: mods, utf8: [0x0D])
					case .tab:       return KeyEvent(.tab, mods: mods, utf8: [0x09])
					case .backspace: return KeyEvent(.backspace, mods: mods, utf8: [0x7F])
						
					case .left:      return KeyEvent(.left, mods: mods)
					case .right:     return KeyEvent(.right, mods: mods)
					case .up:        return KeyEvent(.up, mods: mods)
					case .down:      return KeyEvent(.down, mods: mods)
						
					case .home:      return KeyEvent(.home, mods: mods)
					case .end:       return KeyEvent(.end, mods: mods)
					case .pageUp:    return KeyEvent(.pageUp, mods: mods)
					case .pageDown:  return KeyEvent(.pageDown, mods: mods)
						
					case .function(let n):
						return KeyEvent(.function(n), mods: mods)
						
					default:
						return KeyEvent(.unknown, mods: mods)
				}
				
			default:
				return nil
		}
	}
}

// MARK: - Helpers

/// ^A..^Z (0x01..0x1A) -> ('A'..'Z', ctrl = true)
fileprivate func normalizeControlChar(_ ch: Character) -> (Character, Bool)? {
	guard let v = ch.unicodeScalars.first?.value else { return nil }
	if 0x01...0x1A ~= v, let us = UnicodeScalar(0x40 + v) { // 0x41='A'
		return (Character(us), true)
	}
	return nil
}

fileprivate func isDel(_ ch: Character) -> Bool {
	ch.unicodeScalars.first?.value == 0x7F
}

fileprivate func isEscape(_ ch: Character) -> Bool {
	ch.unicodeScalars.first?.value == 0x1B
}

fileprivate extension KeyEvent {
	static func modsFrom(_ m: Modifiers) -> KeyMods {
		var out: KeyMods = []
		if m.contains(.shift) { out.insert(.shift) }
		if m.contains(.ctrl)  { out.insert(.ctrl)  }
		if m.contains(.alt)   { out.insert(.alt)   }
		if m.contains(.meta)  { out.insert(.meta)  }
		return out
	}
}
