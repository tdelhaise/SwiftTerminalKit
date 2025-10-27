import Foundation

/// Capability snapshot negotiated/detected at startup.
public struct TerminalCaps {
	public enum ColorMode: String { case ansi16, xterm256, truecolor }
	
	public var color: ColorMode
	public var supportsAltScreen: Bool
	public var supportsMouse: Bool
	public var supportsBracketedPaste: Bool
	public var supportsFocusEvents: Bool
	
	private static let defaultCaps = TerminalCaps(color: .ansi16,
												  supportsAltScreen: true,
												  supportsMouse: true,
												  supportsBracketedPaste: true,
												  supportsFocusEvents: true)
	
	public init(color: ColorMode = .ansi16,
				supportsAltScreen: Bool = true,
				supportsMouse: Bool = true,
				supportsBracketedPaste: Bool = true,
				supportsFocusEvents: Bool = true) {
		self.color = color
		self.supportsAltScreen = supportsAltScreen
		self.supportsMouse = supportsMouse
		self.supportsBracketedPaste = supportsBracketedPaste
		self.supportsFocusEvents = supportsFocusEvents
	}
}

// MARK: - Detection

public extension TerminalCaps {
	static func detect(environment env: [String: String] = ProcessInfo.processInfo.environment) -> TerminalCaps {
		var caps = defaultCaps
		
		let term = env["TERM"]?.lowercased() ?? ""
		let termProgram = env["TERM_PROGRAM"]?.lowercased() ?? ""
		let colorterm = env["COLORTERM"]?.lowercased()
		
		// Determine color mode
		if let forcedMode = env["SWIFTERMINALKIT_COLOR_MODE"] {
			caps.color = parseColorModeOverride(forcedMode)
		} else if let tcOverride = env["SWIFTERMINALKIT_TRUECOLOR"],
				  let forced = parseBool(tcOverride) {
			caps.color = forced ? .truecolor : inferColorMode(term: term, colorterm: colorterm, termProgram: termProgram, environment: env)
		} else {
			caps.color = inferColorMode(term: term, colorterm: colorterm, termProgram: termProgram, environment: env)
		}
		
		// Determine feature support
		caps.supportsAltScreen = inferAltScreen(term: term, termProgram: termProgram, env: env)
		caps.supportsMouse = inferMouse(term: term, termProgram: termProgram, env: env)
		caps.supportsBracketedPaste = inferBracketedPaste(term: term, termProgram: termProgram, env: env)
		caps.supportsFocusEvents = inferFocusEvents(term: term, termProgram: termProgram, env: env)
		
		// Apply explicit overrides
		if let v = env["SWIFTERMINALKIT_ALTSCREEN"], let b = parseBool(v) { caps.supportsAltScreen = b }
		if let v = env["SWIFTERMINALKIT_MOUSE"], let b = parseBool(v) { caps.supportsMouse = b }
		if let v = env["SWIFTERMINALKIT_BRACKETED_PASTE"], let b = parseBool(v) { caps.supportsBracketedPaste = b }
		if let v = env["SWIFTERMINALKIT_FOCUS_EVENTS"], let b = parseBool(v) { caps.supportsFocusEvents = b }
		
		emitLogIfNeeded(caps: caps, term: term, termProgram: termProgram, colorterm: colorterm, env: env)
		return caps
	}
}

// MARK: - Inference helpers

private extension TerminalCaps {
	static func parseColorModeOverride(_ value: String) -> ColorMode {
		let v = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
		switch v {
			case "truecolor", "24bit", "24", "full": return .truecolor
			case "256", "xterm256", "256color": return .xterm256
			case "16", "ansi16": return .ansi16
			default: return inferColorMode(term: nil, colorterm: nil, termProgram: nil, environment: [:])
		}
	}
	
	static func inferColorMode(term: String?, colorterm: String?, termProgram: String?, environment env: [String: String]) -> ColorMode {
		if let colorterm = colorterm {
			if colorterm.contains("truecolor") || colorterm.contains("24bit") { return .truecolor }
		}
		if let term = term {
			if term.contains("direct") || term.contains("truecolor") { return .truecolor }
			if term.contains("256color") || term.contains("256-colour") { return .xterm256 }
			if term.contains("color") || term.contains("colour") { return .xterm256 }
		}
		if let termProgram = termProgram {
			if ["iterm.app", "apple_terminal", "wezterm", "alacritty", "vscode", "kitty"].contains(termProgram) { return .truecolor }
		}
		if env["WT_SESSION"] != nil || env["DOMTERM"] != nil {
			return .truecolor
		}
		return .ansi16
	}
	
	static func inferAltScreen(term: String, termProgram: String, env: [String: String]) -> Bool {
		if env["STY"] != nil || env["TMUX"] != nil { return true } // screen/tmux re-export alt screen
		if term.isEmpty { return false }
		let stoplist = ["dumb", "ansi", "unknown"]
		if stoplist.contains(term) { return false }
		let candidates = ["xterm", "rxvt", "screen", "tmux", "st", "linux", "vt100", "vte", "alacritty", "wezterm", "foot", "kitty", "contour"]
		if candidates.contains(where: { term.hasPrefix($0) || term.contains($0) }) { return true }
		if ["iterm.app", "apple_terminal", "wezterm", "alacritty", "kitty"].contains(termProgram) { return true }
		return true // optimistic default: most modern terminals support it
	}
	
	static func inferMouse(term: String, termProgram: String, env: [String: String]) -> Bool {
		let stoplist = ["dumb", "ansi", "unknown"]
		if stoplist.contains(term) { return false }
		let mouseCapable = ["xterm", "rxvt", "screen", "tmux", "st", "vte", "alacritty", "wezterm", "foot", "kitty", "linux"]
		if mouseCapable.contains(where: { term.hasPrefix($0) || term.contains($0) }) { return true }
		if ["iterm.app", "apple_terminal", "wezterm", "alacritty", "kitty"].contains(termProgram) { return true }
		return true
	}
	
	static func inferBracketedPaste(term: String, termProgram: String, env: [String: String]) -> Bool {
		let supports = ["xterm", "rxvt", "screen", "tmux", "st", "vte", "alacritty", "wezterm", "foot", "kitty"]
		if supports.contains(where: { term.hasPrefix($0) || term.contains($0) }) { return true }
		if ["iterm.app", "apple_terminal", "wezterm", "alacritty", "kitty"].contains(termProgram) { return true }
		if env["TMUX"] != nil { return true } // tmux advertises bracketed paste
		return false
	}
	
	static func inferFocusEvents(term: String, termProgram: String, env: [String: String]) -> Bool {
		let supports = ["xterm", "rxvt", "vte", "wezterm", "alacritty", "kitty", "foot", "gnome-terminal", "contour"]
		if supports.contains(where: { term.hasPrefix($0) || term.contains($0) }) { return true }
		if ["iterm.app", "wezterm", "alacritty", "kitty"].contains(termProgram) { return true }
		if env["TMUX"] != nil { return true }
		return false
	}
	
	static func parseBool(_ value: String) -> Bool? {
		let v = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
		switch v {
			case "1", "true", "yes", "on": return true
			case "0", "false", "no", "off": return false
			default: return nil
		}
	}
}

// MARK: - Logging

private extension TerminalCaps {
	static func emitLogIfNeeded(caps: TerminalCaps,
								term: String,
								termProgram: String,
								colorterm: String?,
								env: [String: String]) {
		guard shouldLog(env: env) else { return }
		var parts: [String] = []
		parts.append("color=\(caps.color.rawValue)")
		parts.append("altScreen=\(caps.supportsAltScreen)")
		parts.append("mouse=\(caps.supportsMouse)")
		parts.append("bracketedPaste=\(caps.supportsBracketedPaste)")
		parts.append("focusEvents=\(caps.supportsFocusEvents)")
		let base = parts.joined(separator: " ")
		
		var envParts: [String] = []
		if !term.isEmpty { envParts.append("TERM=\(term)") }
		if !termProgram.isEmpty { envParts.append("TERM_PROGRAM=\(termProgram)") }
		if let colorterm = colorterm, !colorterm.isEmpty { envParts.append("COLORTERM=\(colorterm)") }
		let envSummary = envParts.joined(separator: " ")
		
		let message: String
		if envSummary.isEmpty {
			message = "[SwiftTerminalKit] caps \(base)"
		} else {
			message = "[SwiftTerminalKit] caps \(base) (\(envSummary))"
		}
		
		if let data = (message + "\n").data(using: .utf8) {
			FileHandle.standardError.write(data)
		}
	}
	
	static func shouldLog(env: [String: String]) -> Bool {
		if let v = env["SWIFTERMINALKIT_DEBUG_CAPS"], let b = parseBool(v) { return b }
		return false
	}
}
