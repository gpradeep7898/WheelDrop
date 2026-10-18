// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WheelDrop",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "WheelDrop",
            path: "Sources/WheelDrop",
            swiftSettings: [.unsafeFlags(["-suppress-warnings"])]
        )
    ]
)
