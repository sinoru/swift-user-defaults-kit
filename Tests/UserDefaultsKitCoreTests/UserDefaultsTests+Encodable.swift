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

    @Test
    func archivesValuesOutsideThePropertyListTypes() throws {
        userDefaults["profile"] = Profile(name: "Jaehong", age: 30, tags: ["swift"])
        userDefaults["theme"] = Theme.dark

        #expect(try #require(userDefaults.object(forKey: "profile")) is Data)
        #expect(try #require(userDefaults.object(forKey: "theme")) is Data)
    }

    @Test
    func writesURLFoundationCanRead() throws {
        let url = try #require(URL(string: "https://swift.org/blog"))

        userDefaults["url"] = url

        #expect(userDefaults.url(forKey: "url") == url)
    }

    @Test
    func removesTheKeyWhenTheValueIsNil() throws {
        userDefaults["int"] = 42
        #expect(userDefaults.object(forKey: "int") != nil)

        userDefaults["int"] = Int?.none

        #expect(userDefaults.object(forKey: "int") == nil)
    }
}
