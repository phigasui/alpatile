// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "alpatile",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "alpatile", targets: ["alpatile"]),
        .executable(name: "alpatiled", targets: ["alpatiled"]),
        .library(name: "AlpatileCore", targets: ["AlpatileCore"]),
    ],
    targets: [
        .target(
            name: "AlpatileCore",
            dependencies: [],
            path: "Sources/AlpatileCore"
        ),
        .executableTarget(
            name: "alpatile",
            dependencies: ["AlpatileCore"],
            path: "Sources/alpatile"
        ),
        .executableTarget(
            name: "alpatiled",
            dependencies: ["AlpatileCore"],
            path: "Sources/alpatiled"
        ),
        .testTarget(
            name: "AlpatileCoreTests",
            dependencies: ["AlpatileCore"],
            path: "Tests/AlpatileCoreTests"
        ),
    ]
)
