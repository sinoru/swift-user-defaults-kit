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

// A manifest is compiled and run on the build host, so `#if os(...)` here would report the machine
// doing the building rather than the platform being built for. Gating traits or targets on it lets
// two machines resolve one package version differently — and the trait set is part of a package's
// public interface, so that difference is not a private detail. The platform split belongs where it
// can see the destination: the `.when(platforms:traits:)` conditions below, and the
// `#if canImport(...)` guards inside the sources.
let traits: Set<PackageDescription.Trait> = [
    .trait(name: "Combine"),
    .trait(name: "SwiftUI", enabledTraits: ["Combine"]),
    .default(enabledTraits: ["Combine", "SwiftUI"]),
]

// The floor is 0.0.2 rather than 0.0.1 because a consumer resolves this range for itself and never
// sees this package's `Package.resolved`. 0.0.2 is where `RWLock` stopped drawing ThreadSanitizer
// reports on the Mach semaphore backend — which is every deployment target this package supports
// below macOS 14.4 and iOS 17.4 — and where `_MutexHandle`/`_RWLockHandle`, public in 0.0.1 by
// oversight, went back to being plumbing.
let dependencies: [PackageDescription.Package.Dependency] = [
    .package(
        url: "https://github.com/sinoru/swift-synchronization-kit.git",
        "0.0.2"..<"0.1.0"
    ),
]

let targets: [PackageDescription.Target] = [
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
    traits: traits,
    dependencies: dependencies,
    targets: targets
)
