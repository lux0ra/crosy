// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Crosy",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Crosy", path: "Sources/CrosshairOverlay"),
        .testTarget(name: "CrosyTests", dependencies: ["Crosy"])
    ]
)
