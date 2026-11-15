//
//  Benchmarks.swift
//  UserDefaultsKitBenchmarks
//

import Benchmark

/// What the harness runs: every benchmark in this target, registered in the order it is reported.
///
/// Instructions retired is the number to read. A read is small enough that the clock varies by
/// more between runs than the differences being measured, and the wall clock is reported only so
/// that a number that moved can be seen to have moved the time with it. Allocations and
/// retain/release traffic are counted because the subscript's share of a read or a write is a
/// value tree built and a stored object bridged, and that is where both show.
///
/// Every count is this process's. What the defaults daemon does with a write happens in another
/// one and is in none of them, on either side of a comparison.
///
/// Nothing here fails on a regression, and no threshold is checked in: a number means something
/// next to the number beside it, or next to a baseline taken on the same machine, not next to one
/// from another machine.
let benchmarks: @Sendable () -> Void = {
    // The harness keeps its defaults in a `nonisolated(unsafe)` static. It calls this closure once,
    // before any benchmark runs, so nothing else is reading it while it is written.
    unsafe Benchmark.defaultConfiguration = .init(
        metrics: [
            .instructions,
            .mallocCountTotal,
            .retainCount,
            .releaseCount,
            .wallClock,
        ],
        scalingFactor: .kilo
    )

    registerReadingBenchmarks()
    registerWritingBenchmarks()
}
