// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "summon",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "summon", targets: ["summon"]),
        .library(name: "SummonKit", targets: ["SummonKit"]),
    ],
    targets: [
        .target(
            name: "SummonKit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "summon",
            dependencies: ["SummonKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SummonKitTests",
            dependencies: ["SummonKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SummonAppsPluginTests",
            dependencies: ["SummonKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SummonCursorPluginTests",
            dependencies: ["SummonKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SummonTests",
            dependencies: ["summon", "SummonKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
