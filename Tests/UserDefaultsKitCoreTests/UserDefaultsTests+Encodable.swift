//
//  UserDefaultsTests+Encodable.swift
//  UserDefaultsKit
//
//  Created by Kang Jaehong on 7/12/26.
//

import Foundation
import Testing
import UserDefaultsKitTestSupport

@testable import UserDefaultsKitCore

/// What the kit's subscript *writes*, verified with Foundation's own readers rather than by reading
/// it back through the same subscript. Checking the kit against itself would pass even if it
/// invented a private storage format that nothing else can read.
@Suite("UserDefaults + Encodable")
final class UserDefaultsEncodableTests: UserDefaultsTestCase {
    @Test
    func writesPropertyListNativeValuesFoundationCanRead() throws {
        userDefaults["bool"] = true
        userDefaults["int"] = 42
        userDefaults["float"] = Float(1.5)
        userDefaults["double"] = 3.25
        userDefaults["string"] = "hello"
        userDefaults["data"] = Data([0x01, 0x02])
        userDefaults["stringArray"] = ["a", "b"]

        #expect(userDefaults.bool(forKey: "bool") == true)
        #expect(userDefaults.integer(forKey: "int") == 42)
        #expect(userDefaults.float(forKey: "float") == 1.5)
        #expect(userDefaults.double(forKey: "double") == 3.25)
        #expect(userDefaults.string(forKey: "string") == "hello")
        #expect(userDefaults.data(forKey: "data") == Data([0x01, 0x02]))
        #expect(userDefaults.stringArray(forKey: "stringArray") == ["a", "b"])
    }

    @Test
    func doesNotArchivePropertyListNativeValues() throws {
        userDefaults["int"] = 42
        userDefaults["string"] = "hello"

        // Archiving these would make the defaults opaque to `defaults(1)`, `@AppStorage`, and every
        // other process that reads the same domain.
        #expect(!(try #require(userDefaults.object(forKey: "int")) is Data))
        #expect(!(try #require(userDefaults.object(forKey: "string")) is Data))
    }

    // The payoff of encoding into a property list instead of archiving: the struct lands as a
    // dictionary and the `String`-backed enum as a string, so `defaults(1)` and every other reader
    // of the domain sees the value rather than an opaque blob. An archive would satisfy the round
    // trip just as well and fail every expectation below.
    @Test
    func encodesValuesOutsideThePropertyListTypesAsPropertyLists() throws {
        userDefaults["profile"] = Profile(name: "Jane Doe", age: 30, tags: ["swift"])
        userDefaults["theme"] = Theme.dark

        #expect(!(try #require(userDefaults.object(forKey: "profile")) is Data))
        #expect(!(try #require(userDefaults.object(forKey: "theme")) is Data))

        #expect(userDefaults.string(forKey: "theme") == "dark")
        #expect(userDefaults.dictionary(forKey: "profile")?["name"] as? String == "Jane Doe")
        #expect(userDefaults.dictionary(forKey: "profile")?["age"] as? Int == 30)
    }

    // swift-corelibs-foundation's `set(_ url:forKey:)` stores only `url.path`, so there is nothing
    // left for its `url(forKey:)` to read back; see the note on the subscript.
    #if canImport(ObjectiveC)
    @Test
    func writesURLFoundationCanRead() throws {
        let url = try #require(URL(string: "https://swift.org/blog"))

        userDefaults["url"] = url

        #expect(userDefaults.url(forKey: "url") == url)
    }

    // The exception the subscript's note names, pinned rather than left to be discovered. A
    // top-level `URL` is handed to `set(_:forKey:)` rather than encoded, and what that stores for a
    // non-file URL is a keyed archive — the one opaque thing a key written through the subscript can
    // hold, and the price of `url(forKey:)` and `@AppStorage` being able to read it at all. A file
    // URL is stored as its path and stays legible.
    @Test
    func storesATopLevelNonFileURLAsAnArchive() throws {
        let web = try #require(URL(string: "https://swift.org/blog"))

        userDefaults["web"] = web
        userDefaults["file"] = URL(fileURLWithPath: "/tmp/settings.json")

        #expect(try #require(userDefaults.object(forKey: "web")) is Data)
        #expect(userDefaults.string(forKey: "file") == "/tmp/settings.json")
    }
    #endif

    // And the other half of the same note: a `URL` inside a value is encoded like anything else, so
    // it lands as a dictionary on both platforms and keeps the parts `set(_:forKey:)` drops. The two
    // shapes do not read each other, which is why this is worth stating rather than assuming.
    @Test
    func encodesAURLInsideAValueAsADictionary() throws {
        let web = try #require(URL(string: "https://swift.org/blog"))

        userDefaults["pages"] = [web]

        #expect(!(try #require(userDefaults.object(forKey: "pages")) is Data))
        #expect(userDefaults["pages", type: [URL].self] == [web])
    }

    @Test
    func removesTheKeyWhenTheValueIsNil() throws {
        userDefaults["int"] = 42
        #expect(userDefaults.object(forKey: "int") != nil)

        userDefaults["int"] = Int?.none

        #expect(userDefaults.object(forKey: "int") == nil)
    }
}
