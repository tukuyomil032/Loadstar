// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "LoadStar",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .library(name: "LoadStarDomain", targets: ["LoadStarDomain"]),
        .library(name: "LoadStarPersistence", targets: ["LoadStarPersistence"]),
        .library(name: "LoadStarPlatform", targets: ["LoadStarPlatform"]),
        .library(name: "LoadStarServices", targets: ["LoadStarServices"]),
        .library(name: "LoadStarFeatures", targets: ["LoadStarFeatures"]),
        .library(name: "LoadStarUI", targets: ["LoadStarUI"]),
        .library(name: "LoadStarGuide", targets: ["LoadStarGuide"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/Defaults.git", from: "9.0.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0"),
        .package(url: "https://github.com/krzyzanowskim/STTextView.git", from: "0.9.0"),
    ],
    targets: [
        .target(name: "LoadStarDomain", path: "Loadstar/Domain"),
        .target(
            name: "LoadStarPersistence",
            dependencies: ["LoadStarDomain", .product(name: "Defaults", package: "Defaults")],
            path: "Loadstar/Persistence"
        ),
        .target(name: "LoadStarPlatform", dependencies: ["LoadStarDomain"], path: "Loadstar/Platform"),
        .target(
            name: "LoadStarServices",
            dependencies: ["LoadStarDomain", "LoadStarPersistence", "LoadStarPlatform", .product(name: "Sparkle", package: "Sparkle")],
            path: "Loadstar/Services"
        ),
        .target(
            name: "LoadStarFeatures",
            dependencies: ["LoadStarDomain", "LoadStarPersistence", "LoadStarServices"],
            path: "Loadstar/Features"
        ),
        .target(
            name: "LoadStarUI",
            dependencies: ["LoadStarDomain", "LoadStarFeatures", "LoadStarServices", .product(name: "STTextView", package: "STTextView")],
            path: "Loadstar/UI"
        ),
        .target(name: "LoadStarGuide", dependencies: ["LoadStarDomain", "LoadStarUI"], path: "Loadstar/Guide"),
        .testTarget(name: "LoadStarDomainTests", dependencies: ["LoadStarDomain"], path: "Tests/LoadStarDomainTests"),
        .testTarget(name: "LoadStarPersistenceTests", dependencies: ["LoadStarPersistence"], path: "Tests/LoadStarPersistenceTests"),
        .testTarget(name: "LoadStarPlatformTests", dependencies: ["LoadStarPlatform"], path: "Tests/LoadStarPlatformTests"),
        .testTarget(name: "LoadStarServicesTests", dependencies: ["LoadStarServices"], path: "Tests/LoadStarServicesTests"),
        .testTarget(name: "LoadStarFeaturesTests", dependencies: ["LoadStarFeatures"], path: "Tests/LoadStarFeaturesTests"),
        .testTarget(name: "LoadStarUITests", dependencies: ["LoadStarUI"], path: "Tests/LoadStarUITests"),
        .testTarget(name: "LoadStarIntegrationTests", dependencies: ["LoadStarServices"], path: "Tests/LoadStarIntegrationTests"),
        .testTarget(name: "LoadStarAcceptanceTests", dependencies: ["LoadStarFeatures", "LoadStarUI"], path: "Tests/LoadStarAcceptanceTests"),
    ]
)
