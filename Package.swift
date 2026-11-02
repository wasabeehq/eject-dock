// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EjectDock",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "EjectDock", targets: ["EjectDock"])],
    targets: [
        .target(name: "EjectDockCore"),
        .executableTarget(name: "EjectDock", dependencies: ["EjectDockCore"], resources: [.process("Resources")]),
        .testTarget(name: "EjectDockCoreTests", dependencies: ["EjectDockCore"], resources: [.copy("Fixtures")])
    ]
)
