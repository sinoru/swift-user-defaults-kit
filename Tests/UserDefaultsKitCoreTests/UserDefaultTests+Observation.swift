//
//  UserDefaultTests+Observation.swift
//  UserDefaultsKit
//

import Foundation
import SynchronizationKit
import Testing
import UserDefaultsKitTestSupport

@testable import UserDefaultsKitCore

/// `UserDefaults.Observation` is the one place the package talks to KVO, and to the notification it
/// falls back to. These exercise it directly — the change surfaces (`publisher`, `values`, SwiftUI)
/// each own one and lean on this behavior.
@Suite("UserDefaults.Observation")
final class UserDefaultsObservationTests: UserDefaultsTestCase {
    @Test
    func firesHandlersWhenTheValueChanges() {
        let observation = UserDefaults.Observation(key: "count", userDefaults: userDefaults)
        let fired = Mutex(0)
        _ = observation.addHandler { fired.withLock { $0 += 1 } }

        userDefaults.set(42, forKey: "count")

        #expect(fired.withLock { $0 } == 1)
    }

    @Test
    func ignoresChangesToOtherKeys() {
        let observation = UserDefaults.Observation(key: "count", userDefaults: userDefaults)
        let fired = Mutex(false)
        _ = observation.addHandler { fired.withLock { $0 = true } }

        userDefaults.set(42, forKey: "somethingElse")

        #expect(fired.withLock { $0 } == false)
    }

    @Test
    func removingAHandlerStopsItFiring() {
        let observation = UserDefaults.Observation(key: "count", userDefaults: userDefaults)
        let fired = Mutex(0)
        let token = observation.addHandler { fired.withLock { $0 += 1 } }

        observation.removeHandler(token)
        userDefaults.set(42, forKey: "count")

        #expect(observation.handlerCount == 0)
        #expect(fired.withLock { $0 } == 0)
    }

    @Test
    func deliversToEveryAttachedHandler() {
        let observation = UserDefaults.Observation(key: "count", userDefaults: userDefaults)
        let first = Mutex(false)
        let second = Mutex(false)
        _ = observation.addHandler { first.withLock { $0 = true } }
        _ = observation.addHandler { second.withLock { $0 = true } }

        userDefaults.set(42, forKey: "count")

        #expect(observation.handlerCount == 2)
        #expect(first.withLock { $0 } == true)
        #expect(second.withLock { $0 } == true)
    }

    // MARK: - Keys Key-Value Observing cannot take

    // KVO reads a key as a key path, so these never reach `observeValue` and fall back to
    // `UserDefaults.didChangeNotification` — which posts synchronously on the writing thread, the
    // same contract KVO gives. A handler therefore sees this process's own writes either way; what
    // it stops seeing is another process's, which no test here can reach.
    @Test
    func firesHandlersForAKeyContainingADot() {
        let observation = UserDefaults.Observation(key: "com.example.count", userDefaults: userDefaults)
        let fired = Mutex(0)
        _ = observation.addHandler { fired.withLock { $0 += 1 } }

        userDefaults.set(42, forKey: "com.example.count")

        #expect(fired.withLock { $0 } == 1)
    }

    @Test
    func firesHandlersForAKeyContainingACollectionOperator() {
        let observation = UserDefaults.Observation(key: "@count", userDefaults: userDefaults)
        let fired = Mutex(0)
        _ = observation.addHandler { fired.withLock { $0 += 1 } }

        userDefaults.set(42, forKey: "@count")

        #expect(fired.withLock { $0 } == 1)
    }

    // `addObserver(forKeyPath: "")` raises before there is anything to catch it, so constructing
    // this at all is what is being tested.
    @Test
    func doesNotRaiseForAnEmptyKey() {
        let observation = UserDefaults.Observation(key: "", userDefaults: userDefaults)
        _ = observation.addHandler {}

        #expect(observation.handlerCount == 1)
    }

    // The release-mode crash this fallback exists to prevent: with `x.y` registered as a KVO key
    // path, writing `x` raises inside KVO delivery, where Swift cannot catch it. Reaching the
    // expectation is the assertion.
    @Test
    func doesNotRaiseWhenTheLeadingSegmentOfADottedKeyIsWritten() {
        let observation = UserDefaults.Observation(key: "x.y", userDefaults: userDefaults)
        _ = observation.addHandler {}

        userDefaults.set(1, forKey: "x")

        #expect(observation.handlerCount == 1)
    }

    // `UserDefaults(suiteName:)` returns a new instance on every call, so an app-group app that
    // opens its suite in two places writes through one and observes through the other without
    // meaning anything by it. KVO reports that write, and the fallback has to agree — which is why
    // it takes every notification instead of filtering by the posting instance.
    @Test
    func firesForAWriteThroughAnotherInstanceUnderKeyValueObserving() throws {
        let other = try #require(UserDefaults(suiteName: suiteName))

        let observation = UserDefaults.Observation(key: "count", userDefaults: userDefaults)
        let fired = Mutex(0)
        _ = observation.addHandler { fired.withLock { $0 += 1 } }

        other.set(42, forKey: "count")

        #expect(fired.withLock { $0 } == 1)
    }

    @Test
    func firesForAWriteThroughAnotherInstanceOnTheFallback() throws {
        let other = try #require(UserDefaults(suiteName: suiteName))

        let observation = UserDefaults.Observation(key: "com.example.count", userDefaults: userDefaults)
        let fired = Mutex(0)
        _ = observation.addHandler { fired.withLock { $0 += 1 } }

        other.set(42, forKey: "com.example.count")

        #expect(fired.withLock { $0 } == 1)
    }

    // The notification names no key, so without a comparison every write anywhere in the suite
    // would look like a change to this one.
    @Test
    func ignoresChangesToOtherKeysOnTheFallback() {
        let observation = UserDefaults.Observation(key: "com.example.count", userDefaults: userDefaults)
        let fired = Mutex(false)
        _ = observation.addHandler { fired.withLock { $0 = true } }

        userDefaults.set(42, forKey: "somethingElse")

        #expect(fired.withLock { $0 } == false)
    }

    // `UserDefaults` posts for a write that changed nothing, so the comparison is also what keeps a
    // subscriber from being told about a change that did not happen.
    @Test
    func ignoresARewriteOfTheSameValueOnTheFallback() {
        userDefaults.set(42, forKey: "com.example.count")

        let observation = UserDefaults.Observation(key: "com.example.count", userDefaults: userDefaults)
        let fired = Mutex(0)
        _ = observation.addHandler { fired.withLock { $0 += 1 } }

        userDefaults.set(42, forKey: "com.example.count")

        #expect(fired.withLock { $0 } == 0)

        userDefaults.set(43, forKey: "com.example.count")

        #expect(fired.withLock { $0 } == 1)
    }
}
