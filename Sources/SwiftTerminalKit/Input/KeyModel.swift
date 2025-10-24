import Foundation

// Pont Console.Event -> KeyEvent unifié.
// Les types publics (KeyMods, KeyEvent, InputEvent) sont définis dans InputEvent.swift.

extension KeyEvent {
	
	public static func fromConsoleEvent(_ ev: Event) -> KeyEvent? {
		switch ev {
			case .key(let key, let m):
				let mods = mapConsoleMods(m)
				
				switch key {
						// --- Texte / caractères ---
					case .char(let ch):
						// Ctrl-A..Ctrl-Z (0x01..0x1A) -> synthèse .ctrl + lettre correspondante
						if let (normCh, extra) = normalizeControlChar(ch) {
							var final = mods
							if extra.contains(KeyMods.ctrl) { final.insert(.ctrl) }
							return KeyEvent(.char(normCh), mods: final, utf8: utf8Payload(of: normCh))
						}
						
						// Entrée / Echap / Tab / Backspace via valeurs de contrôle usuelles
						if ch == "\r" || ch == "\n" { return KeyEvent(.enter,     mods: mods, utf8: [0x0D]) }
						if ch == "\u{1B}"          { return KeyEvent(.escape,    mods: mods, utf8: [0x1B]) }
						if ch == "\t"              { return KeyEvent(.tab,       mods: mods, utf8: [0x09]) }
						if ch == "\u{08}" || ch == "\u{7F}" {
							return KeyEvent(.backspace, mods: mods, utf8: [0x7F])
						}
						
						// Caractère imprimable
						return KeyEvent(.char(ch), mods: mods, utf8: utf8Payload(of: ch))
						
						// --- Touches spéciales mappées une-à-une ---
					case .left:      return KeyEvent(.left,      mods: mods)
					case .right:     return KeyEvent(.right,     mods: mods)
					case .up:        return KeyEvent(.up,        mods: mods)
					case .down:      return KeyEvent(.down,      mods: mods)
					case .home:      return KeyEvent(.home,      mods: mods)
					case .end:       return KeyEvent(.end,       mods: mods)
					case .pageUp:    return KeyEvent(.pageUp,    mods: mods)
					case .pageDown:  return KeyEvent(.pageDown,  mods: mods)
					case .insert:    return KeyEvent(.insert,    mods: mods)
						
						// Ces cas existent dans ton Console.Key (messages du compilateur) :
					case .enter:     return KeyEvent(.enter,     mods: mods,   utf8: [0x0D])
					case .backspace: return KeyEvent(.backspace, mods: mods,   utf8: [0x7F])
					case .tab:       return KeyEvent(.tab,       mods: mods,   utf8: [0x09])
					case .shiftTab:  return KeyEvent(.tab,       mods: mods.union([.shift]), utf8: [0x09])
					case .esc:       return KeyEvent(.escape,    mods: mods,   utf8: [0x1B])
						
					case .deleteKey: return KeyEvent(.delete,    mods: mods)
					case .function(let n):
						return KeyEvent(.function(n), mods: mods)
						
					case .unknown:
						// Rien à mapper -> on ignore.
						return nil
				}
				
			default:
				return nil
		}
	}
	
	// MARK: - Helpers
	
	private static func mapConsoleMods(_ m: Modifiers) -> KeyMods {
		var out: KeyMods = []
		if m.contains(.shift) { out.insert(.shift) }
		if m.contains(.ctrl)  { out.insert(.ctrl)  }   // tes Modifiers: .shift, .ctrl, .alt, .meta
		if m.contains(.alt)   { out.insert(.alt)   }
		if m.contains(.meta)  { out.insert(.meta)  }
		return out
	}
	
	/// Si `ch` ∈ C0 (0x01..0x1A) => ('a'..'z', [.ctrl])
	private static func normalizeControlChar(_ ch: Character) -> (Character, KeyMods)? {
		guard let u = ch.unicodeScalars.first?.value else { return nil }
		if u >= 0x01 && u <= 0x1A {
			let base = UnicodeScalar("a").value
			let mapped = Character(UnicodeScalar(base + (u - 1))!)
			return (mapped, [.ctrl])
		}
		return nil
	}
	
	private static func utf8Payload(of ch: Character) -> [UInt8] {
		if let u = ch.unicodeScalars.first?.value {
			return [UInt8(truncatingIfNeeded: u)]
		}
		return []
	}
}
