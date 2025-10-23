import Foundation

/// Capability snapshot negotiated/detected at startup.
public struct TerminalCaps {
	public enum ColorMode { case ansi16, xterm256, truecolor }
	public var color: ColorMode
	public var supportsAltScreen: Bool
	public var supportsMouse: Bool
	public var supportsBracketedPaste: Bool
	
	public init(color: ColorMode = .truecolor,
				supportsAltScreen: Bool = true,
				supportsMouse: Bool = true,
				supportsBracketedPaste: Bool = true) {
		self.color = color
		self.supportsAltScreen = supportsAltScreen
		self.supportsMouse = supportsMouse
		self.supportsBracketedPaste = supportsBracketedPaste
	}
}
