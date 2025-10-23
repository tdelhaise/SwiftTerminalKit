import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import CShims

// Type utilitaire pour manipuler les flags de termios de façon portable.
fileprivate typealias TCFlag = tcflag_t

final class POSIXIO: TerminalIO {
	private let inFD: Int32 = 0
	private let outFD: Int32 = 1
	
	private var origTerm: termios = termios()
	private var rawInstalled = false
	
	func initRawMode() throws {
		guard !rawInstalled else { return }
		
		// Sauvegarde
		if tcgetattr(inFD, &origTerm) != 0 {
			throw NSError(domain: "POSIXIO", code: 1, userInfo: [NSLocalizedDescriptionKey:"tcgetattr failed"])
		}
		var raw = origTerm
		
		// -------- Input flags --------
		// Désactiver: BRKINT, ICRNL, INPCK, ISTRIP, IXON, IXOFF (clé pour ^S/^Q)
		let inMask: TCFlag =
		TCFlag(BRKINT) |
		TCFlag(ICRNL)  |
		TCFlag(INPCK)  |
		TCFlag(ISTRIP) |
		TCFlag(IXON)   |
		TCFlag(IXOFF)
		raw.c_iflag &= ~inMask
		
		// -------- Output flags --------
		// Pas de post-processing
		let outMask: TCFlag = TCFlag(OPOST)
		raw.c_oflag &= ~outMask
		
		// -------- Control flags --------
		// 8 bits par caractère
		raw.c_cflag |= TCFlag(CS8)
		
		// -------- Local flags --------
		// Pas d’écho, pas de mode canonique, pas de signaux, pas d’extensions
		let localMask: TCFlag =
		TCFlag(ECHO)   |
		TCFlag(ICANON) |
		TCFlag(IEXTEN) |
		TCFlag(ISIG)
		raw.c_lflag &= ~localMask
		
		// -------- Lecture non bloquante (ajuste au besoin) --------
		// VMIN = 0, VTIME = 1 (dixièmes de seconde) => timeout 100 ms
		raw.c_cc.0 = 0  // VMIN
		raw.c_cc.1 = 1  // VTIME
		
		if tcsetattr(inFD, TCSAFLUSH, &raw) != 0 {
			throw NSError(domain: "POSIXIO", code: 2, userInfo: [NSLocalizedDescriptionKey:"tcsetattr failed"])
		}
		rawInstalled = true
	}
	
	func restoreMode() {
		if rawInstalled {
			_ = tcsetattr(inFD, TCSAFLUSH, &origTerm)
			rawInstalled = false
		}
	}
	
	func write(_ bytes: [UInt8]) {
		bytes.withUnsafeBytes { ptr in
#if canImport(Darwin)
			_ = Darwin.write(outFD, ptr.baseAddress, ptr.count)
#elseif canImport(Glibc)
			_ = Glibc.write(outFD, ptr.baseAddress, ptr.count)
#endif
		}
	}
	
	func read(into buffer: inout [UInt8], timeoutMs: Int) -> Int {
		var rfds = fd_set()
		fdZero(&rfds)
		fdSet(inFD, &rfds)
		
		// timeval portable
#if canImport(Darwin)
		typealias STUsec = __darwin_suseconds_t
#else
		typealias STUsec = suseconds_t
#endif
		var tv = timeval(tv_sec: 0, tv_usec: 0)
		var tvPtr: UnsafeMutablePointer<timeval>? = nil
		
		if timeoutMs < 0 {
			tvPtr = nil
		} else {
			let usec: STUsec = STUsec((timeoutMs % 1000) * 1000)
			tv = timeval(tv_sec: timeoutMs / 1000, tv_usec: usec)
			tvPtr = UnsafeMutablePointer<timeval>.allocate(capacity: 1)
			tvPtr!.initialize(to: tv)
		}
		
		let sel = select(inFD + 1, &rfds, nil, nil, tvPtr)
		if let p = tvPtr { p.deinitialize(count: 1); p.deallocate() }
		if sel <= 0 { return 0 }
		
		return buffer.withUnsafeMutableBytes { ptr in
#if canImport(Darwin)
			let n = Darwin.read(inFD, ptr.baseAddress, ptr.count)
#else
			let n = Glibc.read(inFD, ptr.baseAddress, ptr.count)
#endif
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

// MARK: - fd_set helpers

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
		$0.withMemoryRebound(to: UInt32.self,
							 capacity: (MemoryLayout<fd_set>.size / MemoryLayout<UInt32>.size)) { ptr in
			ptr[intOffset] |= (1 << bitOffset)
		}
	}
}
