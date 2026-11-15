//
//  WritingBenchmarks.swift
//  UserDefaultsKitBenchmarks
//

import Benchmark
import Foundation
import UserDefaultsKit

/// Two lists of tags to alternate between, so that no write in a run stores what the key
/// already holds. Long enough that each string needs storage of its own rather than fitting
/// inline.
private let tagLists = [
    (0 ..< 16).map { "the \($0)th element of the first array" },
    (0 ..< 16).map { "the \($0)th element of the second array" },
]

/// Two structures to alternate between, for the same reason. One leaves its optional out and the
/// other does not, so both halves of what the encoder does with it are in every run.
private let profiles = [
    Profile(name: "Kim", age: 30, tags: ["swift", "defaults"]),
    Profile(name: "Lee", age: 31, tags: ["plist"], nickname: "L"),
]

/// Registers the benchmarks that write a value: a scalar, an array and a structure through
/// the subscript, each beside `set(_:forKey:)` wherever Foundation has one.
///
/// What they measure is what the subscript costs to write a value, next to what the same costs
/// without it: a scalar, an array the setter checks is a property list already, and a structure
/// it has to encode.
///
/// The harness runs each body many times over, and the index starts from zero in every one. A run
/// ends on an odd index and the next begins on an even one, so the first write of a run does not
/// store what the last write of the run before it left there either.
func registerWritingBenchmarks() {
    // A scalar through the subscript. Before handing it to Foundation, the setter asks whether the
    // value is a `nil` at any depth and then casts it against the scalars it stores directly.
    registerBenchmark("Write an Int through the subscript") { benchmark, userDefaults in
        for index in benchmark.scaledIterations {
            userDefaults["count"] = index
        }
    }

    // Foundation's own setter for the same scalar, as a floor.
    registerBenchmark("Write an Int through set(_:forKey:)") { benchmark, userDefaults in
        for index in benchmark.scaledIterations {
            userDefaults.set(index, forKey: "count")
        }
    }

    // An array through the subscript, which asks `PropertyListSerialization` whether the value is
    // a property list already before storing it as one.
    registerBenchmark("Write an array through the subscript") { benchmark, userDefaults in
        for index in benchmark.scaledIterations {
            userDefaults["tags"] = tagLists[index % 2]
        }
    }

    // Foundation's own setter for the same array, as a floor.
    registerBenchmark("Write an array through set(_:forKey:)") { benchmark, userDefaults in
        for index in benchmark.scaledIterations {
            userDefaults.set(tagLists[index % 2], forKey: "tags")
        }
    }

    // A structure, which has no property-list form of its own and so goes through the encoder.
    // Foundation has no setter to set beside it.
    registerBenchmark("Write a structure through the subscript") { benchmark, userDefaults in
        for index in benchmark.scaledIterations {
            userDefaults["profile"] = profiles[index % 2]
        }
    }
}
