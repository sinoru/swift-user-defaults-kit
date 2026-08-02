//
//  UserDefaultTests+Concurrency.swift
//  UserDefaultsKit
//

// `UserDefault.values` is Darwin-only; see the note on `UserDefaults.Observation`.
#if canImport(ObjectiveC)
import Foundation
import Testing
import UserDefaultsKitTestSupport

@testable import UserDefaultsKitCore

@Suite("UserDefault + Concurrency")
final class UserDefaultConcurrencyTests: UserDefaultsTestCase {
    @Test
    func yieldsTheCurrentValueFirst() async throws {
        userDefaults.set(5, forKey: "count")
        let count = UserDefault(key: "count", defaultValue: 0, userDefaults: userDefaults)

        let first = try #require(await count.values.first { _ in true })

        #expect(first == 5)
    }

    @Test
    func yieldsTheDefaultValueWhenTheKeyIsAbsent() async throws {
        let count = UserDefault(key: "count", defaultValue: 7, userDefaults: userDefaults)

        let first = try #require(await count.values.first { _ in true })

        #expect(first == 7)
    }

    @Test
    func yieldsEveryChange() async throws {
        let count = UserDefault(key: "count", defaultValue: 0, userDefaults: userDefaults)

        var received: [Int] = []
        var iterator = count.values.makeAsyncIterator()

        received.append(try #require(await iterator.next()))

        count.wrappedValue = 1
        received.append(try #require(await iterator.next()))

        count.wrappedValue = 2
        received.append(try #require(await iterator.next()))

        #expect(received == [0, 1, 2])
    }

    @Test
    func yieldsChangesMadeThroughFoundation() async throws {
        let count = UserDefault(key: "count", defaultValue: 0, userDefaults: userDefaults)

        var iterator = count.values.makeAsyncIterator()
        _ = await iterator.next()

        userDefaults.set(42, forKey: "count")

        #expect(await iterator.next() == 42)
    }

    @Test
    func yieldsTheDefaultValueWhenTheKeyIsRemoved() async throws {
        userDefaults.set(5, forKey: "count")
        let count = UserDefault(key: "count", defaultValue: 7, userDefaults: userDefaults)

        var iterator = count.values.makeAsyncIterator()
        #expect(await iterator.next() == 5)

        userDefaults.removeObject(forKey: "count")

        #expect(await iterator.next() == 7)
    }

    @Test
    func yieldsValuesOutsideThePropertyListTypes() async throws {
        let profile = UserDefault(
            key: "profile",
            defaultValue: Profile(name: "", age: 0, tags: []),
            userDefaults: userDefaults
        )
        let jane = Profile(name: "Jane Doe", age: 30, tags: ["swift"])

        var iterator = profile.values.makeAsyncIterator()
        _ = await iterator.next()

        profile.wrappedValue = jane

        #expect(await iterator.next() == jane)
    }

    // Each `values` stream owns its observation and unregisters it when torn down, so churning through
    // many streams leaves nothing registered behind and a fresh one still works.
    @Test
    func tearingDownAStreamDoesNotLeakOntoTheNextOne() async throws {
        let count = UserDefault(key: "count", defaultValue: 0, userDefaults: userDefaults)

        for _ in 0..<50 {
            var iterator = count.values.makeAsyncIterator()
            _ = await iterator.next()
            // The iterator drops here, deinitializing the stream's observation and removing its observer.
        }

        var iterator = count.values.makeAsyncIterator()
        #expect(await iterator.next() == 0)

        userDefaults.set(7, forKey: "count")

        #expect(await iterator.next() == 7)
    }
}
#endif
