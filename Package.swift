// swift-tools-version: 6.2
// Swift 6.2 is the floor because swift-subprocess 1.0 requires it (Xcode 26 or later).

import PackageDescription

let package = Package(
    name: "organize-my-iphone",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "organize-my-iphone", targets: ["OrganizeCLI"]),
        .library(name: "OrganizeCore", targets: ["OrganizeCore"]),
        .library(name: "OrganizeAdapters", targets: ["OrganizeAdapters"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.2"),
        .package(url: "https://github.com/swiftlang/swift-subprocess.git", from: "1.0.2"),
    ],
    targets: [
        // Pure logic: models, layout codec, classification, planning, rendering. No I/O.
        .target(
            name: "OrganizeCore"
        ),
        // Everything that touches the outside world: cfgutil, HTTP, local models, disk.
        .target(
            name: "OrganizeAdapters",
            dependencies: [
                "OrganizeCore",
                .product(name: "Subprocess", package: "swift-subprocess"),
            ]
        ),
        // The command-line front end.
        .executableTarget(
            name: "OrganizeCLI",
            dependencies: [
                "OrganizeCore",
                "OrganizeAdapters",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "OrganizeCoreTests",
            dependencies: ["OrganizeCore"]
        ),
        .testTarget(
            name: "OrganizeAdaptersTests",
            dependencies: ["OrganizeCore", "OrganizeAdapters"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
