import Foundation

/// Terminal input parser turning raw bytes into high-level `Event`s.
final class VTParser {
	private var buffer: [UInt8] = []
	private var eventQueue: [Event] = []
	
	func feed(_ slice: ArraySlice<UInt8>) {
		buffer.append(contentsOf: slice)
		parse()
	}
	
	func nextEvent() -> Event? {
		eventQueue.isEmpty ? nil : eventQueue.removeFirst()
	}
	
	// MARK: - Core parsing loop
	
	private func parse() {
		while !buffer.isEmpty {
			if let result = parseNextEvent() {
				eventQueue.append(result.event)
				if result.consumed > 0 {
					buffer.removeFirst(result.consumed)
				} else {
					buffer.removeAll()
				}
			} else {
				break
			}
		}
	}
	
	private func parseNextEvent() -> (event: Event, consumed: Int)? {
		guard let first = buffer.first else { return nil }
		
		switch first {
			case 0x1B: // ESC
				return parseEscapeSequence()
				
			case 0x7F:
				return (.key(.backspace, []), 1)
				
			case 0x09:
				return (.key(.tab, []), 1)
				
			case 0x0D, 0x0A:
				return (.key(.enter, []), 1)
				
			default:
				if let (ch, consumed) = decodeUTF8Character(from: buffer) {
					return (.key(.char(ch), []), consumed)
				}
				// Not enough data to decode yet.
				return nil
		}
	}
	
	// MARK: - Escape handling
	
	private func parseEscapeSequence() -> (event: Event, consumed: Int)? {
		guard buffer.count >= 2 else {
			// Lone ESC -> treat as Escape key.
			return (.key(.esc, []), 1)
		}
		
		let second = buffer[1]
		switch second {
			case UInt8(ascii: "["):
				return parseCSISequence()
				
			case UInt8(ascii: "O"):
				return parseSS3Sequence()
				
			default:
				// ALT-modified character: ESC + UTF-8 payload.
				let remainder = Array(buffer.dropFirst(1))
				if let (ch, consumedChar) = decodeUTF8Character(from: remainder) {
					return (.key(.char(ch), [.alt]), consumedChar + 1)
				}
				return nil
		}
	}
	
	// MARK: - CSI sequences (ESC [ ...)
	
	private func parseCSISequence() -> (event: Event, consumed: Int)? {
		guard let finalIndex = indexOfFinalCSIByte(start: 2) else {
			// Incomplete sequence
			return nil
		}
		
		let final = buffer[finalIndex]
		let parameters = buffer[2..<finalIndex]
		let consumed = finalIndex + 1
		
		// Special-case SGR mouse (CSI <...M/m) before parsing digits generically.
		if !parameters.isEmpty && parameters.first == UInt8(ascii: "<") {
			if let mouse = parseSGRMouse(parameters: parameters, final: final) {
				return (.mouse(mouse), consumed)
			}
			return (.key(.unknown, []), consumed)
		}
		
		let params = parseCSINumericParameters(parameters)
		
		switch final {
			case UInt8(ascii: "A"):
				return (.key(.up, modifiersFrom(params: params)), consumed)
			case UInt8(ascii: "B"):
				return (.key(.down, modifiersFrom(params: params)), consumed)
			case UInt8(ascii: "C"):
				return (.key(.right, modifiersFrom(params: params)), consumed)
			case UInt8(ascii: "D"):
				return (.key(.left, modifiersFrom(params: params)), consumed)
			case UInt8(ascii: "E"):
				return (.key(.function(10), modifiersFrom(params: params)), consumed)
			case UInt8(ascii: "F"):
				return (.key(.end, modifiersFrom(params: params)), consumed)
			case UInt8(ascii: "F"):
				return (.key(.end, modifiersFrom(params: params)), consumed)
			case UInt8(ascii: "H"):
				return (.key(.home, modifiersFrom(params: params)), consumed)
			case UInt8(ascii: "Z"):
				var mods = modifiersFrom(params: params)
				mods.insert(.shift)
				return (.key(.shiftTab, mods), consumed)
			case UInt8(ascii: "~"):
				return parseTildeSequence(params: params, consumed: consumed)
			case UInt8(ascii: "I"):
				return (.focusGained, consumed)
			case UInt8(ascii: "O"):
				return (.focusLost, consumed)
			default:
				return (.key(.unknown, []), consumed)
		}
	}
	
	private func parseTildeSequence(params: [Int], consumed: Int) -> (event: Event, consumed: Int)? {
		guard let code = params.first else {
			return (.key(.unknown, []), consumed)
		}
		
		// Bracketed paste start/end
		if code == 200 {
			return parseBracketedPaste(consumedUpToStart: consumed)
		}
		if code == 201 {
			// Should be consumed together with 200 handler; if seen alone, ignore.
			return (.key(.unknown, []), consumed)
		}
		
		let mods = params.count >= 2 ? modifiersFrom(value: params[1]) : []
		
		if let key = keyFromTildeCode(code) {
			return (.key(key, mods), consumed)
		}
		
		if let functionNumber = functionKeyNumber(fromTildeCode: code) {
			return (.key(.function(functionNumber), mods), consumed)
		}
		
		return (.key(.unknown, []), consumed)
	}
	
	// MARK: - SS3 sequences (ESC O ...)
	
	private func parseSS3Sequence() -> (event: Event, consumed: Int)? {
		// Format: ESC O [parameters] <final>
		guard let finalIndex = indexOfSS3FinalByte(start: 2) else {
			return nil
		}
		
		let final = buffer[finalIndex]
		let parameters = buffer[2..<finalIndex]
		let consumed = finalIndex + 1
		
		let params = parseCSINumericParameters(parameters)
		let mods = modifiersFromSS3(params: params)
		
		switch final {
			case UInt8(ascii: "P"):
				return (.key(.function(1), mods), consumed)
			case UInt8(ascii: "Q"):
				return (.key(.function(2), mods), consumed)
			case UInt8(ascii: "R"):
				return (.key(.function(3), mods), consumed)
			case UInt8(ascii: "S"):
				return (.key(.function(4), mods), consumed)
			case UInt8(ascii: "A"):
				return (.key(.up, mods), consumed)
			case UInt8(ascii: "B"):
				return (.key(.down, mods), consumed)
			case UInt8(ascii: "C"):
				return (.key(.right, mods), consumed)
			case UInt8(ascii: "D"):
				return (.key(.left, mods), consumed)
			case UInt8(ascii: "H"):
				return (.key(.home, mods), consumed)
			case UInt8(ascii: "F"):
				return (.key(.end, mods), consumed)
			default:
				return (.key(.unknown, []), consumed)
		}
	}
	
	// MARK: - Helpers
	
	private func decodeUTF8Character(from bytes: [UInt8]) -> (Character, Int)? {
		guard let first = bytes.first else { return nil }
		
		if first < 0x80 {
			return (Character(UnicodeScalar(first)), 1)
		}
		
		let expectedLength: Int
		switch first {
			case 0xC0...0xDF: expectedLength = 2
			case 0xE0...0xEF: expectedLength = 3
			case 0xF0...0xF7: expectedLength = 4
			default:
				return nil
		}
		
		guard bytes.count >= expectedLength else { return nil }
		let slice = Array(bytes[0..<expectedLength])
		if let str = String(bytes: slice, encoding: .utf8), let ch = str.first {
			return (ch, expectedLength)
		}
		return nil
	}
	
	private func indexOfFinalCSIByte(start: Int) -> Int? {
		var i = start
		while i < buffer.count {
			let b = buffer[i]
			if (0x40...0x7E).contains(b) {
				return i
			}
			i += 1
		}
		return nil
	}
	
	private func indexOfSS3FinalByte(start: Int) -> Int? {
		return indexOfFinalCSIByte(start: start)
	}
	
	private func parseCSINumericParameters(_ bytes: ArraySlice<UInt8>) -> [Int] {
		guard !bytes.isEmpty else { return [] }
		var params: [Int] = []
		var current = ""
		
		for b in bytes {
			switch b {
				case UInt8(ascii: ";"):
					if let value = Int(current) {
						params.append(value)
					} else if !current.isEmpty {
						params.append(0)
					}
					current.removeAll(keepingCapacity: true)
				case UInt8(ascii: "?"), UInt8(ascii: "="), UInt8(ascii: ">"):
					// Ignore private mode prefixes.
					continue
				default:
					let scalar = UnicodeScalar(b)
					if scalar.isASCII {
						current.append(Character(scalar))
					}
			}
		}
		
		if let value = Int(current) {
			params.append(value)
		} else if !current.isEmpty {
			params.append(0)
		}
		return params
	}
	
	private func modifiersFrom(params: [Int]) -> Modifiers {
		if params.count >= 2 {
			return modifiersFrom(value: params[1])
		}
		if let first = params.first, first >= 2 {
			return modifiersFrom(value: first)
		}
		return []
	}
	
	private func modifiersFromSS3(params: [Int]) -> Modifiers {
		guard let last = params.last else { return [] }
		return modifiersFrom(value: last)
	}
	
	private func modifiersFrom(value: Int) -> Modifiers {
		guard value > 1 else { return [] }
		let mask = value - 1
		var mods: Modifiers = []
		if (mask & 0b0001) != 0 { mods.insert(.shift) }
		if (mask & 0b0010) != 0 { mods.insert(.alt) }
		if (mask & 0b0100) != 0 { mods.insert(.ctrl) }
		if (mask & 0b1000) != 0 { mods.insert(.meta) }
		return mods
	}
	
	private func keyFromTildeCode(_ code: Int) -> Key? {
		switch code {
			case 1, 7: return .home
			case 2: return .insert
			case 3: return .deleteKey
			case 4, 8: return .end
			case 5: return .pageUp
			case 6: return .pageDown
			default: return nil
		}
	}
	
	private func functionKeyNumber(fromTildeCode code: Int) -> Int? {
		switch code {
			case 11: return 1
			case 12: return 2
			case 13: return 3
			case 14: return 4
			case 15: return 5
			case 17: return 6
			case 18: return 7
			case 19: return 8
			case 20: return 9
			case 21: return 10
			case 23: return 11
			case 24: return 12
			case 25: return 13
			case 26: return 14
			case 28: return 15
			case 29: return 16
			case 31: return 17
			case 32: return 18
			case 33: return 19
			case 34: return 20
			default: return nil
		}
	}
	
	// MARK: - Bracketed paste
	
	private func parseBracketedPaste(consumedUpToStart start: Int) -> (event: Event, consumed: Int)? {
		let terminator: [UInt8] = [0x1B, 0x5B, 0x32, 0x30, 0x31, 0x7E] // ESC [ 201 ~
		let dataStart = start
		
		guard let endIndex = indexOfSequence(terminator, from: dataStart) else {
			// Need more bytes to finish paste payload.
			return nil
		}
		
		let pasteBytes = buffer[dataStart..<endIndex]
		let consumed = endIndex + terminator.count
		let payload = String(bytes: pasteBytes, encoding: .utf8) ?? String(decoding: pasteBytes, as: UTF8.self)
		return (.paste(payload), consumed)
	}
	
	private func indexOfSequence(_ sequence: [UInt8], from start: Int) -> Int? {
		guard !sequence.isEmpty, start < buffer.count else { return nil }
		let lastPossible = buffer.count - sequence.count
		var i = start
		while i <= lastPossible {
			var matched = true
			for j in 0..<sequence.count {
				if buffer[i + j] != sequence[j] {
					matched = false
					break
				}
			}
			if matched { return i }
			i += 1
		}
		return nil
	}
	
	// MARK: - Mouse (SGR 1006)
	
	private func parseSGRMouse(parameters: ArraySlice<UInt8>, final: UInt8) -> MouseEvent? {
		guard let str = String(bytes: parameters, encoding: .ascii) else { return nil }
		let comps = str.dropFirst().split(separator: ";")
		guard comps.count >= 3,
			  let b = Int(comps[0]),
			  let x = Int(comps[1]),
			  let y = Int(comps[2]) else { return nil }
		
		let mods = mouseModifiers(from: b)
		let position = (x: max(0, x - 1), y: max(0, y - 1)) // 1-based -> 0-based
		
		if b >= 64 {
			let button: MouseButton = (b & 1) == 0 ? .wheelUp : .wheelDown
			return MouseEvent(x: position.x, y: position.y, button: button, type: .wheel, modifiers: mods)
		}
		
		let buttonCode = b & 0b11
		let isDrag = (b & 0b100000) != 0
		let button = mouseButton(from: buttonCode)
		
		let eventType: MouseEventType
		if final == UInt8(ascii: "m") {
			eventType = .up
		} else if isDrag {
			eventType = .drag
		} else if button == .none {
			eventType = .move
		} else {
			eventType = .down
		}
		
		return MouseEvent(x: position.x, y: position.y, button: button, type: eventType, modifiers: mods)
	}
	
	private func mouseModifiers(from code: Int) -> Modifiers {
		var mods: Modifiers = []
		if (code & 4) != 0 { mods.insert(.shift) }
		if (code & 8) != 0 { mods.insert(.alt) }
		if (code & 16) != 0 { mods.insert(.ctrl) }
		return mods
	}
	
	private func mouseButton(from code: Int) -> MouseButton {
		switch code {
			case 0: return .left
			case 1: return .middle
			case 2: return .right
			default: return .none
		}
	}
}
