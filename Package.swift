// swift-tools-version: 6.2

import PackageDescription

// Package name matches the repo directory (`apxy-ios`) so Xcode local path
// dependencies resolve without a package-graph identity mismatch.
let package = Package(
    name: "apxy-ios",
    platforms: [
        .iOS(.v14),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "ApxyCore",
            targets: ["ApxyCore"]
        ),
        .library(
            name: "ApxyUI",
            targets: ["ApxyUI"]
        ),
    ],
    targets: [
        .target(
            name: "ApxyCore",
            path: "Sources/ApxyCore",
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug)),
            ]
        ),
        .target(
            name: "ApxyUI",
            dependencies: ["ApxyCore"],
            path: "Sources/ApxyUI",
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug)),
            ]
        ),
        .testTarget(
            name: "ApxyCoreTests",
            dependencies: ["ApxyCore"],
            path: "Tests/ApxyCoreTests"
        ),
        .testTarget(
            name: "ApxyUITests",
            dependencies: ["ApxyCore", "ApxyUI"],
            path: "Tests/ApxyUITests"
        ),
    ]
)
