# SwiftTerminalKit Manual Verification Checklist

Use this guide to confirm the new capability detection and input parsing behaviour on real terminals. Run the steps in each environment you care about (xterm, tmux, macOS Terminal, Linux console, etc.).

## 1. Capture Terminal Context

1. Start the session exactly as you would run the demos.
2. Export debug logging for capabilities:
   ```sh
   export SWIFTERMINALKIT_DEBUG_CAPS=1
   ```
3. Note the key environment variables:
   ```sh
   echo "TERM=$TERM"
   echo "TERM_PROGRAM=$TERM_PROGRAM"
   echo "COLORTERM=$COLORTERM"
   ```
4. Optional: record the raw terminfo entry if `infocmp` is available (purely for offline comparison, SwiftTerminalKit does not depend on it):
   ```sh
   infocmp -1 "$TERM" > /tmp/stk-terminfo-$TERM.txt
   ```

## 2. Run the Demo App

1. Build and run the TextEdit demo from the repository root:
   ```sh
   swift run TextEditDemo
   ```
   If `SWIFTERMINALKIT_DEBUG_CAPS=1`, a capability summary prints once on launch; note it before interacting with the app.
2. Keep that log; we will compare it with observed behaviour below.

## 3. Keyboard Verification

Perform each action and confirm the editor reacts (cursor movement, menus, etc.). Report any mismatches along with the logged capabilities.

- Arrow keys (Up/Down/Left/Right).
- Home, End, Page Up, Page Down.
- Insert, Delete, Backspace.
- Function keys F1–F12.
- Ctrl-modified arrows (expect word/line navigation once the editor binds them).
- Alt/Meta + character (TextEdit should display the character; confirm the app does not drop it).
- Shift+Tab (should move focus backwards in menu/dialog contexts).
- Enter / Return.
- Esc (menu dismiss or app-level handling).
- F10 toggles the menu bar; Alt+F, Alt+E, Alt+S jump to File/Edit/Search while active.

## 4. Bracketed Paste

1. Copy multi-line text from an external source.
2. In the demo, paste it with the terminal’s standard paste shortcut.
3. Expected: Text is inserted once, preserving newlines. If nothing appears or characters trickle in slowly, bracketed paste negotiation likely failed.

## 5. Mouse (if supported)

1. Verify left-click sets cursor position inside the editor.
2. If the terminal supports it, try selecting menu entries with the mouse.
3. Scroll the mouse wheel to ensure wheel events are detected (should move the view once wired).
4. Note that some terminals require Shift+click for mouse events when running inside tmux/screen; record any such quirks.

## 6. Focus Events (optional)

1. Alt-tab away from the terminal and back.
2. Watch stderr for additional `[SwiftTerminalKit]` lines indicating focus gained/lost. If absent, the terminal may not support focus events even if the capability log says true—report the discrepancy.

## 7. Reporting Template

When reporting results, please include:

- Terminal/emulator name & version.
- The captured capability log line.
- Which checklist items succeeded or failed.
- Any unexpected escape sequences (if visible) or screenshots/text dumps illustrating failures.

These details will help refine heuristics or design targeted escape-sequence probes/overrides for future releases.
