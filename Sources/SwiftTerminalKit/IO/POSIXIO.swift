import Foundation
import Darwin
import CShims

final class POSIXIO: TerminalIO {
    private let inFD: Int32 = 0
    private let outFD: Int32 = 1

    func initRawMode() throws {
        if stk_enable_raw_mode(inFD) != 0 { throw IOError("enable raw mode failed") }
        if stk_set_nonblocking(inFD, 1) != 0 { throw IOError("nonblocking failed") }
    }

    func restoreMode() {
        _ = stk_restore_mode(inFD)
        _ = stk_set_nonblocking(inFD, 0)
    }

    func write(_ bytes: [UInt8]) {
        bytes.withUnsafeBytes { ptr in
            _ = Darwin.write(outFD, ptr.baseAddress, ptr.count)
        }
    }

    func read(into buffer: inout [UInt8], timeoutMs: Int) -> Int {
        var rfds = fd_set()
        fdZero(&rfds)
        fdSet(inFD, &rfds)

        var tv = timeval(tv_sec: 0, tv_usec: 0)
        var tvPtr: UnsafeMutablePointer<timeval>? = nil
        if timeoutMs >= 0 {
            tv.tv_sec = time_t(timeoutMs / 1000)
            tv.tv_usec = suseconds_t((timeoutMs % 1000) * 1000)
            tvPtr = .allocate(capacity: 1)
            tvPtr!.initialize(to: tv)
        }

        let sel = select(inFD + 1, &rfds, nil, nil, tvPtr)
        if let p = tvPtr { p.deinitialize(count: 1); p.deallocate() }
        if sel <= 0 { return 0 }

        return buffer.withUnsafeMutableBytes { ptr in
            let n = Darwin.read(inFD, ptr.baseAddress, ptr.count)
            return n
        }
    }

    var size: (cols: Int, rows: Int) {
        var c: Int32 = 0
        var r: Int32 = 0
        _ = stk_get_winsize(outFD, &c, &r)
        return (Int(c), Int(r))
    }

    func flush() { /* unbuffered */ }
}

// MARK: - Helpers

struct IOError: Error, CustomStringConvertible {
    let message: String
    init(_ message: String) { self.message = message }
    var description: String { message }
}

// Safe fd_set helpers
fileprivate func fdZero(_ set: inout fd_set) {
    let size = MemoryLayout.size(ofValue: set)
    withUnsafeMutableBytes(of: &set) { buf in
        buf.baseAddress!.assumingMemoryBound(to: UInt8.self).update(repeating: 0, count: size)
    }
}
fileprivate func fdSet(_ fd: Int32, _ set: inout fd_set) {
    let intOffset = Int(fd / 32)
    let bitOffset = UInt32(fd % 32)
    withUnsafeMutablePointer(to: &set) {
        $0.withMemoryRebound(to: UInt32.self, capacity: (MemoryLayout<fd_set>.size / MemoryLayout<UInt32>.size)) { ptr in
            ptr[intOffset] |= (1 << bitOffset)
        }
    }
}
