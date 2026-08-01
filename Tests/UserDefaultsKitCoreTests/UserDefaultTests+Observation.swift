//
//  UserDefaultTests+Observation.swift
//  UserDefaultsKit
//

// `UserDefaults.Observation` is Darwin-only; see the note on the type.
#if canImport(ObjectiveC)
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
    /// Runs `body` against an observation of `key`, keeping it alive until `body` returns.
    ///
    /// In the package a subscription owns its observation. Here nothing would: an `Observation`
    /// holds its handlers, but no handler holds it back, so ARC is free to release it the moment
    /// the last statement naming it has run — and `deinit` unregisters. A test that then wrote and
    /// expected a handler to fire would fail intermittently, and one expecting *no* handler to fire
    /// would pass for the wrong reason.
    private func withObservation(
        key: String,
        _ body: (UserDefaults.Observation) throws -> Void
    ) rethrows {
        let observation = UserDefaults.Observation(key: key, userDefaults: userDefaults)

        try body(observation)

        withExtendedLifetime(observation) {}
    }

    @Test
    func firesHandlersWhenTheValueChanges() {
        withObservation(key: "count") { observation in
            let fired = Mutex(0)
            _ = observation.addHandler { fired.withLock { $0 += 1 } }

            userDefaults.set(42, forKey: "count")

            #expect(fired.withLock { $0 } == 1)
        }
    }

    @Test
    func ignoresChangesToOtherKeys() {
        withObservation(key: "count") { observation in
            let fired = Mutex(false)
            _ = observation.addHandler { fired.withLock { $0 = true } }

            userDefaults.set(42, forKey: "somethingElse")

            #expect(fired.withLock { $0 } == false)
        }
    }

    @Test
    func removingAHandlerStopsItFiring() {
        withObservation(key: "count") { observation in
            let fired = Mutex(0)
            let token = observation.addHandler { fired.withLock { $0 += 1 } }

            observation.removeHandler(token)
            userDefaults.set(42, forKey: "count")

            #expect(observation.handlerCount == 0)
            #expect(fired.withLock { $0 } == 0)
        }
    }

    @Test
    func deliversToEveryAttachedHandler() {
        withObservation(key: "count") { observation in
            let first = Mutex(false)
            let second = Mutex(false)
            _ = observation.addHandler { first.withLock { $0 = true } }
            _ = observation.addHandler { second.withLock { $0 = true } }

            userDefaults.set(42, forKey: "count")

            #expect(observation.handlerCount == 2)
            #expect(first.withLock { $0 } == true)
            #expect(second.withLock { $0 } == true)
        }
    }

    // MARK: - Keys Key-Value Observing cannot take

    // KVO reads a key as a key path, so these never reach `observeValue` and fall back to
    // `UserDefaults.didChangeNotification` — which posts synchronously on the writing thread, the
    // same contract KVO gives. A handler therefore sees this process's own writes either way; what
    // it stops seeing is another process's, which no test here can reach.
    @Test
    func firesHandlersForAKeyContainingADot() {
        withObservation(key: "com.example.count") { observation in
            let fired = Mutex(0)
            _ = observation.addHandler { fired.withLock { $0 += 1 } }

            userDefaults.set(42, forKey: "com.example.count")

            #expect(fired.withLock { $0 } == 1)
        }
    }

    @Test
    func firesHandlersForAKeyContainingACollectionOperator() {
        withObservation(key: "@count") { observation in
            let fired = Mutex(0)
            _ = observation.addHandler { fired.withLock { $0 += 1 } }

            userDefaults.set(42, forKey: "@count")

            #expect(fired.withLock { $0 } == 1)
        }
    }

    // `addObserver(forKeyPath: "")` raises before there is anything to catch it, so constructing
    // this at all is what is being tested.
    @Test
    func doesNotRaiseForAnEmptyKey() {
        withObservation(key: "") { observation in
            _ = observation.addHandler {}

            #expect(observation.handlerCount == 1)
        }
    }

    // The release-mode crash this fallback exists to prevent: with `x.y` registered as a KVO key
    // path, writing `x` raises inside KVO delivery, where Swift cannot catch it. Reaching the
    // expectation is the assertion.
    @Test
    func doesNotRaiseWhenTheLeadingSegmentOfADottedKeyIsWritten() {
        withObservation(key: "x.y") { observation in
            _ = observation.addHandler {}

            userDefaults.set(1, forKey: "x")

            #expect(observation.handlerCount == 1)
        }
    }

    // `UserDefaults(suiteName:)` returns a new instance on every call, so an app-group app that
    // opens its suite in two places writes through one and observes through the other without
    // meaning anything by it. KVO reports that write, and the fallback has to agree — which is why
    // it takes every notification instead of filtering by the posting instance.
    @Test
    func firesForAWriteThroughAnotherInstanceUnderKeyValueObserving() throws {
        let other = try #require(UserDefaults(suiteName: suiteName))

        withObservation(key: "count") { observation in
            let fired = Mutex(0)
            _ = observation.addHandler { fired.withLock { $0 += 1 } }

            other.set(42, forKey: "count")

            #expect(fired.withLock { $0 } == 1)
        }
    }

    @Test
    func firesForAWriteThroughAnotherInstanceOnTheFallback() throws {
        let other = try #require(UserDefaults(suiteName: suiteName))

        withObservation(key: "com.example.count") { observation in
            let fired = Mutex(0)
            _ = observation.addHandler { fired.withLock { $0 += 1 } }

            other.set(42, forKey: "com.example.count")

            #expect(fired.withLock { $0 } == 1)
        }
    }

    // The notification names no key, so without a comparison every write anywhere in the suite
    // would look like a change to this one.
    @Test
    func ignoresChangesToOtherKeysOnTheFallback() {
        withObservation(key: "com.example.count") { observation in
            let fired = Mutex(false)
            _ = observation.addHandler { fired.withLock { $0 = true } }

            userDefaults.set(42, forKey: "somethingElse")

            #expect(fired.withLock { $0 } == false)
        }
    }

    // `UserDefaults` posts for a write that changed nothing, so the comparison is also what keeps a
    // subscriber from being told about a change that did not happen.
    @Test
    func ignoresARewriteOfTheSameValueOnTheFallback() {
        userDefaults.set(42, forKey: "com.example.count")

        withObservation(key: "com.example.count") { observation in
            let fired = Mutex(0)
            _ = observation.addHandler { fired.withLock { $0 += 1 } }

            userDefaults.set(42, forKey: "com.example.count")

            #expect(fired.withLock { $0 } == 0)

            userDefaults.set(43, forKey: "com.example.count")

            #expect(fired.withLock { $0 } == 1)
        }
    }
}
#endif
