// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

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
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "FormulaKit",
            targets: ["FormulaKit"]
        ),
        .executable(
            name: "FormulaKitSample",
            targets: ["FormulaKitSample"]
        ),
        .executable(
            name: "MathImage",
            targets: ["MathImage"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "FormulaKit"
        ),
        .executableTarget(
            name: "FormulaKitSample",
            dependencies: ["FormulaKit"]
        ),
        .executableTarget(
            name: "MathImage",
            dependencies: ["FormulaKit"]
        ),
        .testTarget(
            name: "FormulaKitTests",
            dependencies: ["FormulaKit"]
        ),
    ]
)
