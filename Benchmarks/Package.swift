// swift-tools-version: 6.3

import PackageDescription

// A package of its own rather than a target of the one above it, so that nothing a consumer
// resolves ever includes the benchmark harness: the manifest they read never names it, and this
// one is only ever opened from inside this directory.
let package = Package(
    name: "Benchmarks",
    // The harness's floor, not the library's. The library deploys further back than this and is
    // not held to it by being measured here.
    platforms: [
        .macOS(.v13),
    ],
    dependencies: [
        // No traits: what is measured is the storage half, which is the core alone. The default
        // set would build the Combine and SwiftUI halves beside it and measure neither.
        .package(path: "../", traits: []),
        .package(url: "https://github.com/ordo-one/benchmark.git", from: "1.36.4"),
    ],
    targets: [
        .executableTarget(
            name: "UserDefaultsKitBenchmarks",
            dependencies: [
                .product(name: "Benchmark", package: "benchmark"),
                .product(name: "UserDefaultsKit", package: "swift-user-defaults-kit"),
            ],
            path: "Benchmarks/UserDefaultsKitBenchmarks",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("ImmutableWeakCaptures"),
                .strictMemorySafety(),
            ],
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "benchmark"),
            ]
        ),
    ]
)
