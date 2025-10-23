import Foundation

/// A simple run loop object that can be used both synchronously and asynchronously.
public final class STKRunLoop {
	private let queue: EventQueue
	private let screen: Screen?  // optional: auto-flush before blocking
	
	public init(console: Console, screen: Screen? = nil) {
		self.queue = EventQueue(console: console)
		self.screen = screen
	}
	
	/// Synchronous style: provide a handler; returns when handler says to stop.
	@discardableResult
	public func runSync(pollMs: Int = 50, handle: (InputEvent) -> Bool) -> Int {
		var frames = 0
		while true {
			// allow compositor to flush before blocking
			screen?.render()
			if let ev = queue.nextEvent(timeoutMs: pollMs) {
				let keepGoing = handle(ev)
				frames += 1
				if !keepGoing { break }
			}
		}
		return frames
	}
	
	/// Asynchronous style using Swift concurrency.
	public func runAsync(pollMs: Int = 50, handle: @escaping (InputEvent) async -> Bool) async {
		for await ev in queue.eventsStream(pollEveryMs: pollMs) {
			let keep = await handle(ev)
			screen?.render()
			if !keep { break }
		}
	}
}
