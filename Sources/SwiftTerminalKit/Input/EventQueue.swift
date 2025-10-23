import Foundation

/// Enveloppe `console.pollEvent(timeoutMs:)` et expose un API sync/async.
public final class EventQueue {
	private let console: Console
	
	public init(console: Console) { self.console = console }
	
	/// Attente bloquante (jusqu'à timeoutMs) d’un InputEvent unifié.
	public func nextEvent(timeoutMs: Int = 50) -> InputEvent? {
		guard let ev = console.pollEvent(timeoutMs: timeoutMs) else { return nil }
		
		switch ev {
			case .resize(let c, let r):
				return .resize(cols: c, rows: r)
				
			case .paste(let s): // Event.paste(String)
				return .paste(s)
				
			case .mouse(let me): // Event.mouse(MouseEvent)
				let mods = KeyEvent.modsFromConsole(me.modifiers)
				return .mouse(
					x: me.x,
					y: me.y,
					button: me.button,
					type: me.type,
					mods: mods
				)
				
			case .key:
				if let k = KeyEvent.fromConsoleEvent(ev) {
					return .key(k)
				}
				return nil
				
			case .focusGained, .focusLost:
				// Ignoré pour l’instant (possible d’exposer un InputEvent dédié plus tard).
				return nil
		}
	}
	
	/// Séquence asynchrone d’événements (compatible Swift 6.2+).
	public func eventsStream(pollEveryMs: Int = 50) -> AsyncStream<InputEvent> {
		AsyncStream { continuation in
			Task.detached {
				while !Task.isCancelled {
					if let e = self.nextEvent(timeoutMs: pollEveryMs) {
						continuation.yield(e)
					}
				}
				continuation.finish()
			}
		}
	}
}
