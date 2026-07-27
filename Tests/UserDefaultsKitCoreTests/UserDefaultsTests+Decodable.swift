//
//  UserDefaultsTests+Decodable.swift
//  UserDefaultsKit
//
//  Created by Kang Jaehong on 7/12/26.
//

import Foundation
import Testing
import UserDefaultsKitTestSupport

@testable import UserDefaultsKitCore

/// What the kit's subscript *reads*, set up with Foundation's own writers wherever Foundation has a
/// native representation. A value the kit both wrote and read back proves nothing about whether the
/// two agree with the rest of the system.
///
/// The archived types are the exception: `Profile` and `Theme` have no property-list form, so the
/// kit's own subscript is the only way to store them and the round trip is the contract.
@Suite("UserDefaults + Decodable")
final class UserDefaultsDecodableTests: UserDefaultsTestCase {
    @Test
    func readsPropertyListNativeValuesWrittenByFoundation() {
        userDefaults.set(true, forKey: "bool")
        userDefaults.set(42, forKey: "int")
        userDefaults.set(Float(1.5), forKey: "float")
        userDefaults.set(3.25, forKey: "double")
        userDefaults.set("hello", forKey: "string")
        userDefaults.set(Data([0x01, 0x02]), forKey: "data")
        userDefaults.set(["a", "b"], forKey: "stringArray")

        #expect(userDefaults["bool", type: Bool.self] == true)
        #expect(userDefaults["int", type: Int.self] == 42)
        #expect(userDefaults["float", type: Float.self] == 1.5)
        #expect(userDefaults["double", type: Double.self] == 3.25)
        #expect(userDefaults["string", type: String.self] == "hello")
        #expect(userDefaults["data", type: Data.self] == Data([0x01, 0x02]))
        #expect(userDefaults["stringArray", type: [String].self] == ["a", "b"])
    }

    @Test
    func readsURLWrittenByFoundation() throws {
        let url = try #require(URL(string: "https://swift.org/blog"))

        userDefaults.set(url, forKey: "url")

        #expect(userDefaults["url", type: URL.self] == url)
    }

    @Test
    func readsURLWrittenByTheKit() throws {
        let url = try #require(URL(string: "https://swift.org/blog"))

        userDefaults["url"] = url

        #expect(userDefaults["url", type: URL.self] == url)
    }

    @Test
    func readsArchivedValuesWrittenByTheKit() throws {
        let profile = Profile(name: "Jaehong", age: 30, tags: ["swift", "macOS"])

        userDefaults["profile"] = profile
        userDefaults["theme"] = Theme.dark

        #expect(userDefaults["profile", type: Profile.self] == profile)
        #expect(userDefaults["theme", type: Theme.self] == .dark)
    }

    @Test
    func returnsNilWhenTheKeyIsAbsent() {
        #expect(userDefaults["absent", type: Int.self] == nil)
    }

    @Test
    func fallsBackToTheDefaultValueWhenTheKeyIsAbsent() {
        #expect(userDefaults["absent", default: 7] == 7)
    }

    @Test
    func returnsNilWhenTheStoredValueIsOfAnotherType() {
        userDefaults.set("not a profile", forKey: "profile")

        #expect(userDefaults["profile", type: Profile.self] == nil)
    }

    // MARK: - Numeric storage

    // A property list keeps no `Float`/`Double` distinction — both land as `<real>`. Demanding an
    // exact `Float` back would reject `1.1`, which has no binary32 form, and quietly substitute the
    // default for anything another writer stored as a `Double`.
    @Test
    func readsAFloatWrittenAsADouble() {
        userDefaults.set(1.1, forKey: "double")

        #expect(userDefaults["double", type: Float.self] == Float(1.1))
    }

    @Test
    func readsADoubleWrittenAsAnInt() {
        userDefaults.set(42, forKey: "int")

        #expect(userDefaults["int", type: Double.self] == 42)
    }

    // The same reasoning in the other direction. `<real>` is what `defaults(1)` writes for any
    // fractional literal, so rejecting it when an `Int` is asked for would drop a value another
    // writer meant as a number. Truncating toward zero is what `integer(forKey:)` does with the
    // same storage.
    @Test
    func readsAnIntWrittenAsADouble() {
        userDefaults.set(3.5, forKey: "double")

        #expect(userDefaults["double", type: Int.self] == 3)
    }

    // `Int(_:)` traps on a magnitude it cannot hold, and `UserDefaults` is writable from outside
    // the process — `defaults write <domain> huge 1e300` is enough to reach this. It has to read
    // back as missing rather than take the process down.
    @Test
    func fallsBackToTheDefaultValueWhenANumberIsTooLargeForAnInt() {
        userDefaults.set(1e300, forKey: "huge")

        #expect(userDefaults["huge", type: Int.self] == nil)
        #expect(userDefaults["huge", default: 7] == 7)

        // The optional spelling is the one that breaks if the failed conversion is cast rather than
        // unwrapped: `Int?.none as? Int?` succeeds and produces a result that is present and nil,
        // which the `??` reads as a value and the caller's default never replaces.
        #expect(userDefaults["huge", default: Int?(7)] == 7)
    }

    // `Bool` is deliberately narrower than `bool(forKey:)`, which reports any non-zero number as
    // `true`. A property list means one of two things by a boolean, and a number that is neither
    // is a mismatch — which this reads as missing rather than flattening.
    @Test
    func readsABoolWrittenAsZeroOrOne() {
        userDefaults.set(1, forKey: "one")
        userDefaults.set(0, forKey: "zero")

        #expect(userDefaults["one", type: Bool.self] == true)
        #expect(userDefaults["zero", type: Bool.self] == false)
    }

    @Test
    func returnsNilWhenABoolIsStoredAsAnotherNumber() {
        userDefaults.set(2, forKey: "two")

        #expect(userDefaults["two", type: Bool.self] == nil)
    }

    // Reading across kinds is where the default has to win: unlike `integer(forKey:)`, which
    // flattens a mismatch into `0`, a non-numeric value has to read back as missing.
    @Test
    func fallsBackToTheDefaultValueWhenTheStoredValueIsNotANumber() {
        userDefaults.set("not a number", forKey: "int")
        userDefaults.set("not a number", forKey: "float")

        #expect(userDefaults["int", default: 7] == 7)
        #expect(userDefaults["float", default: Float(2.5)] == 2.5)
    }

    // MARK: - Optional value types

    // An absent key has to read back as a *missing* value, not as a present-but-nil one. If
    // `subscript(_:type:)` hands back `.some(.none)`, the `??` in `subscript(_:type:default:)`
    // never fires and the caller's default is silently discarded — which only shows up when the
    // default is non-nil, so a `defaultValue: nil` test would not catch it.
    @Test
    func fallsBackToTheDefaultValueForAnAbsentOptionalString() {
        #expect(userDefaults["absent", default: String?("fallback")] == "fallback")
    }

    @Test
    func fallsBackToTheDefaultValueForAnAbsentOptionalInt() {
        #expect(userDefaults["absent", default: Int?(7)] == 7)
    }

    @Test
    func fallsBackToTheDefaultValueForAnAbsentOptionalURL() throws {
        let fallback = try #require(URL(string: "https://swift.org"))

        #expect(userDefaults["absent", default: URL?(fallback)] == fallback)
    }

    @Test
    func fallsBackToTheDefaultValueForAnAbsentOptionalProfile() {
        let fallback = Profile(name: "fallback", age: 0, tags: [])

        #expect(userDefaults["absent", default: Profile?(fallback)] == fallback)
    }

    @Test
    func readsOptionalValuesThatArePresent() throws {
        let url = try #require(URL(string: "https://swift.org/blog"))
        userDefaults.set("hello", forKey: "string")
        userDefaults.set(42, forKey: "int")
        userDefaults.set(url, forKey: "url")

        #expect(userDefaults["string", type: String?.self] == "hello")
        #expect(userDefaults["int", type: Int?.self] == 42)
        #expect(userDefaults["url", type: URL?.self] == url)
    }
}
