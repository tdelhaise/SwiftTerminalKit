import Foundation

public final class EventQueue {
	private let console: Console
	
	public init(console: Console) {
		self.console = console
	}
	
	/// Récupère un InputEvent (ou nil si timeout)
	public func nextEvent(timeoutMs: Int = 50) -> InputEvent? {
		guard let ev = console.pollEvent(timeoutMs: timeoutMs) else { return nil }
		
		switch ev {
			case .resize(let c, let r):
				return .resize(cols: c, rows: r)
				
			case .paste(let s):
				// ton Event expose paste(String) -> on convertit en Data UTF-8
				return .paste(Data(s.utf8))
				
			case .mouse(let me):
				// map MouseEvent -> InputEvent.mouse
				let mods = mapMods(me.modifiers)
				return .mouse(x: me.x, y: me.y, button: me.button, type: me.type, mods: mods)
				
			case .key:
				if let ke = KeyEvent.fromEvent(ev) {
					return .key(ke)
				}
				return nil
				
			case .focusGained:
				return .focusGained
			case .focusLost:
				return .focusLost
		}
	}
	
	/// Stream asynchrone d’événements
	public func eventsStream(pollEveryMs: Int = 50) -> AsyncStream<InputEvent> {
		AsyncStream { continuation in
			Task.detached { [weak self] in
				guard let self else { continuation.finish(); return }
				while true {
					if let ev = self.nextEvent(timeoutMs: pollEveryMs) {
						continuation.yield(ev)
					}
					// Sinon: timeout -> on boucle
				}
			}
		}
	}
	
	private func mapMods(_ m: Modifiers) -> KeyMods {
		var out: KeyMods = []
		if m.contains(.shift) { out.insert(.shift) }
		if m.contains(.ctrl)  { out.insert(.ctrl)  }
		if m.contains(.alt)   { out.insert(.alt)   }
		if m.contains(.meta)  { out.insert(.meta)  }
		return out
	}
}
