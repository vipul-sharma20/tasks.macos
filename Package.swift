// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TaskBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TaskBar",
            path: "Sources/TaskBar"
        ),
    ]
)
