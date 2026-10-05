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
    /// holds its handler, but no handler holds it back, so ARC is free to release it the moment
    /// the last statement naming it has run — and `deinit` unregisters. A test that then wrote and
    /// expected a handler to fire would fail intermittently, and one expecting *no* handler to fire
    /// would pass for the wrong reason.
    private func withObservation(
        key: String,
        handler: @escaping @Sendable () -> Void,
        _ body: (UserDefaults.Observation) async throws -> Void
    ) async rethrows {
        let observation = UserDefaults.Observation(key: key, userDefaults: userDefaults, handler: handler)

        try await body(observation)

        withExtendedLifetime(observation) {}
    }

    /// Gives a handler up to a second to catch up with a write made on the fallback.
    ///
    /// The notification is posted on the writing thread, but it reaches every observation in the
    /// process, and so does every other test's. Another thread's post can re-read the key first,
    /// claim the change, and call the handler just after the write returns — once, but not before
    /// the expectation that follows it.
    private func waitForHandlers(until condition: () -> Bool) async {
        for _ in 0..<1_000 where !condition() {
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
    }

    @Test
    func firesHandlersWhenTheValueChanges() async {
        let fired = Mutex(0)

        await withObservation(
            key: "count",
            handler: { fired.withLock { $0 += 1 } }
        ) { observation in
            userDefaults.set(42, forKey: "count")

            #expect(fired.withLock { $0 } == 1)
        }
    }

    @Test
    func ignoresChangesToOtherKeys() async {
        let fired = Mutex(false)

        await withObservation(
            key: "count",
            handler: { fired.withLock { $0 = true } }
        ) { observation in
            userDefaults.set(42, forKey: "somethingElse")

            #expect(fired.withLock { $0 } == false)
        }
    }

    @Test
    func removingAHandlerStopsItFiring() async {
        let fired = Mutex(0)

        await withObservation(
            key: "count",
            handler: { fired.withLock { $0 += 1 } }
        ) { observation in
            observation.removeHandler()
            userDefaults.set(42, forKey: "count")

            #expect(observation.hasHandler == false)
            #expect(fired.withLock { $0 } == 0)
        }
    }

    // MARK: - Keys Key-Value Observing cannot take

    // KVO reads a key as a key path, so these never reach `observeValue` and fall back to
    // `UserDefaults.didChangeNotification`. A handler still sees each of this process's own writes
    // exactly once; what it stops seeing is another process's, which no test here can reach. What
    // it also loses is KVO's timing — see `waitForHandlers(until:)` — so these wait before they
    // count.
    @Test
    func firesHandlersForAKeyContainingADot() async {
        let fired = Mutex(0)

        await withObservation(
            key: "com.example.count",
            handler: { fired.withLock { $0 += 1 } }
        ) { observation in
            userDefaults.set(42, forKey: "com.example.count")
            await waitForHandlers { fired.withLock { $0 } > 0 }

            #expect(fired.withLock { $0 } == 1)
        }
    }

    @Test
    func firesHandlersForAKeyContainingACollectionOperator() async {
        let fired = Mutex(0)

        await withObservation(
            key: "@count",
            handler: { fired.withLock { $0 += 1 } }
        ) { observation in
            userDefaults.set(42, forKey: "@count")
            await waitForHandlers { fired.withLock { $0 } > 0 }

            #expect(fired.withLock { $0 } == 1)
        }
    }

    // `addObserver(forKeyPath: "")` raises before there is anything to catch it, so constructing
    // this at all is what is being tested.
    @Test
    func doesNotRaiseForAnEmptyKey() async {
        await withObservation(key: "", handler: {}) { observation in
            #expect(observation.hasHandler)
        }
    }

    // The release-mode crash this fallback exists to prevent: with `x.y` registered as a KVO key
    // path, writing `x` raises inside KVO delivery, where Swift cannot catch it. Reaching the
    // expectation is the assertion.
    @Test
    func doesNotRaiseWhenTheLeadingSegmentOfADottedKeyIsWritten() async {
        await withObservation(key: "x.y", handler: {}) { observation in
            userDefaults.set(1, forKey: "x")

            #expect(observation.hasHandler)
        }
    }

    // `UserDefaults(suiteName:)` returns a new instance on every call, so an app-group app that
    // opens its suite in two places writes through one and observes through the other without
    // meaning anything by it. KVO reports that write, and the fallback has to agree — which is why
    // it takes every notification instead of filtering by the posting instance.
    @Test
    func firesForAWriteThroughAnotherInstanceUnderKeyValueObserving() async throws {
        let other = try #require(UserDefaults(suiteName: suiteName))

        let fired = Mutex(0)

        await withObservation(
            key: "count",
            handler: { fired.withLock { $0 += 1 } }
        ) { observation in
            other.set(42, forKey: "count")

            #expect(fired.withLock { $0 } == 1)
        }
    }

    @Test
    func firesForAWriteThroughAnotherInstanceOnTheFallback() async throws {
        let other = try #require(UserDefaults(suiteName: suiteName))

        let fired = Mutex(0)

        await withObservation(
            key: "com.example.count",
            handler: { fired.withLock { $0 += 1 } }
        ) { observation in
            other.set(42, forKey: "com.example.count")
            await waitForHandlers { fired.withLock { $0 } > 0 }

            #expect(fired.withLock { $0 } == 1)
        }
    }

    // The notification names no key, so without a comparison every write anywhere in the suite
    // would look like a change to this one.
    @Test
    func ignoresChangesToOtherKeysOnTheFallback() async {
        let fired = Mutex(false)

        await withObservation(
            key: "com.example.count",
            handler: { fired.withLock { $0 = true } }
        ) { observation in
            userDefaults.set(42, forKey: "somethingElse")

            #expect(fired.withLock { $0 } == false)
        }
    }

    // `UserDefaults` posts for a write that changed nothing, so the comparison is also what keeps a
    // subscriber from being told about a change that did not happen.
    @Test
    func ignoresARewriteOfTheSameValueOnTheFallback() async {
        userDefaults.set(42, forKey: "com.example.count")

        let fired = Mutex(0)

        await withObservation(
            key: "com.example.count",
            handler: { fired.withLock { $0 += 1 } }
        ) { observation in
            userDefaults.set(42, forKey: "com.example.count")

            #expect(fired.withLock { $0 } == 0)

            userDefaults.set(43, forKey: "com.example.count")
            await waitForHandlers { fired.withLock { $0 } > 0 }

            #expect(fired.withLock { $0 } == 1)
        }
    }
}
#endif
