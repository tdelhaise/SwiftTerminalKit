import SwiftTerminalKit
import Foundation

do {
    let app = try TextEditDemoApp()
    try app.run()
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}
