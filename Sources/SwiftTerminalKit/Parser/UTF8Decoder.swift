import Foundation

struct UTF8Decoder {
    private var buffer: [UInt8] = []

    mutating func feed(_ bytes: ArraySlice<UInt8>) -> [Character] {
        var out: [Character] = []
        for b in bytes {
            buffer.append(b)
            if let s = String(bytes: buffer, encoding: .utf8) {
                out.append(contentsOf: s)
                buffer.removeAll(keepingCapacity: true)
            } else if buffer.count > 4 {
                buffer.removeAll(keepingCapacity: true)
            }
        }
        return out
    }
}
