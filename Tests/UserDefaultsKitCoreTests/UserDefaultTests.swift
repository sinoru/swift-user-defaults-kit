//
//  UserDefaultTests.swift
//  UserDefaultsKit
//
//  Created by Kang Jaehong on 7/12/26.
//

import Foundation
import Testing
import UserDefaultsKitTestSupport

@testable import UserDefaultsKitCore

@Suite("UserDefault")
final class UserDefaultTests: UserDefaultsTestCase {
    @Test
    func returnsTheDefaultValueWhenTheKeyIsAbsent() {
        let count = UserDefault(key: "count", defaultValue: 7, userDefaults: userDefaults)

        #expect(count.wrappedValue == 7)
    }

    @Test
    func writesThroughToUserDefaults() {
        let count = UserDefault(key: "count", defaultValue: 0, userDefaults: userDefaults)

        count.wrappedValue = 42

        #expect(userDefaults.integer(forKey: "count") == 42)
    }

    @Test
    func readsValuesWrittenDirectlyToUserDefaults() {
        let count = UserDefault(key: "count", defaultValue: 0, userDefaults: userDefaults)

        userDefaults.set(42, forKey: "count")

        #expect(count.wrappedValue == 42)
    }

    @Test
    func storesValuesOutsideThePropertyListTypes() {
        let jaehong = Profile(name: "Jaehong", age: 30, tags: ["swift"])
        let profile = UserDefault(
            key: "profile",
            defaultValue: Profile(name: "", age: 0, tags: []),
            userDefaults: userDefaults
        )

        profile.wrappedValue = jaehong

        #expect(profile.wrappedValue == jaehong)
    }

    @Test
    func projectedValueIsTheWrapperItself() {
        let count = UserDefault(key: "count", defaultValue: 7, userDefaults: userDefaults)

        let projection = count.projectedValue

        #expect(projection.key == count.key)
        #expect(projection.defaultValue == count.defaultValue)
        #expect(projection.userDefaults === count.userDefaults)
    }

    @Test
    func worksAsAPropertyWrapper() {
        @UserDefault(key: "count", defaultValue: 0, userDefaults: userDefaults)
        var count: Int

        #expect(count == 0)

        count = 42

        #expect(userDefaults.integer(forKey: "count") == 42)
        #expect($count.key == "count")
    }

    // The spelling a property wrapper is normally declared with. Without `init(wrappedValue:_:store:)`
    // this does not compile at all, and a caller has to name the type and pass `defaultValue:`.
    @Test
    func takesItsDefaultFromTheDeclaration() {
        @UserDefault("count", store: userDefaults)
        var count = 7

        #expect(count == 7)

        count = 42

        #expect(userDefaults.integer(forKey: "count") == 42)
        #expect($count.defaultValue == 7)
    }

    // MARK: - Optional Value

    @Test
    func returnsANonNilDefaultValueForAnAbsentOptionalKey() {
        let name = UserDefault(key: "name", defaultValue: String?("anonymous"), userDefaults: userDefaults)

        #expect(name.wrappedValue == "anonymous")
    }

    @Test
    func returnsANilDefaultValueForAnAbsentOptionalKey() {
        let name = UserDefault(key: "name", defaultValue: String?.none, userDefaults: userDefaults)

        #expect(name.wrappedValue == nil)
    }

    @Test
    func roundTripsAnOptionalValue() {
        let name = UserDefault(key: "name", defaultValue: String?.none, userDefaults: userDefaults)

        name.wrappedValue = "Jaehong"

        #expect(name.wrappedValue == "Jaehong")
        #expect(userDefaults.string(forKey: "name") == "Jaehong")
    }

    @Test
    func assigningNilRemovesTheKeyAndFallsBackToTheDefaultValue() {
        let name = UserDefault(key: "name", defaultValue: String?("anonymous"), userDefaults: userDefaults)
        name.wrappedValue = "Jaehong"

        name.wrappedValue = nil

        #expect(userDefaults.object(forKey: "name") == nil)
        #expect(name.wrappedValue == "anonymous")
    }
}
