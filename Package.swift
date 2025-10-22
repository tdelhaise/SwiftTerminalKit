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
		.executable(name: "ColorPaletteDemo", targets: ["ColorPaletteDemo"]),
		.executable(name: "GradientDemo", targets: ["GradientDemo"]),
		.executable(name: "Utf8TableDemo", targets: ["Utf8TableDemo"]),
		.executable(name: "ViewsDemo", targets: ["ViewsDemo"]),
    ],
    targets: [
        .target(name: "CShims", path: "CShims", publicHeadersPath: "."),
        .target(name: "SwiftTerminalKit", dependencies: ["CShims"], path: "Sources/SwiftTerminalKit"),
        .executableTarget(name: "BasicDemo", dependencies: ["SwiftTerminalKit"], path: "Examples/BasicDemo"),
		.executableTarget(name: "GradientDemo", dependencies: ["SwiftTerminalKit"], path: "Examples/GradientDemo"),
		.executableTarget(name: "ColorPaletteDemo", dependencies: ["SwiftTerminalKit"], path: "Examples/ColorPaletteDemo"),
		.executableTarget(
			name: "Utf8TableDemo",
			dependencies: ["SwiftTerminalKit"],
			path: "Examples/Utf8TableDemo"
		),
		.executableTarget(
			name: "ViewsDemo",
			dependencies: ["SwiftTerminalKit"],
			path: "Examples/ViewsDemo"
		),
        .testTarget(name: "SwiftTerminalKitTests", dependencies: ["SwiftTerminalKit"])
    ]
)
