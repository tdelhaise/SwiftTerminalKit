import Foundation

open class Application {
    public let console: Console
    public let screen: Screen
    private let runLoop: STKRunLoop
    private var shouldExit = false
    private var pendingStatusMessage: String?

    public init() throws {
        self.console = try Console()
        self.screen = Screen(console: console)
        self.runLoop = STKRunLoop(console: console, screen: screen)
        self.pendingStatusMessage = console.capabilitySummary
        console.statusHook = { [weak self] message in
            self?.statusDidUpdate(message)
        }
    }

    open func setup() throws {}
    open func teardown() {}
    open func handle(event: InputEvent) -> Bool {
        // By default, pass key events to the focused view.
        if case .key(let key) = event {
            if let focused = screen.focusedView, focused.handle(event: key) {
                return true // Event was handled by the focused view.
            }
        }
        // Return false to indicate the event was not handled by the base implementation.
        return false
    }
    open func statusDidUpdate(_ message: String) {
        pendingStatusMessage = message
    }

    public func requestExit() {
        shouldExit = true
    }

    public func run() throws {
        defer { console.shutdown() }
        try setup()
        if let message = pendingStatusMessage {
            pendingStatusMessage = nil
            statusDidUpdate(message)
        }
        _ = runLoop.runSync { [weak self] event in
            guard let self else { return false }
            if !self.handle(event: event) {
                self.shouldExit = true
            }
            return !self.shouldExit
        }
        teardown()
    }
}
