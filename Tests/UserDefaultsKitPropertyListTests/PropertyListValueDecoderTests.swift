//
//  PropertyListValueDecoderTests.swift
//  UserDefaultsKitPropertyList
//

import Foundation
import Testing

import UserDefaultsKitPropertyList

@Suite("PropertyListValueDecoder")
struct PropertyListValueDecoderTests {
    private let decoder = PropertyListValueDecoder()

    private struct Profile: Codable, Equatable {
        var name: String
        var age: Int
        var tags: [String]
        var nickname: String?
    }

    private struct Wrapper: Codable, Equatable {
        var profile: Profile
        var updatedAt: Date
        var avatar: Data
    }

    private enum Theme: String, Codable {
        case light
        case dark
    }

    // MARK: - Scalars

    @Test
    func decodesEachScalarFromItsOwnKind() throws {
        #expect(try decoder.decode(Bool.self, from: .bool(true)) == true)
        #expect(try decoder.decode(String.self, from: .string("hello")) == "hello")
        #expect(try decoder.decode(Int.self, from: .integer(42)) == 42)
        #expect(try decoder.decode(UInt64.self, from: .unsignedInteger(.max)) == UInt64.max)
        #expect(try decoder.decode(Double.self, from: .real(3.25)) == 3.25)
        #expect(try decoder.decode(Data.self, from: .data(Data([0x01]))) == Data([0x01]))
        #expect(
            try decoder.decode(Date.self, from: .date(Date(timeIntervalSinceReferenceDate: 5)))
                == Date(timeIntervalSinceReferenceDate: 5)
        )
    }

    // A `String`-backed enum is stored as a bare string, which is the top-level fragment
    // `PropertyListDecoder` refuses to be handed.
    @Test
    func decodesATopLevelFragment() throws {
        #expect(try decoder.decode(Theme.self, from: .string("dark")) == .dark)
    }

    // MARK: - Collections

    @Test
    func decodesAKeyedStructure() throws {
        let value = PropertyListValue.dictionary([
            "name": .string("Jane Doe"),
            "age": .integer(30),
            "tags": .array([.string("swift"), .string("macOS")]),
        ])

        #expect(
            try decoder.decode(Profile.self, from: value)
                == Profile(name: "Jane Doe", age: 30, tags: ["swift", "macOS"], nickname: nil)
        )
    }

    @Test
    func decodesNestedStructuresAndNativeKinds() throws {
        let date = Date(timeIntervalSinceReferenceDate: 1_000)
        let avatar = Data([0xDE, 0xAD])
        let value = PropertyListValue.dictionary([
            "profile": .dictionary([
                "name": .string("Jane Doe"),
                "age": .integer(30),
                "tags": .array([]),
                "nickname": .string("Janie"),
            ]),
            "updatedAt": .date(date),
            "avatar": .data(avatar),
        ])

        let wrapper = try decoder.decode(Wrapper.self, from: value)

        #expect(wrapper.profile.nickname == "Janie")
        #expect(wrapper.updatedAt == date)
        #expect(wrapper.avatar == avatar)
    }

    @Test
    func decodesAnEmptyCollection() throws {
        #expect(try decoder.decode([Int].self, from: .array([])) == [])
        #expect(try decoder.decode([String: Int].self, from: .dictionary([:])) == [:])
    }

    // MARK: - Numeric reading across kinds

    // The point of the whole exercise. `PropertyListDecoder` applies its rules only to what it can
    // reach from the top, and refuses a `<real>` asked for as an integer at all; these are the same
    // coercions the subscript documents, holding at a depth the old two-hop read never applied them.
    @Test
    func readsARealAsAnIntegerInsideACollection() throws {
        #expect(try decoder.decode([Int].self, from: .array([.real(3.7), .real(-3.7)])) == [3, -3])
    }

    @Test
    func readsAnIntegerAsAFloatingPointInsideACollection() throws {
        #expect(try decoder.decode([Double].self, from: .array([.integer(42)])) == [42])
        #expect(try decoder.decode([Float].self, from: .array([.integer(42)])) == [42])
    }

    // `Float(exactly: 1.1)` is nil, which is exactly what `PropertyListDecoder` refuses on.
    @Test
    func readsADoubleAsAFloatWithoutRequiringItToBeExact() throws {
        #expect(try decoder.decode([Float].self, from: .array([.real(1.1)])) == [Float(1.1)])
    }

    @Test
    func readsABooleanFromTheTwoNumbersThatCanMeanOne() throws {
        #expect(try decoder.decode([Bool].self, from: .array([.integer(1), .integer(0)])) == [true, false])
        #expect(try decoder.decode([Bool].self, from: .array([.real(1), .real(0)])) == [true, false])
    }

    @Test
    func refusesABooleanReadFromAnyOtherNumber() {
        #expect(throws: DecodingError.self) {
            try decoder.decode([Bool].self, from: .array([.integer(2)]))
        }
    }

    // A number too large for the type, and a NaN, both have to come back as an error rather than
    // trapping — `UserDefaults` is writable from outside the process, so both are reachable.
    @Test
    func refusesANumberThatDoesNotFit() {
        #expect(throws: DecodingError.self) {
            try decoder.decode([Int].self, from: .array([.real(1e300)]))
        }
        #expect(throws: DecodingError.self) {
            try decoder.decode([Int].self, from: .array([.real(.nan)]))
        }
        #expect(throws: DecodingError.self) {
            try decoder.decode([Int8].self, from: .array([.integer(300)]))
        }
    }

    // The other direction stays strict: a value of an unrelated kind is a mismatch, not a coercion.
    @Test
    func refusesAStringReadAsANumber() {
        #expect(throws: DecodingError.self) {
            try decoder.decode([Int].self, from: .array([.string("42")]))
        }
    }

    @Test
    func refusesANumberReadAsAString() {
        #expect(throws: DecodingError.self) {
            try decoder.decode([String].self, from: .array([.integer(42)]))
        }
    }

    // MARK: - Null

    @Test
    func readsTheNullSentinelAsNilInAnUnkeyedContainer() throws {
        let value = PropertyListValue.array([.string("a"), .string("$null"), .string("b")])

        #expect(try decoder.decode([String?].self, from: value) == ["a", nil, "b"])
    }

    @Test
    func readsTheNullSentinelAsNilUnderAKey() throws {
        let value = PropertyListValue.dictionary([
            "name": .string("Jane Doe"),
            "age": .integer(30),
            "tags": .array([]),
            "nickname": .string("$null"),
        ])

        #expect(try decoder.decode(Profile.self, from: value).nickname == nil)
    }

    @Test
    func refusesTheNullSentinelReadAsAValue() {
        #expect(throws: DecodingError.self) {
            try decoder.decode([String].self, from: .array([.string("$null")]))
        }
    }

    // MARK: - Errors

    @Test
    func reportsAMissingKey() throws {
        let value = PropertyListValue.dictionary(["name": .string("Jane Doe")])
        let error = try #require(throws: DecodingError.self) {
            try decoder.decode(Profile.self, from: value)
        }

        guard case .keyNotFound(let key, _) = error else {
            Issue.record("expected keyNotFound, got \(error)")
            return
        }

        #expect(key.stringValue == "age")
    }

    @Test
    func reportsAMismatchAtTheTop() throws {
        let error = try #require(throws: DecodingError.self) {
            try decoder.decode(Profile.self, from: .string("not a profile"))
        }

        guard case .typeMismatch(_, let context) = error else {
            Issue.record("expected typeMismatch, got \(error)")
            return
        }

        #expect(context.codingPath.isEmpty)
        #expect(context.debugDescription.contains("a string"))
    }

    // What the coding path is for: naming which element of which property refused, rather than just
    // saying the whole value did.
    @Test
    func reportsWhereInsideTheValueTheMismatchWas() throws {
        let value = PropertyListValue.dictionary([
            "name": .string("Jane Doe"),
            "age": .integer(30),
            "tags": .array([.string("swift"), .integer(2)]),
        ])
        let error = try #require(throws: DecodingError.self) {
            try decoder.decode(Profile.self, from: value)
        }

        guard case .typeMismatch(_, let context) = error else {
            Issue.record("expected typeMismatch, got \(error)")
            return
        }

        #expect(context.codingPath.map(\.stringValue) == ["tags", "Index 1"])
        #expect(context.codingPath.last?.intValue == 1)
    }

    @Test
    func reportsRunningOffTheEndOfAnUnkeyedContainer() throws {
        struct Pair: Decodable {
            let first: Int
            let second: Int

            init(from decoder: any Decoder) throws {
                var container = try decoder.unkeyedContainer()
                first = try container.decode(Int.self)
                second = try container.decode(Int.self)
            }
        }

        let error = try #require(throws: DecodingError.self) {
            try decoder.decode(Pair.self, from: .array([.integer(1)]))
        }

        guard case .valueNotFound(_, let context) = error else {
            Issue.record("expected valueNotFound, got \(error)")
            return
        }

        #expect(context.codingPath.map(\.stringValue) == ["Index 1"])
    }

    // MARK: - Container behaviour

    // `decodeNil()` consumes the element only when it says yes, so a caller that gets `false` reads
    // the same element as a value.
    @Test
    func leavesTheIndexAloneWhenAnElementIsNotNull() throws {
        struct Probe: Decodable {
            let wasNil: Bool
            let value: Int

            init(from decoder: any Decoder) throws {
                var container = try decoder.unkeyedContainer()
                wasNil = try container.decodeNil()
                value = try container.decode(Int.self)
            }
        }

        let probe = try decoder.decode(Probe.self, from: .array([.integer(7)]))

        #expect(probe.wasNil == false)
        #expect(probe.value == 7)
    }

    // A `Decodable` is allowed to try an element one way, catch the mismatch, and try it another.
    // Consuming on failure would hand the retry the element after it — or the end — so the index
    // moves only once a read has succeeded.
    @Test
    func leavesTheIndexAloneWhenAnElementFailsToDecode() throws {
        struct Retry: Decodable, Equatable {
            let values: [String]

            init(from decoder: any Decoder) throws {
                var container = try decoder.unkeyedContainer()
                var values = [String]()

                while !container.isAtEnd {
                    if let number = try? container.decode(Int.self) {
                        values.append("int:\(number)")
                    } else {
                        values.append("string:\(try container.decode(String.self))")
                    }
                }

                self.values = values
            }
        }

        let value = PropertyListValue.array([.string("a"), .integer(1), .string("b")])

        #expect(
            try decoder.decode(Retry.self, from: value).values == ["string:a", "int:1", "string:b"]
        )
    }

    // The same rule for a nested container: a failed request must not swallow the element.
    @Test
    func leavesTheIndexAloneWhenANestedContainerIsRefused() throws {
        struct Probe: Decodable {
            let recovered: String

            init(from decoder: any Decoder) throws {
                var container = try decoder.unkeyedContainer()
                _ = try? container.nestedUnkeyedContainer()
                recovered = try container.decode(String.self)
            }
        }

        #expect(try decoder.decode(Probe.self, from: .array([.string("a")])).recovered == "a")
    }

    // An absent `super` stands in as null, not as an empty dictionary. A superclass that asks for a
    // container has to be told the value is missing rather than handed one with every key absent —
    // which is what `PropertyListDecoder` does with the same input.
    @Test
    func refusesASuperclassThatAsksForAContainerThatIsNotThere() {
        class Base: Codable {
            var kind: String?
        }

        final class Derived: Base {
            var extra = 0

            private enum CodingKeys: String, CodingKey {
                case extra
            }

            required init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                extra = try container.decode(Int.self, forKey: .extra)

                try super.init(from: container.superDecoder())
            }
        }

        #expect(throws: DecodingError.self) {
            try decoder.decode(Derived.self, from: .dictionary(["extra": .integer(9)]))
        }
    }

    @Test
    func reportsWhichKeysAKeyedContainerHas() throws {
        struct Keys: Decodable {
            let names: [String]

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: PropertyListCodingKeyStub.self)
                names = container.allKeys.map(\.stringValue).sorted()
            }
        }

        struct PropertyListCodingKeyStub: CodingKey {
            let stringValue: String
            var intValue: Int? { nil }

            init?(stringValue: String) { self.stringValue = stringValue }
            init?(intValue: Int) { nil }
        }

        let value = PropertyListValue.dictionary(["b": .integer(2), "a": .integer(1)])

        #expect(try decoder.decode(Keys.self, from: value).names == ["a", "b"])
    }

    // A class that inherits `Decodable` reads its superclass's half from `super`, and a superclass
    // that stored nothing leaves no key there to read.
    @Test
    func decodesThroughASuperDecoder() throws {
        class Base: Codable {
            var kind: String = ""
        }

        final class Derived: Base {
            var extra: Int = 0

            private enum CodingKeys: String, CodingKey {
                case extra
            }

            required init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                extra = try container.decode(Int.self, forKey: .extra)
                try super.init(from: container.superDecoder())
            }
        }

        let value = PropertyListValue.dictionary([
            "extra": .integer(9),
            "super": .dictionary(["kind": .string("widget")]),
        ])
        let derived = try decoder.decode(Derived.self, from: value)

        #expect(derived.extra == 9)
        #expect(derived.kind == "widget")
    }
}
