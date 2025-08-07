// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MXMasterGestureControl",
    platforms: [
        .macOS(.v10_15) // Required for Core Graphics and AppKit features
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .executable(
            name: "mxmaster-gesture-control",
            targets: ["MXMasterGestureControl"]
        )
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // No external dependencies needed for this project
    ],
    targets: [
        // Main executable target
        .executableTarget(
            name: "MXMasterGestureControl",
            dependencies: [],
            path: "Sources/MXMasterGestureControl"
        ),
        // Test target
        .testTarget(
            name: "MXMasterGestureControlTests",
            dependencies: ["MXMasterGestureControl"],
            path: "Tests/MXMasterGestureControlTests"
        )
    ]
)
