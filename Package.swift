// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EjectDock",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "EjectDock", targets: ["EjectDock"])],
    targets: [
        .target(name: "EjectDockCore"),
        .executableTarget(name: "EjectDock", dependencies: ["EjectDockCore"]),
        .testTarget(name: "EjectDockCoreTests", dependencies: ["EjectDockCore"])
    ]
)
