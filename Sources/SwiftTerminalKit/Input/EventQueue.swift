import Foundation

public final class EventQueue {
	private let console: Console
	public init(console: Console) { self.console = console }
	
	/// Attend un InputEvent (timeout Ms).
	public func nextEvent(timeoutMs: Int = 50) -> InputEvent? {
		guard let ev = console.pollEvent(timeoutMs: timeoutMs) else { return nil }
		
		switch ev {
			case .resize(let c, let r):
				return .resize(cols: c, rows: r)
				
			case .paste(let s):
				return .paste(Data(s.utf8))
				
			case .mouse(let me):
				var km: KeyMods = []
				if me.modifiers.contains(.shift) { km.insert(.shift) }
				if me.modifiers.contains(.ctrl)  { km.insert(.ctrl)  }
				if me.modifiers.contains(.alt)   { km.insert(.alt)   }
				if me.modifiers.contains(.meta)  { km.insert(.meta)  }
				return .mouse(x: me.x, y: me.y, button: me.button, type: me.type, mods: km)
				
			case .key:
				if let ke = KeyEvent.fromConsoleEvent(ev) {
					return .key(ke)
				}
				return nil
				
			case .focusGained:
				return .focusGained
				
			case .focusLost:
				return .focusLost
		}
	}
	
	/// Flux d’événements asynchrone (Swift Concurrency)
	public func eventsStream(pollEveryMs: Int = 50) -> AsyncStream<InputEvent> {
		AsyncStream { continuation in
			Task.detached { [weak self] in
				guard let self = self else { return }
				while true {
					if let e = self.nextEvent(timeoutMs: pollEveryMs) {
						continuation.yield(e)
					}
				}
			}
		}
	}
}
