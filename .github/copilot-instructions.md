# SwiftTerminalKit Copilot Instructions

## Project Overview

**SwiftTerminalKit** is a Swift framework for building terminal user interfaces (TUIs) with support for escape-sequence parsing, capability detection, composited views, and event handling. It abstracts POSIX terminal control into high-level APIs.

**Target:** macOS 13+ (currently Unix/POSIX only; Windows not yet implemented)

## Architecture: Five Core Components

### 1. **Input Pipeline** (`Sources/SwiftTerminalKit/Input/`)
- **Entry:** Raw terminal bytes → `VTParser` (escape sequence parser in `Parser/VTParser.swift`)
- **Events:** Parsed into `Event` enum variants: `.key()`, `.mouse()`, `.paste()`, `.focusGained`, `.focusLost`, `.resize()`
- **Queue:** `EventQueue` wraps `Console.pollEvent()` and bridges to `InputEvent` format
- **RunLoop:** `STKRunLoop` in `Input/RunLoop.swift` drives the main event loop:
  - Synchronous: `runSync { (InputEvent) -> Bool }` — return `false` to exit
  - Asynchronous: `runAsync { (InputEvent) async -> Bool }` using Swift Concurrency
- **Capabilities:** `TerminalCaps.detect()` queries environment (`TERM`, `COLORTERM`, etc.) to determine color mode, mouse, bracketed paste, focus events support

**Key: Terminal capability detection is automatic at startup; override via `SWIFTERMINALKIT_COLOR_MODE` env var.**

### 2. **Output & Rendering** (`Sources/SwiftTerminalKit/Render/`, `Terminal.swift`)
- **Console:** Central I/O class managing terminal modes (alt screen, mouse reporting, bracketed paste, focus events)
- **Surface:** In-memory grid (`Compositor/Region.swift`) tracking cells `(Character, fg, bg)`
- **Emitter:** Low-level escape sequence writer (e.g., `writeEsc()`, color codes, cursor movement)
- **Compositor:** `Screen.render()` collects dirty regions from views and redraws in z-order
- **Invalidation:** Views mark themselves dirty via `invalidate(rect)` when state changes; compositor only repaints damaged areas

**Key: All drawing is buffered to a surface, then flushed atomically via `console.present()`.**

### 3. **View Hierarchy** (`Sources/SwiftTerminalKit/UI/`)
- **Base Class:** `View` holds frame (screen coords), z-index, colors, focus state, border style
- **Invalidation Pattern:** When `view.frame` changes (didSet), both old and new rectangles are invalidated to clear artifacts
- **Concrete Views:** `Panel`, `Label`, `Button`, `Checkbox`, `InputLine`, `EditorView`, `Dialog`, etc.
- **Focus Management:** `Screen.setFocus(view)` updates `hasFocus` and invalidates both old and new focused views
- **Drawing Contract:** `draw(into:clip:)` receives a clipped damage rectangle; view is responsible for rendering only within bounds

**Key: All coordinate math uses `Rect` and `Region` helpers; never assume coordinate origin.**

### 4. **Event Handling**
- **Application Base Class:** `Application` wraps `Console`, `Screen`, and `STKRunLoop`
  - Override `handle(event: InputEvent) -> Bool` to intercept events
  - Return `false` to exit, `true` to continue
- **View Events:** Some views (e.g., `Button`, `InputLine`) have event handlers that can consume input
- **Event Dispatch:** Screen passes events to focused view first; app-level handler acts as fallback

**Key: Events propagate from focused view to application; views consume (return false) to prevent bubbling.**

### 5. **Terminal Capability Detection** (`Input/TerminalCaps.swift`)
- **Auto-Detection:** Reads `TERM`, `TERM_PROGRAM`, `COLORTERM` env vars
- **Overrides:** 
  - `SWIFTERMINALKIT_COLOR_MODE=ansi16|xterm256|truecolor`
  - `SWIFTERMINALKIT_TRUECOLOR=1|0`
  - `SWIFTERMINALKIT_DEBUG_CAPS=1` (prints capability summary to stderr)
- **Features Toggled:** Mouse, bracketed paste, focus events, alt screen, color depth
- **Fallback:** Defaults to ANSI 16 colors, assumes modern terminal features enabled

## Development Workflows

### Build & Run
```bash
# Build library
swift build

# Run specific demo
swift run BasicDemo        # Raw console API example
swift run TextEditDemo     # Full app with views

# Build & test
swift test
```

### C Shims Integration
- `CShims/termios_shim.{c,h}` provides POSIX termios wrappers for raw mode control
- Used by `POSIXIO` to initialize/restore terminal state
- No external dependencies; direct system call wrapping

### Manual Testing
- See `ManualVerification.md` for terminal capability verification across xterm, tmux, Terminal.app, etc.
- Run with `SWIFTERMINALKIT_DEBUG_CAPS=1` to log detected capabilities

## Common Patterns

### Adding a New View Type
1. Subclass `View` in `UI/`
2. Override `draw(into:clip:)` to render within the clipped rect
3. Override `cursorPosition() -> (x: Int, y: Int)?` if view displays a text cursor
4. Implement event handling if needed: override `handleEvent(_ e: InputEvent) -> Bool`
5. Call `invalidate()` whenever model state changes

### Handling User Input
```swift
open func handle(event: InputEvent) -> Bool {
    switch event {
    case .key(let ke) where ke.key == .char("q"):
        requestExit()
        return false  // Stop the runloop
    case .resize(let cols, let rows):
        screen.resizeToConsole()
        return true
    default:
        return true
    }
}
```

### Color & Styling
- Use `Console.PaletteColor` enum: `.named(.brightGreen)`, `.hex()` with hex strings, `.gray(level: 0-23)`, `.default`
- Renderer automatically chooses the best representation based on terminal capabilities
- No need to manually check color mode; the framework handles downsampling

## Critical Implementation Details

- **Escape Sequence Parsing:** `VTParser` is a **state machine** handling CSI sequences, SS3, UTF-8 decoding. Incomplete sequences are buffered until enough bytes arrive.
- **Region Tracking:** `Region` uses a union of non-overlapping rectangles; always call `normalize()` before iterating.
- **Surface Coordinates:** All (x, y) are screen coords. Views transform their local frames to screen space in `draw()`.
- **Damage/Invalidation:** Dirty regions accumulate; `takeInvalidRegion()` clears the pending queue and returns rects for repainting.
- **Terminal Shutdown:** Always call `console.shutdown()` (done by `Application`) to restore modes, disable mouse, show cursor, etc.

## Testing
- Unit tests in `Tests/SwiftTerminalKitTests/SwiftTerminalKitTests.swift`
- No heavy mocking; tests exercise real terminal capability detection and basic parsing
- Run: `swift test`

## Notable Limitations & Constraints
- **macOS 13+ only** (no Windows, limited Linux verification)
- **No external dependencies** for the core library (uses only Darwin/Glibc)
- **POSIX-only I/O** — non-blocking reads via `read()` with timeout via `select()`
- **No async/await wrapper around core loops** yet (though `EventQueue.eventsStream()` provides async iteration)
