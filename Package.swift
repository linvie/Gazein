// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Gazein",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "Gazein", targets: ["Gazein"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.0")
    ],
    targets: [
        .executableTarget(
            name: "Gazein",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "GazeinTests",
            dependencies: ["Gazein"],
            path: "Tests"
        )
    ]
)
