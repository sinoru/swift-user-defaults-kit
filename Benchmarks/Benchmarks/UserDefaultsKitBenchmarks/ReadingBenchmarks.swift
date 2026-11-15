//
//  ReadingBenchmarks.swift
//  UserDefaultsKitBenchmarks
//

import Benchmark
import Foundation
import UserDefaultsKit

/// Registers the benchmarks that read an `Int`: through the subscript, and the two ways
/// Foundation reads the same key without it.
///
/// What they measure is what the subscript costs to read a value, next to what the same costs
/// without it. The question is one the subscript's own history raises. Reading an `Int`
/// used to be a ladder of `as?` casts over `object(forKey:)`; it now goes through a decoder, which
/// builds a value tree out of the stored object and dispatches through `Decodable`. That is more
/// work, and the claim made when the ladder was removed was that it disappears next to the cost
/// of `object(forKey:)` itself. These are the numbers that claim is checked against.
///
/// `integer(forKey:)` is here as a floor: Foundation's own accessor for the same key, doing the
/// least any of them can.
func registerReadingBenchmarks() {
    registerBenchmark("Read an Int through the subscript") { benchmark, userDefaults in
        for _ in benchmark.scaledIterations {
            blackHole(userDefaults["count", default: 0])
        }
    }

    // The shape the ladder had before the decoder took the branch over.
    registerBenchmark("Read an Int through object(forKey:)") { benchmark, userDefaults in
        for _ in benchmark.scaledIterations {
            blackHole((userDefaults.object(forKey: "count") as? Int) ?? 0)
        }
    }

    // Foundation's own accessor, as a floor.
    registerBenchmark("Read an Int through integer(forKey:)") { benchmark, userDefaults in
        for _ in benchmark.scaledIterations {
            blackHole(userDefaults.integer(forKey: "count"))
        }
    }
}
