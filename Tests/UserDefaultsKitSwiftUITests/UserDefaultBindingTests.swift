//
//  UserDefaultBindingTests.swift
//  UserDefaultsKitSwiftUI
//

#if canImport(SwiftUI)
import Combine
import Foundation
import SwiftUI
import Testing
import UserDefaultsKitTestSupport

@testable import UserDefaultsKitCore
@testable import UserDefaultsKitSwiftUI

@Suite("UserDefault + Binding")
final class UserDefaultBindingTests {
    let suiteName: String
    let userDefaults: UserDefaults

    init() throws {
        let suiteName = "UserDefaultsKitSwiftUITests.\(UUID().uuidString)"
        self.suiteName = suiteName
        self.userDefaults = try #require(UserDefaults(suiteName: suiteName))
    }

    deinit {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    @Test
    func readsTheDefaultValueWhenTheKeyIsAbsent() {
        let name = UserDefault(key: "name", defaultValue: "anonymous", userDefaults: userDefaults)

        #expect(name.binding.wrappedValue == "anonymous")
    }

    @Test
    func readsThroughToUserDefaults() {
        let name = UserDefault(key: "name", defaultValue: "anonymous", userDefaults: userDefaults)

        userDefaults.set("Jane Doe", forKey: "name")

        #expect(name.binding.wrappedValue == "Jane Doe")
    }

    @Test
    func writesThroughToUserDefaults() {
        let name = UserDefault(key: "name", defaultValue: "anonymous", userDefaults: userDefaults)

        name.binding.wrappedValue = "Jane Doe"

        #expect(userDefaults.string(forKey: "name") == "Jane Doe")
    }

    @Test
    func bindsValuesOutsideThePropertyListTypes() {
        let theme = UserDefault(key: "theme", defaultValue: Theme.light, userDefaults: userDefaults)

        theme.binding.wrappedValue = .dark

        #expect(theme.wrappedValue == .dark)
    }

    // The @StateObject-backed observation is only installed inside a live view, so this covers the
    // value/binding round trip; the change-driven refresh is exercised through the coordinator below.
    @Test
    func userDefaultStorageReadsAndWritesThroughToUserDefaults() {
        let name = UserDefaultStorage(wrappedValue: "anonymous", "name", store: userDefaults)

        #expect(name.wrappedValue == "anonymous")

        name.wrappedValue = "Jane Doe"

        #expect(userDefaults.string(forKey: "name") == "Jane Doe")
        #expect(name.projectedValue.wrappedValue == "Jane Doe")
    }

    // `@StateObject` builds its object once per view identity and discards every later one, so the
    // coordinator has to be re-pointed rather than rebuilt when a view keeps its identity while its
    // key changes — a row in a `ForEach`, say. Left unfixed the failure is invisible from the
    // outside: writes go to the new key and only the refresh goes missing.
    @Test
    func theCoordinatorFollowsAChangedKey() {
        let coordinator = Coordinator<String>()

        coordinator.observe(UserDefault(key: "first", defaultValue: "", userDefaults: userDefaults))

        #expect(coordinator.observed?.key == "first")

        coordinator.observe(UserDefault(key: "second", defaultValue: "", userDefaults: userDefaults))

        #expect(coordinator.observed?.key == "second")
    }

    // The coordinator hears of a change from the observation rather than from a value arriving, so
    // nothing but this says that a write still reaches the view.
    @Test
    func theCoordinatorInvalidatesWhenTheValueChanges() async {
        let coordinator = Coordinator<String>()
        let (changes, continuation) = AsyncStream.makeStream(of: Void.self)
        let cancellable = coordinator.objectWillChange.sink { continuation.yield() }
        defer { cancellable.cancel() }

        coordinator.observe(UserDefault(key: "name", defaultValue: "", userDefaults: userDefaults))
        userDefaults.set("Jane Doe", forKey: "name")

        // The invalidation hops to the main queue, so it is waited for — and given up on rather
        // than waited for indefinitely, which is all a missing one would otherwise look like.
        let timeout = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            continuation.finish()
        }
        defer { timeout.cancel() }

        var iterator = changes.makeAsyncIterator()

        #expect(await iterator.next() != nil)
    }

    @Test
    func theCoordinatorFollowsAChangedStore() throws {
        let otherSuiteName = "\(suiteName).other"
        let other = try #require(UserDefaults(suiteName: otherSuiteName))
        defer { other.removePersistentDomain(forName: otherSuiteName) }

        let coordinator = Coordinator<String>()

        coordinator.observe(UserDefault(key: "name", defaultValue: "", userDefaults: userDefaults))

        #expect(coordinator.observed?.store === userDefaults)

        coordinator.observe(UserDefault(key: "name", defaultValue: "", userDefaults: other))

        #expect(coordinator.observed?.store === other)
    }
}
#endif
