// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WheelDropDiag",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "WheelDropDiag",
            path: "Sources/WheelDropDiag",
            swiftSettings: [
                .unsafeFlags(["-suppress-warnings"])
            ]
        )
    ]
)
