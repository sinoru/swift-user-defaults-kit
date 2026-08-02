//
//  PropertyListValueTests.swift
//  UserDefaultsKitPropertyList
//

import Foundation
import Testing

import UserDefaultsKitPropertyList

@Suite("PropertyListValue")
struct PropertyListValueTests {
    // MARK: - Round Trip

    // Asserts the value rather than the Swift type it lands on, because that type is not the same
    // everywhere: `Int` is 32 bits on arm64_32, so a value `Int` cannot hold there stays an `Int64`.
    @Test(arguments: [
        PropertyListValue.string("Jane Doe"),
        .string(""),
        .data(Data([0x00, 0xFF])),
        .data(Data()),
        .date(Date(timeIntervalSinceReferenceDate: 0)),
        .bool(true),
        .bool(false),
        .integer(0),
        .integer(-1),
        .integer(Int64.min),
        .integer(Int64.max),
        .unsignedInteger(UInt64(Int64.max) + 1),
        .unsignedInteger(UInt64.max),
        .real(0),
        .real(-1.5),
        .real(.infinity),
        .array([]),
        .array([.integer(1), .string("two"), .bool(true), .real(3.5)]),
        .dictionary([:]),
        .dictionary(["name": .string("Jane Doe"), "age": .integer(30)]),
        .array([.dictionary(["tags": .array([.string("swift")])])]),
    ])
    func survivesARoundTripThroughItsPropertyListForm(_ value: PropertyListValue) throws {
        let restored = try #require(PropertyListValue(propertyList: value.propertyList))

        #expect(restored == value)
    }

    // MARK: - Bool

    // The distinction the whole type exists to keep. On Darwin every number arrives as one
    // `NSNumber` type and `NSNumber(value: 1) as? Bool` succeeds, so these two are exactly what a
    // ladder of Swift casts would collapse together.
    @Test
    func readsATrueBooleanRatherThanTheNumberOne() {
        #expect(PropertyListValue(propertyList: true) == .bool(true))
        #expect(PropertyListValue(propertyList: 1) == .integer(1))
    }

    @Test
    func readsAFalseBooleanRatherThanTheNumberZero() {
        #expect(PropertyListValue(propertyList: false) == .bool(false))
        #expect(PropertyListValue(propertyList: 0) == .integer(0))
    }

    // MARK: - Numbers

    // The other collapse a cast ladder would make: `NSNumber` bridging is exactness-checked, so a
    // stored `<real>2</real>` passes `as? Int64` and would arrive as an integer.
    @Test
    func readsAnIntegralRealAsAReal() {
        #expect(PropertyListValue(propertyList: 2.0) == .real(2))
    }

    @Test
    func widensAFloatIntoAReal() {
        #expect(PropertyListValue(propertyList: Float(0.5)) == .real(0.5))
    }

    // The spellings swift-corelibs-foundation reaches for at the ends of the signed range, which is
    // where a ladder written in terms of `Int` alone stops matching.
    @Test
    func readsTheSignedIntegerSpellingsAsOneCase() {
        #expect(PropertyListValue(propertyList: Int.max) == .integer(Int64(Int.max)))
        #expect(PropertyListValue(propertyList: Int64.max) == .integer(Int64.max))
        #expect(PropertyListValue(propertyList: Int64.min) == .integer(Int64.min))
        #expect(PropertyListValue(propertyList: Int8(-1)) == .integer(-1))
        #expect(PropertyListValue(propertyList: UInt32(7)) == .integer(7))
    }

    // `unsignedInteger` carries only what `integer` cannot, so that one number has one spelling.
    @Test
    func readsAnUnsignedValueAsAnIntegerWhileItFits() {
        #expect(PropertyListValue(propertyList: UInt64(7)) == .integer(7))
        #expect(PropertyListValue(propertyList: UInt64(Int64.max)) == .integer(Int64.max))
        #expect(
            PropertyListValue(propertyList: UInt64(Int64.max) + 1)
                == .unsignedInteger(UInt64(Int64.max) + 1)
        )
    }

    // MARK: - Rejection

    private struct NotAPropertyListValue: Sendable {}

    @Test
    func rejectsAValueThePropertyListFormatCannotHold() {
        #expect(PropertyListValue(propertyList: NotAPropertyListValue()) == nil)
    }

    @Test
    func rejectsACollectionHoldingOneAnywhereInside() {
        #expect(PropertyListValue(propertyList: [NotAPropertyListValue()] as [Any]) == nil)
        #expect(
            PropertyListValue(propertyList: ["key": NotAPropertyListValue()] as [String: Any]) == nil
        )
        #expect(
            PropertyListValue(
                propertyList: [["deep": [NotAPropertyListValue()]]] as [Any]
            ) == nil
        )
    }

    // A property list keys its dictionaries by string and nothing else.
    @Test
    func rejectsADictionaryKeyedBySomethingOtherThanAString() {
        #expect(PropertyListValue(propertyList: [1: "one"] as [AnyHashable: Any]) == nil)
    }
}
