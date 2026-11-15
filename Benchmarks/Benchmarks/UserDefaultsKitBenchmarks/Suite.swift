//
//  Suite.swift
//  UserDefaultsKitBenchmarks
//

import Benchmark
import Foundation

/// Why a benchmark could not be given a suite to run against.
private enum SuiteError: Error, CustomStringConvertible {
    /// Foundation refused the name.
    case cannotOpen(String)
    /// The suite took a write and did not hand it back.
    case cannotReadBack(String)
    /// The suite took a write and the defaults system would not keep it.
    case cannotSynchronize(String)

    var description: String {
        switch self {
        case .cannotOpen(let suiteName):
            "UserDefaults would not open the suite \(suiteName)."
        case .cannotReadBack(let suiteName):
            "The suite \(suiteName) did not hand back the value just written to it."
        case .cannotSynchronize(let suiteName):
            """
            The suite \(suiteName) could not be synchronized, so nothing written to it is being \
            kept. Under SwiftPM's plugin sandbox that is every write: run the benchmarks with \
            `swift package --disable-sandbox benchmark`.
            """
        }
    }
}

/// Registers a benchmark that runs against a `UserDefaults` suite of its own, emptied once the
/// benchmark finishes.
///
/// A suite each, so that no benchmark reads what another wrote. The suite starts with `"count"`
/// holding `42`, which is what the reading benchmarks read.
///
/// The seed is read back and the suite synchronized before anything is measured, and it is the
/// second that matters. SwiftPM runs a plugin in a sandbox that cannot write to the preferences
/// directory, and on Darwin the defaults daemon turns down a write from a process that could not
/// have made it itself. Nothing reports that at the call: the value is in this process's cache
/// and reads back from there, while no other process ever sees it and no file is written.
/// A benchmark run that way measures a refusal — for a scalar, nearly twice the instructions
/// of a write that is kept, and several times the clock — so it is stopped here instead.
///
/// `synchronize()` is the one call that says so, which is the only reason to make it: Apple
/// documents the method as unnecessary and not to be used, and for getting a write to disk it
/// is. What is wanted here is its answer, and nothing else in the process gives one.
///
/// Emptied, not removed: `removePersistentDomain(forName:)` takes the keys out, and on Darwin
/// the daemon leaves an empty property list where the suite was and puts it back if it is
/// deleted from here.
///
/// - Parameters:
///   - name: The name the benchmark is reported and matched against a baseline under.
///   - body: The work to measure, handed the benchmark and its suite.
func registerBenchmark(
    _ name: String,
    _ body: @escaping (_ benchmark: Benchmark, _ userDefaults: UserDefaults) -> Void
) {
    // The harness hands a teardown nothing, so the name is made here, where both closures can
    // capture it.
    let suiteName = "UserDefaultsKitBenchmarks.\(UUID().uuidString)"

    Benchmark(name) { benchmark, userDefaults in
        body(benchmark, userDefaults)
    } setup: {
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            throw SuiteError.cannotOpen(suiteName)
        }

        userDefaults.set(42, forKey: "count")

        guard userDefaults.integer(forKey: "count") == 42 else {
            throw SuiteError.cannotReadBack(suiteName)
        }

        guard userDefaults.synchronize() else {
            throw SuiteError.cannotSynchronize(suiteName)
        }

        return userDefaults
    } teardown: {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }
}
