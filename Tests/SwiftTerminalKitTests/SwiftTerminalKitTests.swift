import XCTest
@testable import SwiftTerminalKit

final class VTParserTests: XCTestCase {
	private func events(from bytes: [UInt8]) -> [Event] {
		let parser = VTParser()
		parser.feed(bytes[...])
		var collected: [Event] = []
		while let ev = parser.nextEvent() {
			collected.append(ev)
		}
		return collected
	}
	
	func testArrowKeysWithoutModifiers() {
		let sequence: [UInt8] = [0x1B, 0x5B, 0x41] // ESC [ A
		let events = events(from: sequence)
		guard case .key(let key, let mods)? = events.first else {
			return XCTFail("Expected key event")
		}
		XCTAssertEqual(key, .up)
		XCTAssertTrue(mods.isEmpty)
	}
	
	func testArrowKeysWithModifiers() {
		let sequence: [UInt8] = [0x1B, 0x5B] + Array("1;5C".utf8) // Ctrl+Right
		let events = events(from: sequence)
		guard case .key(let key, let mods)? = events.first else {
			return XCTFail("Expected key event")
		}
		XCTAssertEqual(key, .right)
		XCTAssertTrue(mods.contains(.ctrl))
	}
	
	func testFunctionKeyFromCSI() {
		let sequence: [UInt8] = [0x1B, 0x5B] + Array("15~".utf8) // F5
		let events = events(from: sequence)
		guard case .key(let key, _) = events.first else {
			return XCTFail("Expected key event")
		}
		XCTAssertEqual(key, .function(5))
	}

	func testFunctionKeyF10Variants() {
		let plain: [UInt8] = [0x1B, 0x5B] + Array("21~".utf8)
		let shifted: [UInt8] = [0x1B, 0x5B] + Array("21;2~".utf8)
		let controls: [[UInt8]] = [plain, shifted]
		for seq in controls {
			let events = events(from: seq)
			guard case .key(let key, let mods) = events.first else {
				return XCTFail("Expected key event for sequence \(seq)")
			}
			XCTAssertEqual(key, .function(10))
			if seq == shifted {
				XCTAssertTrue(mods.contains(.shift))
			} else {
				XCTAssertTrue(mods.isEmpty)
			}
		}
	}
	
	func testFunctionKeyFromSS3() {
		let sequence: [UInt8] = [0x1B, 0x4F, 0x50] // ESC O P => F1
		let events = events(from: sequence)
		guard case .key(let key, _) = events.first else {
			return XCTFail("Expected key event")
		}
		XCTAssertEqual(key, .function(1))
	}
	
	func testAltModifiedCharacter() {
		let sequence: [UInt8] = [0x1B, 0x78] // ESC + x
		let events = events(from: sequence)
		guard case .key(let key, let mods) = events.first,
			  case .char(let ch) = key else {
			return XCTFail("Expected alt-char event")
		}
		XCTAssertEqual(ch, "x")
		XCTAssertTrue(mods.contains(.alt))
	}
	
	func testBracketedPaste() {
		let sequence: [UInt8] = [0x1B, 0x5B] + Array("200~Hello\nWorld".utf8) + [0x1B, 0x5B] + Array("201~".utf8)
		let events = events(from: sequence)
		guard case .paste(let payload)? = events.first else {
			return XCTFail("Expected paste event")
		}
		XCTAssertEqual(payload, "Hello\nWorld")
	}
	
	func testFocusEvents() {
		let focusIn: [UInt8] = [0x1B, 0x5B, 0x49]
		let focusOut: [UInt8] = [0x1B, 0x5B, 0x4F]
		let events = events(from: focusIn + focusOut)
		guard events.count == 2 else {
			return XCTFail("Expected two focus events")
		}
		if case .focusGained = events[0] {} else { XCTFail("Expected focusGained") }
		if case .focusLost = events[1] {} else { XCTFail("Expected focusLost") }
	}
	
	func testShiftTab() {
		let sequence: [UInt8] = [0x1B, 0x5B, 0x5A] // ESC [ Z
		let events = events(from: sequence)
		guard case .key(let key, let mods) = events.first else {
			return XCTFail("Expected key event")
		}
		XCTAssertEqual(key, .shiftTab)
		XCTAssertTrue(mods.contains(.shift))
	}
}
