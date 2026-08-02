//
//  PropertyListValueEncoderTests.swift
//  UserDefaultsKitPropertyList
//

import Foundation
import Testing

import UserDefaultsKitPropertyList

@Suite("PropertyListValueEncoder")
struct PropertyListValueEncoderTests {
    private let encoder = PropertyListValueEncoder()
    private let decoder = PropertyListValueDecoder()

    private struct Profile: Codable, Equatable {
        var name: String
        var age: Int
        var tags: [String]
        var nickname: String?
    }

    private enum Theme: String, Codable {
        case light
        case dark
    }

    // MARK: - Scalars

    @Test
    func writesEachScalarInTheShapeThePropertyListHas() throws {
        #expect(try encoder.encode(true) == .bool(true))
        #expect(try encoder.encode("hello") == .string("hello"))
        #expect(try encoder.encode(42) == .integer(42))
        #expect(try encoder.encode(3.25) == .real(3.25))
        #expect(try encoder.encode(Float(0.5)) == .real(0.5))
        #expect(try encoder.encode(Data([0x01])) == .data(Data([0x01])))
        #expect(
            try encoder.encode(Date(timeIntervalSinceReferenceDate: 5))
                == .date(Date(timeIntervalSinceReferenceDate: 5))
        )
    }

    // `<true/>` rather than `<integer>1</integer>`, which is what keeps `defaults(1)` printing it as
    // a boolean and what lets a reader tell the two apart at all.
    @Test
    func writesABooleanAsABooleanRatherThanANumber() throws {
        #expect(try encoder.encode(true) == .bool(true))
        #expect(try encoder.encode(1) == .integer(1))
    }

    // One spelling per number: the unsigned case carries only what the signed one cannot.
    @Test
    func writesAnUnsignedValueAsAnIntegerWhileItFits() throws {
        #expect(try encoder.encode(UInt64(7)) == .integer(7))
        #expect(try encoder.encode(UInt64(Int64.max)) == .integer(Int64.max))
        #expect(try encoder.encode(UInt64.max) == .unsignedInteger(UInt64.max))
        #expect(try encoder.encode(Int64.min) == .integer(Int64.min))
    }

    // What `PropertyListEncoder` refuses, and the reason the old write path wrapped every value in a
    // single-element array and unwrapped the result again.
    @Test
    func writesATopLevelFragment() throws {
        #expect(try encoder.encode(Theme.dark) == .string("dark"))
        #expect(try encoder.encode(7) == .integer(7))
    }

    // MARK: - Collections

    @Test
    func writesAStructureAsADictionary() throws {
        let value = try encoder.encode(Profile(name: "Jane Doe", age: 30, tags: ["swift"], nickname: nil))

        #expect(
            value == .dictionary([
                "name": .string("Jane Doe"),
                "age": .integer(30),
                "tags": .array([.string("swift")]),
            ])
        )
    }

    // A synthesized `Encodable` calls `encodeIfPresent`, which leaves the key out rather than
    // writing the sentinel — so an absent value stays absent in what `defaults(1)` prints.
    @Test
    func leavesAnAbsentPropertyOutRatherThanWritingTheSentinel() throws {
        let value = try encoder.encode(Profile(name: "a", age: 1, tags: [], nickname: nil))

        guard case .dictionary(let dictionary) = value else {
            Issue.record("expected a dictionary, got \(value)")
            return
        }

        #expect(dictionary["nickname"] == nil)
    }

    // An array has no way to leave a hole, so the sentinel is what holds the position.
    @Test
    func writesTheSentinelForANilElement() throws {
        let value = try encoder.encode(["a", nil, "b"] as [String?])

        #expect(value == .array([.string("a"), .string("$null"), .string("b")]))
    }

    @Test
    func writesNestedCollections() throws {
        let value = try encoder.encode(["outer": ["inner": [1, 2]]])

        #expect(
            value == .dictionary([
                "outer": .dictionary(["inner": .array([.integer(1), .integer(2)])]),
            ])
        )
    }

    // The contracts `PropertyListFuture` exists for, which nothing a synthesized `Codable` writes
    // ever reaches: a type that asks for a nested container writes into the parent's tree, and
    // asking twice for the same key gets the container it already had rather than a fresh one that
    // discards what was written.
    @Test
    func writesIntoANestedContainerAskedForTwice() throws {
        struct Twice: Encodable {
            enum Outer: String, CodingKey {
                case inner
            }

            enum Inner: String, CodingKey {
                case x, y
            }

            func encode(to encoder: any Encoder) throws {
                var outer = encoder.container(keyedBy: Outer.self)

                var first = outer.nestedContainer(keyedBy: Inner.self, forKey: .inner)
                try first.encode(1, forKey: .x)

                var second = outer.nestedContainer(keyedBy: Inner.self, forKey: .inner)
                try second.encode(2, forKey: .y)
            }
        }

        #expect(
            try encoder.encode(Twice()) == .dictionary([
                "inner": .dictionary(["x": .integer(1), "y": .integer(2)]),
            ])
        )
    }

    @Test
    func writesIntoANestedUnkeyedContainer() throws {
        struct Nested: Encodable {
            enum Outer: String, CodingKey {
                case list
            }

            func encode(to encoder: any Encoder) throws {
                var outer = encoder.container(keyedBy: Outer.self)
                var list = outer.nestedUnkeyedContainer(forKey: .list)
                try list.encode(1)

                var inner = list.nestedUnkeyedContainer()
                try inner.encode(2)

                try list.encode(3)
            }
        }

        #expect(
            try encoder.encode(Nested()) == .dictionary([
                "list": .array([.integer(1), .array([.integer(2)]), .integer(3)]),
            ])
        )
    }

    // `superEncoder()` takes its position when it is made and fills it when it is released, so what
    // the caller encodes in between lands after it rather than in front of it.
    @Test
    func keepsThePositionAnUnkeyedSuperEncoderReserved() throws {
        struct Ordered: Encodable {
            func encode(to encoder: any Encoder) throws {
                var container = encoder.unkeyedContainer()
                try container.encode(0)

                let reserved = container.superEncoder()
                try container.encode(2)

                var single = reserved.singleValueContainer()
                try single.encode(1)
            }
        }

        #expect(try encoder.encode(Ordered()) == .array([.integer(0), .integer(1), .integer(2)]))
    }

    @Test
    func writesAnEmptyCollection() throws {
        #expect(try encoder.encode([Int]()) == .array([]))
        #expect(try encoder.encode([String: Int]()) == .dictionary([:]))
    }

    // MARK: - Round trip

    @Test
    func survivesARoundTripThroughTheDecoder() throws {
        let profile = Profile(name: "Jane Doe", age: 30, tags: ["swift", "macOS"], nickname: "Janie")

        #expect(try decoder.decode(Profile.self, from: encoder.encode(profile)) == profile)
    }

    @Test
    func survivesARoundTripThroughTheAnyForm() throws {
        let profile = Profile(name: "Jane Doe", age: 30, tags: ["swift"], nickname: nil)
        let stored = try encoder.encode(profile).propertyList
        let restored = try #require(PropertyListValue(propertyList: stored))

        #expect(try decoder.decode(Profile.self, from: restored) == profile)
    }

    // What the sentinel is for, checked end to end rather than one side at a time.
    @Test
    func survivesARoundTripWithNilElements() throws {
        let names = ["a", nil, "b"] as [String?]

        #expect(try decoder.decode([String?].self, from: encoder.encode(names)) == names)
    }

    // MARK: - Inheritance

    @Test
    func writesASuperclassThroughItsOwnEncoder() throws {
        class Base: Codable {
            var kind: String

            init(kind: String) {
                self.kind = kind
            }
        }

        final class Derived: Base {
            var extra: Int

            private enum CodingKeys: String, CodingKey {
                case extra
            }

            init(kind: String, extra: Int) {
                self.extra = extra

                super.init(kind: kind)
            }

            required init(from decoder: any Decoder) throws {
                fatalError("unused")
            }

            override func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(extra, forKey: .extra)
                try super.encode(to: container.superEncoder())
            }
        }

        let value = try encoder.encode(Derived(kind: "widget", extra: 9))

        #expect(
            value == .dictionary([
                "extra": .integer(9),
                "super": .dictionary(["kind": .string("widget")]),
            ])
        )
    }

    // MARK: - Errors

    @Test
    func refusesAValueThatEncodesNothingAtTheTop() {
        struct Silent: Encodable {
            func encode(to encoder: any Encoder) throws {}
        }

        #expect(throws: EncodingError.self) {
            try encoder.encode(Silent())
        }
    }

    // The widest number the value model carries is `UInt64`, and nothing narrows silently to reach
    // it: `SingleValueEncodingContainer` has no `Int128` method that this implements, so the
    // standard library's own default refuses with `Encoder has not implemented support for Int128`.
    // Pinned because the alternative — a value quietly losing its top half — is the failure that
    // would not announce itself.
    @Test
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    func refusesAnIntegerWiderThanThePropertyListFormatHas() {
        #expect(throws: EncodingError.self) {
            try encoder.encode(Int128.max)
        }
    }
}
