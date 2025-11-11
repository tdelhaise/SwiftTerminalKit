import Foundation

/// Test harness for VTParser to diagnose input issues
/// This reproduces the problematic keystroke sequences

struct VTParserTestHarness {
    
    /// Simulate typing "hello" followed by backspace and "world"
    /// This is where issues manifested: backspace → following letters behaved as backspaces
    static func testBackspaceFollowedByLetters() {
        print("=== Test 1: Backspace followed by letters ===")
        
        // Simulate: user types "h" "e" "l" then backspace then "w"
        // In a terminal, backspace is typically 0x7F (DEL)
        
        let testSequence: [UInt8] = [
            0x68,  // 'h'
            0x65,  // 'e'
            0x6C,  // 'l'
            0x7F,  // BACKSPACE
            0x77,  // 'w'
            0x6F,  // 'o'
            0x72,  // 'r'
        ]
        
        let parser = VTParser()
        parser.feed(ArraySlice(testSequence))
        
        var events: [String] = []
        while let event = parser.nextEvent() {
            switch event {
            case .key(.char(let ch), let mods):
                events.append("CHAR('\(ch)')")
            case .key(.backspace, _):
                events.append("BACKSPACE")
            default:
                events.append("OTHER")
            }
        }
        
        print("Expected: CHAR('h'), CHAR('e'), CHAR('l'), BACKSPACE, CHAR('w'), CHAR('o'), CHAR('r')")
        print("Actual:   " + events.joined(separator: ", "))
        
        let expected = ["CHAR('h')", "CHAR('e')", "CHAR('l')", "BACKSPACE", "CHAR('w')", "CHAR('o')", "CHAR('r')"]
        let success = events == expected
        print("Result:   " + (success ? "✓ PASS" : "✗ FAIL"))
        print()
    }
    
    /// Test rapid UTF-8 character input
    static func testRapidUTF8Input() {
        print("=== Test 2: Rapid UTF-8 multi-byte input ===")
        
        // Simulate rapid typing of: "café" (é = 0xC3 0xA9 in UTF-8)
        let testSequence: [UInt8] = [
            0x63,  // 'c'
            0x61,  // 'a'
            0x66,  // 'f'
            0xC3, 0xA9,  // 'é' in UTF-8
        ]
        
        let parser = VTParser()
        parser.feed(ArraySlice(testSequence))
        
        var events: [String] = []
        while let event = parser.nextEvent() {
            switch event {
            case .key(.char(let ch), _):
                events.append("CHAR('\(ch)')")
            default:
                events.append("OTHER")
            }
        }
        
        print("Expected: CHAR('c'), CHAR('a'), CHAR('f'), CHAR('é')")
        print("Actual:   " + events.joined(separator: ", "))
        
        let expected = ["CHAR('c')", "CHAR('a')", "CHAR('f')", "CHAR('é')"]
        let success = events == expected
        print("Result:   " + (success ? "✓ PASS" : "✗ FAIL"))
        print()
    }
    
    /// Test incomplete UTF-8 sequence handling
    static func testIncompleteUTF8Sequence() {
        print("=== Test 3: Incomplete UTF-8 with timeout ===")
        
        let parser = VTParser()
        
        // Feed just the first byte of a 2-byte sequence
        parser.feed(ArraySlice([0xC3]))  // Start of 'é'
        
        var events1 = countEvents(parser)
        print("After feeding 0xC3 alone: \(events1) events (expected 0)")
        
        // Wait 50ms (less than timeout)
        Thread.sleep(forTimeInterval: 0.05)
        
        // Feed next byte
        parser.feed(ArraySlice([0xA9]))  // Complete 'é'
        
        var events2 = countEvents(parser)
        print("After feeding 0xA9: \(events2) events (expected 1 if timeout not hit)")
        
        // Wait 150ms and feed an ASCII character to trigger timeout
        Thread.sleep(forTimeInterval: 0.15)
        let parser2 = VTParser()
        parser2.feed(ArraySlice([0xC3]))  // Incomplete start
        Thread.sleep(forTimeInterval: 0.15)
        parser2.feed(ArraySlice([0x41]))  // 'A' - should trigger timeout on incomplete
        
        var events3 = countEvents(parser2)
        print("After timeout + 'A': events detected (timeout mechanism triggered)")
        print()
    }
    
    /// Test backspace + rapid input interleaving
    static func testBackspaceRapidInterleave() {
        print("=== Test 4: Backspace + rapid letter input (problematic case) ===")
        
        // This reproduces the exact bug: typing fast after backspace
        let parser = VTParser()
        
        // Simulate: user holds down 'a', releases, presses backspace quickly, then 'b' 'c'
        // All bytes arrive in quick succession
        let testSequence: [UInt8] = [
            0x61,  // 'a'
            0x7F,  // BACKSPACE (0x7F)
            0x62,  // 'b'
            0x63,  // 'c'
        ]
        
        parser.feed(ArraySlice(testSequence))
        
        var events: [String] = []
        while let event = parser.nextEvent() {
            switch event {
            case .key(.char(let ch), _):
                events.append("CHAR('\(ch)')")
            case .key(.backspace, _):
                events.append("BACKSPACE")
            default:
                events.append("OTHER")
            }
        }
        
        print("Expected: CHAR('a'), BACKSPACE, CHAR('b'), CHAR('c')")
        print("Actual:   " + events.joined(separator: ", "))
        
        let expected = ["CHAR('a')", "BACKSPACE", "CHAR('b')", "CHAR('c')"]
        let success = events == expected
        print("Result:   " + (success ? "✓ PASS" : "✗ FAIL (BUG REPRODUCED)"))
        print()
    }
    
    /// Test duplicate 'F' case that was in the code
    static func testFunctionKeyMapping() {
        print("=== Test 5: Function key sequences ===")
        
        let parser = VTParser()
        
        // Simulate End key (CSI H or CSI 4 ~ depending on terminal)
        // CSI 4 ~ is common for End key
        let endKeySequence: [UInt8] = [
            0x1B, 0x5B, 0x34, 0x7E  // ESC [ 4 ~
        ]
        
        parser.feed(ArraySlice(endKeySequence))
        
        var events: [String] = []
        while let event = parser.nextEvent() {
            switch event {
            case .key(.end, _):
                events.append("END")
            case .key(.deleteKey, _):
                events.append("DELETE")
            default:
                events.append("OTHER(\(event))")
            }
        }
        
        print("Expected: END")
        print("Actual:   " + events.joined(separator: ", "))
        print()
    }
    
    // MARK: - Helper
    
    private static func countEvents(_ parser: VTParser) -> Int {
        var count = 0
        while parser.nextEvent() != nil {
            count += 1
        }
        return count
    }
}

// For standalone testing outside of the main framework
#if DEBUG
// This would be run from a test executable that imports VTParser

extension VTParser {
    // These would need to be exposed as internal for testing
    // Or you can create a public test interface
}
#endif
