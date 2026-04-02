// swift-tools-version: 5.9

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
            name: "ApxySDK",
            targets: ["ApxySDK"]
        ),
    ],
    targets: [
        .target(
            name: "ApxySDK",
            path: "Sources/ApxySDK",
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug)),
            ]
        ),
        .testTarget(
            name: "ApxySDKTests",
            dependencies: ["ApxySDK"],
            path: "Tests/ApxySDKTests"
        ),
    ]
)
