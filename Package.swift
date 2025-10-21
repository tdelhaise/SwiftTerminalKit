// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftTerminalKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "SwiftTerminalKit", targets: ["SwiftTerminalKit"]),
        .executable(name: "BasicDemo", targets: ["BasicDemo"]),
    ],
    targets: [
        .target(name: "CShims", path: "CShims", publicHeadersPath: "."),
        .target(name: "SwiftTerminalKit", dependencies: ["CShims"], path: "Sources/SwiftTerminalKit"),
        .executableTarget(name: "BasicDemo", dependencies: ["SwiftTerminalKit"], path: "Examples/BasicDemo"),
        .testTarget(name: "SwiftTerminalKitTests", dependencies: ["SwiftTerminalKit"])
    ]
)
