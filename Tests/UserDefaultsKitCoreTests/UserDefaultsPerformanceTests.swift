//
//  UserDefaultsPerformanceTests.swift
//  UserDefaultsKit
//

// XCTest rather than the testing library: measurement has no equivalent there, and the two coexist
// in one target. Darwin only, because `XCTMetric` does.
#if canImport(Darwin)
import Foundation
import UserDefaultsKitTestSupport
import XCTest

import UserDefaultsKitCore

/// What the subscript costs to read a scalar, next to what reading the same key without it costs.
///
/// The question this exists to answer is one the subscript's own history raises. Reading an `Int`
/// used to be a ladder of `as?` casts over `object(forKey:)`; it now goes through a decoder, which
/// allocates a node and dispatches through `Decodable`. That is more work, and the claim made when
/// the ladder was removed was that it disappears next to the cost of `object(forKey:)` itself.
/// These are the numbers that claim was never checked against.
///
/// `integer(forKey:)` is here as a floor: Foundation's own accessor for the same key, doing the
/// least any of them can.
///
/// Every case is skipped in a debug build, where an unoptimized measurement says nothing about
/// anything, so an ordinary `swift test` is untouched. Measure in release:
///
///     swift test -c release -Xswiftc -enable-testing \
///         --filter UserDefaultsPerformanceTests
///
/// Nothing here fails on a regression. A number means something next to the number beside it, not
/// next to one from another machine.
final class UserDefaultsPerformanceTests: XCTestCase {
    private var suiteName = ""
    private var userDefaults = UserDefaults.standard

    private static let iterations = 1_000

    /// Built fresh per call: `XCTMetric` is not `Sendable`, so one shared array could not be a
    /// static, and a metric is free to carry state from the run it just took part in.
    private var metrics: [any XCTMetric] {
        [XCTClockMetric(), XCTCPUMetric()]
    }

    override func setUpWithError() throws {
        #if DEBUG
        throw XCTSkip("Measurements only mean something optimized; build for release.")
        #else
        try XCTSkipIf(
            threadSanitizerIsLoaded,
            "A measurement taken under ThreadSanitizer would not mean anything."
        )

        suiteName = "UserDefaultsKitTests.\(UUID().uuidString)"
        userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        userDefaults.set(42, forKey: "count")
        #endif
    }

    override func tearDown() {
        // XCTest runs this even when `setUpWithError()` threw, which is every debug run and every
        // sanitized one. The suite has no name yet there, and calling this anyway would be a
        // mutating call on `UserDefaults.standard` with an empty domain.
        guard suiteName.isEmpty == false else { return }

        userDefaults.removePersistentDomain(forName: suiteName)
    }

    func testReadAnIntThroughTheSubscript() {
        var total = 0

        measure(metrics: metrics) {
            for _ in 0 ..< Self.iterations {
                total += userDefaults["count", default: 0]
            }
        }

        // A measurement whose work was optimized away reports excellent numbers.
        XCTAssertGreaterThan(total, 0)
    }

    /// The shape the ladder had before the decoder took the branch over.
    func testReadAnIntThroughObjectForKey() {
        var total = 0

        measure(metrics: metrics) {
            for _ in 0 ..< Self.iterations {
                total += (userDefaults.object(forKey: "count") as? Int) ?? 0
            }
        }

        XCTAssertGreaterThan(total, 0)
    }

    /// Foundation's own accessor, as a floor.
    func testReadAnIntThroughIntegerForKey() {
        var total = 0

        measure(metrics: metrics) {
            for _ in 0 ..< Self.iterations {
                total += userDefaults.integer(forKey: "count")
            }
        }

        XCTAssertGreaterThan(total, 0)
    }
}
#endif
