import Foundation

final class VTParser {
    private var bytes: [UInt8] = []
    private var utf8 = UTF8Decoder()
    private var eventQueue: [Event] = []

    func feed(_ slice: ArraySlice<UInt8>) {
        bytes.append(contentsOf: slice)
        parse()
    }

    func nextEvent() -> Event? {
        eventQueue.isEmpty ? nil : eventQueue.removeFirst()
    }

    private func parse() {
        var i = 0
        while i < bytes.count {
            let b = bytes[i]
            if b == 0x1b { // ESC
                if i + 2 < bytes.count, bytes[i+1] == 0x5b { // CSI
                    let c = bytes[i+2]
                    let key: Key?
                    switch c {
						case 0x41: key = .up
						case 0x42: key = .down
						case 0x43: key = .right
						case 0x44: key = .left
						default: key = .unknown
                    }
                    if let k = key {
                        eventQueue.append(.key(k, []))
                        i += 3
                        continue
                    }
                }
                eventQueue.append(.key(.esc, []))
                i += 1
                continue
            } else if b == 0x7f {
                eventQueue.append(.key(.backspace, []))
                i += 1
                continue
			} else if b == 0x09 {
				eventQueue.append(.key(.tab, []))
				i += 1
				continue
			} else if b == 0x19 {
				eventQueue.append(.key(.shiftTab, [Modifiers.shift]))
				i += 1
				continue
            } else if b == 0x0d || b == 0x0a {
                eventQueue.append(.key(.enter, []))
                i += 1
                continue
            } else if b < 0x20 {
                i += 1
                continue
            } else {
                let remaining = bytes[i...]
                let chars = utf8.feed(remaining)
                if !chars.isEmpty {
                    for ch in chars { eventQueue.append(.key(.char(ch), [])) }
                    i = bytes.count
                    continue
                } else {
                    break
                }
            }
        }
        if i > 0 && i <= bytes.count {
            bytes.removeFirst(i)
        }
    }
}
