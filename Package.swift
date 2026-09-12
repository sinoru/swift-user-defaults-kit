// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let commonSwiftSettings: [PackageDescription.SwiftSetting] = [
    .enableUpcomingFeature("ApproachableConcurrency"),
    .strictMemorySafety()
]

let applePlatforms: [PackageDescription.Platform] = [
    .macOS, .macCatalyst, .iOS, .tvOS, .watchOS, .visionOS
]

let package = Package(
    name: "UserDefaultsKit",
    platforms: [
        .macOS(.v12),
        .macCatalyst(.v15),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8),
        .visionOS(.v1),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "UserDefaultsKit",
            targets: ["UserDefaultsKit"],
        ),
    ],
    // A manifest is compiled and run on the build host, so `#if os(...)` here would report the machine
    // doing the building rather than the platform being built for. Gating traits or targets on it lets
    // two machines resolve one package version differently — and the trait set is part of a package's
    // public interface, so that difference is not a private detail. The platform split belongs where it
    // can see the destination: the `.when(platforms:traits:)` conditions below, and the
    // `#if canImport(...)` guards inside the sources.
    traits: [
        .trait(name: "Combine"),
        .trait(name: "SwiftUI", enabledTraits: ["Combine"]),
        .default(enabledTraits: ["Combine", "SwiftUI"]),
    ],
    dependencies: [
        // 1.0.0 is the first release whose API is stable, and the first where `RWLock`'s
        // uncontended paths inline into this package rather than being compiled for the
        // dependency's own iOS 15 minimum. Only the two primitives this package uses are enabled:
        // a trait decides what the umbrella re-exports, and leaving the asynchronous family off
        // keeps its wait queue out of every consumer's build graph.
        .package(
            url: "https://github.com/sinoru/swift-synchronization-kit.git",
            from: "1.0.0",
            traits: ["Mutex", "RWLock"]
        ),
        // The value tree a stored `UserDefaults` object is, and the coder pair that reads and writes one
        // without serializing it. Both started here and moved out, because neither is about
        // `UserDefaults`: what they model is the format, which every one of its values happens to be in.
        // The platform floor over there is this package's, set so that this one can depend on it
        // everywhere it runs.
        .package(
            url: "https://github.com/sinoru/swift-property-list.git",
            "0.0.1"..<"0.1.0"
        ),
    ],
    targets: [
        .target(
            name: "UserDefaultsKit",
            dependencies: [
                "UserDefaultsKitCore",
                .target(
                    name: "UserDefaultsKitCombine",
                    condition: .when(
                        platforms: applePlatforms,
                        traits: ["Combine"]
                    )
                ),
                .target(
                    name: "UserDefaultsKitSwiftUI",
                    condition: .when(
                        platforms: applePlatforms,
                        traits: ["SwiftUI"]
                    )
                ),
            ],
            swiftSettings: commonSwiftSettings,
        ),
        .target(
            name: "UserDefaultsKitCore",
            dependencies: [
                .product(name: "SynchronizationKit", package: "swift-synchronization-kit"),
                .product(name: "PropertyList", package: "swift-property-list"),
            ],
            swiftSettings: commonSwiftSettings,
        ),
        .target(
            name: "UserDefaultsKitCombine",
            dependencies: ["UserDefaultsKitCore"],
            swiftSettings: commonSwiftSettings,
        ),
        .target(
            name: "UserDefaultsKitSwiftUI",
            dependencies: [
                "UserDefaultsKitCore",
                "UserDefaultsKitCombine",
            ],
            swiftSettings: commonSwiftSettings,
        ),
        .target(
            name: "UserDefaultsKitTestSupport",
            swiftSettings: commonSwiftSettings,
        ),
        .testTarget(
            name: "UserDefaultsKitCoreTests",
            dependencies: [
                "UserDefaultsKitTestSupport",
                "UserDefaultsKitCore",
                .product(name: "SynchronizationKit", package: "swift-synchronization-kit"),
            ],
            swiftSettings: commonSwiftSettings,
        ),
        .testTarget(
            name: "UserDefaultsKitCombineTests",
            dependencies: ["UserDefaultsKitTestSupport", "UserDefaultsKitCombine"],
            swiftSettings: commonSwiftSettings,
        ),
        .testTarget(
            name: "UserDefaultsKitSwiftUITests",
            dependencies: ["UserDefaultsKitTestSupport", "UserDefaultsKitSwiftUI"],
            swiftSettings: commonSwiftSettings,
        ),
    ]
)
