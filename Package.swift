// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let commonSwiftSettings: [PackageDescription.SwiftSetting] = [
    .enableUpcomingFeature("ApproachableConcurrency"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("ImmutableWeakCaptures"),
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
        .trait(name: "SwiftUI"),
        .default(enabledTraits: ["Combine", "SwiftUI"]),
    ],
    dependencies: [
        // Only the one primitive this package uses is enabled: a trait decides what the umbrella
        // re-exports, and leaving the rest off keeps the reader-writer lock, the atomics it is
        // built on, and the asynchronous family's wait queue out of every consumer's build graph.
        // 1.1.2 was the floor an `RWLock` needed while one guarded an observation's handlers.
        // `Mutex` asks for nothing that recent, and the floor stays only because nothing lower
        // has been built against since.
        .package(
            url: "https://github.com/sinoru/swift-synchronization-kit.git",
            from: "1.1.2",
            traits: ["Mutex"]
        ),
        // The value tree a stored `UserDefaults` object is, and the coder pair that reads and writes one
        // without serializing it. Both started here and moved out, because neither is about
        // `UserDefaults`: what they model is the format, which every one of its values happens to be in.
        // The platform floor over there is this package's, set so that this one can depend on it
        // everywhere it runs.
        //
        // `ValueFoundation` is what keeps the bridge to `Any` compiled in away from Apple platforms:
        // from 0.1.0 the package reads `Data` and `Date` from FoundationEssentials there, and only
        // that trait brings Foundation itself back. Reading and writing a stored object is that
        // bridge, and `UserDefaults` lives in Foundation anyway, so enabling it links nothing a
        // consumer here was not already linking. A dependency's traits cannot be conditioned on the
        // platform, so it is on everywhere; on Apple platforms it changes nothing.
        //
        // From 1.0.0 it brings swift-core-foundation-kit with it, which is what tells a stored object
        // apart by its CoreFoundation type ID on Apple platforms. Other platforms resolve that
        // package and build none of it.
        .package(
            url: "https://github.com/sinoru/swift-property-list.git",
            from: "1.0.0",
            traits: [.defaults, "ValueFoundation"]
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
            dependencies: ["UserDefaultsKitCore"],
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
