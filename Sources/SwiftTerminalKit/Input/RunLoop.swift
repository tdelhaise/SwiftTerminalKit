import Foundation

public final class STKRunLoop {
	private let console: Console
	private let screen: Screen
	private let queue: EventQueue
	
	public init(console: Console, screen: Screen) {
		self.console = console
		self.screen = screen
		self.queue = EventQueue(console: console)
	}
	
	/// Boucle synchrone : retourne quand le handler renvoie false.
	@discardableResult
	public func runSync(pollMs: Int = 50, handle: (InputEvent) -> Bool) -> Int {
		var frames = 0
		while true {
			if let ev = queue.nextEvent(timeoutMs: pollMs) {
				let keep = handle(ev)
				screen.render()
				frames += 1
				if !keep { break }
			} else {
				// Aucun événement pendant ce poll ; on pourrait rafraîchir conditionnellement si nécessaire.
				// screen.render()
			}
		}
		return frames
	}
	
	/// Variante asynchrone (Swift Concurrency)
	public func runAsync(pollMs: Int = 50, handle: @escaping (InputEvent) async -> Bool) async {
		for await ev in queue.eventsStream(pollEveryMs: pollMs) {
			let keep = await handle(ev)
			screen.render()
			if !keep { break }
		}
	}
}
