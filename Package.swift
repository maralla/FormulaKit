// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FormulaKit",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        .library(
            name: "FormulaKit",
            targets: ["FormulaKit"]
        ),
    ],
    targets: [
        .target(
            name: "FormulaKit",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "FormulaKitTests",
            dependencies: ["FormulaKit"]
        ),
    ]
)
