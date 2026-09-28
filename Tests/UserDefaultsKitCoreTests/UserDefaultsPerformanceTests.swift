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

/// What the subscript costs to read and write a value, next to what the same costs without it.
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
/// Writing is measured the same way, against `set(_:forKey:)` wherever Foundation has one: a
/// scalar, an array the setter checks is a property list already, and a structure it has to
/// encode.
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

    // MARK: - Writing

    /// Two values to alternate between, so that no write in a run stores what the key already
    /// holds. Long enough that each string needs storage of its own rather than fitting inline.
    private static let arrays = [
        (0 ..< 16).map { "the \($0)th element of the first array" },
        (0 ..< 16).map { "the \($0)th element of the second array" },
    ]

    private static let profiles = [
        Profile(name: "Kim", age: 30, tags: ["swift", "defaults"]),
        Profile(name: "Lee", age: 31, tags: ["plist"], nickname: "L"),
    ]

    /// A scalar through the subscript. Before handing it to Foundation, the setter asks whether the
    /// value is a `nil` at any depth and then casts it against the scalars it stores directly.
    func testWriteAnIntThroughTheSubscript() {
        measure(metrics: metrics) {
            for index in 0 ..< Self.iterations {
                userDefaults["count"] = index
            }
        }

        XCTAssertEqual(userDefaults.integer(forKey: "count"), Self.iterations - 1)
    }

    /// Foundation's own setter for the same scalar, as a floor.
    func testWriteAnIntThroughSetForKey() {
        measure(metrics: metrics) {
            for index in 0 ..< Self.iterations {
                userDefaults.set(index, forKey: "count")
            }
        }

        XCTAssertEqual(userDefaults.integer(forKey: "count"), Self.iterations - 1)
    }

    /// An array through the subscript, which asks `PropertyListSerialization` whether the value is
    /// a property list already before storing it as one.
    func testWriteAnArrayThroughTheSubscript() {
        let arrays = Self.arrays

        measure(metrics: metrics) {
            for index in 0 ..< Self.iterations {
                userDefaults["tags"] = arrays[index % 2]
            }
        }

        XCTAssertEqual(userDefaults.stringArray(forKey: "tags"), arrays[(Self.iterations - 1) % 2])
    }

    /// Foundation's own setter for the same array, as a floor.
    func testWriteAnArrayThroughSetForKey() {
        let arrays = Self.arrays

        measure(metrics: metrics) {
            for index in 0 ..< Self.iterations {
                userDefaults.set(arrays[index % 2], forKey: "tags")
            }
        }

        XCTAssertEqual(userDefaults.stringArray(forKey: "tags"), arrays[(Self.iterations - 1) % 2])
    }

    /// A structure, which has no property-list form of its own and so goes through the encoder.
    /// Foundation has no setter to set beside it.
    func testWriteAStructureThroughTheSubscript() {
        let profiles = Self.profiles

        measure(metrics: metrics) {
            for index in 0 ..< Self.iterations {
                userDefaults["profile"] = profiles[index % 2]
            }
        }

        XCTAssertEqual(
            userDefaults["profile", type: Profile.self],
            profiles[(Self.iterations - 1) % 2]
        )
    }
}
#endif
