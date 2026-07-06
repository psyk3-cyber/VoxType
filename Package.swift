// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "VoxType",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "VoxType",
            path: "Sources/VoxType"
        )
    ]
)
