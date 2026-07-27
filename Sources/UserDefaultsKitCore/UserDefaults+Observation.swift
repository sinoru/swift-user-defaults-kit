//
//  UserDefaults+Observation.swift
//  UserDefaultsKit
//

import Foundation
import SynchronizationKit

extension UserDefaults {
    /// Watches a single key and fans each change out to registered handlers.
    ///
    /// An instance is owned for as long as its changes are wanted and unregisters when it
    /// deinitializes: a Combine subscription, an `AsyncStream`, or a SwiftUI `UserDefaultStorage`
    /// each create and hold their own, so there is no shared, process-lifetime state.
    ///
    /// The backend is chosen once, from the key. Key-Value Observing is the one that carries the
    /// package's promise — Apple documents it as reporting "all updates to setting values,
    /// regardless of which process made the change", which is what lets a write from an app-group
    /// sibling reach a view. It cannot take every key: KVO reads a key as a *key path*, so an empty
    /// key raises the moment it is registered, and a key holding `.` or `@` registers but then
    /// raises inside KVO delivery once the leading segment is written. Both are `NSException`,
    /// which Swift cannot catch, and neither is confined to debug.
    ///
    /// Such a key falls back to `UserDefaults.didChangeNotification`, which is strictly weaker:
    /// Apple documents it as not posted for a change another process made, so the fallback delivers
    /// this process's writes only. It also names no key — a same-value rewrite and
    /// `register(defaults:)` both post it — so the fallback compares the stored value against the
    /// last one it saw rather than reporting every post as a change. That comparison is the one
    /// piece of state here; the KVO backend stores nothing and leaves `UserDefaults` the single
    /// source of truth.
    final package class Observation: NSObject, @unchecked Sendable {
        let key: String
        let userDefaults: UserDefaults

        private let handlers = RWLock<[UUID: @Sendable () -> Void]>([:])

        /// What the notification backend last read, boxed so the mutex will take it.
        ///
        /// `NSObject` rather than `Value`: what is stored is always a property-list object, so
        /// `isEqual(_:)` settles a change — including for a collection — without this type having
        /// to be generic or `Value` having to be `Equatable`.
        ///
        /// The box is what makes it `Sendable`. Region isolation pins whatever `object(forKey:)`
        /// hands back to the region that asked for it, which is right in general and stricter than
        /// it needs to be here: the value crosses only under the mutex, is only ever compared, and
        /// is never handed back out.
        private struct Snapshot: @unchecked Sendable {
            let object: NSObject?
        }

        /// The last value the notification backend saw, and nothing at all under KVO.
        private let lastValue = Mutex<Snapshot>(Snapshot(object: nil))

        /// The `NotificationCenter` registration, and `nil` when this observes with KVO — which is
        /// also how ``deinit`` knows which registration to undo.
        ///
        /// Written once during ``init(key:userDefaults:)`` and read once in `deinit`, so it is a
        /// `var` only because the closure it holds needs a fully initialized `self`.
        private var notificationObserver: (any NSObjectProtocol)?

        package init(key: String, userDefaults: UserDefaults) {
            self.key = key
            self.userDefaults = userDefaults

            super.init()

            guard Self.canObserveWithKeyValueObserving(key) else {
                // Seed before subscribing. The other order would take the first notification's
                // re-read as a change against an empty baseline and fire a handler for a write
                // that never happened.
                lastValue.withLock { $0 = Snapshot(object: userDefaults.object(forKey: key) as? NSObject) }

                // Deliberately unfiltered. `object:` would match the posting *instance*, not the
                // suite, and `UserDefaults(suiteName:)` hands back a new instance every call — so
                // filtering drops a write made through a second instance of the same domain, which
                // is an ordinary thing for an app-group app to do and which the KVO backend
                // reports without complaint. Taking every post and letting the comparison below
                // decide costs one `object(forKey:)` per post and keeps the two backends telling
                // the same story about this process's writes.
                notificationObserver = NotificationCenter.default.addObserver(
                    forName: UserDefaults.didChangeNotification,
                    object: nil,
                    queue: nil
                ) { [weak self] _ in
                    self?.notificationDidPost()
                }

                return
            }

            unsafe userDefaults.addObserver(self, forKeyPath: key, options: [], context: nil)
        }

        deinit {
            if let notificationObserver {
                NotificationCenter.default.removeObserver(notificationObserver)
            } else {
                unsafe userDefaults.removeObserver(self, forKeyPath: key, context: nil)
            }
        }

        /// Whether KVO can observe `key` as the literal key it is.
        ///
        /// An empty key raises at registration; `.` reads as a nested key path and `@` as a
        /// collection operator, either of which raises once the leading segment is written. Every
        /// other spelling this package was measured against — digits, spaces, hyphens, non-ASCII,
        /// and names that collide with `NSObject`'s own, `description` among them — is delivered.
        private static func canObserveWithKeyValueObserving(_ key: String) -> Bool {
            !key.isEmpty && !key.contains(".") && !key.contains("@")
        }

        /// Calls `handler` on every change until the returned token is passed to ``removeHandler(_:)``.
        ///
        /// The handler runs on whichever thread performed the write, so a Combine or async consumer is
        /// never forced onto the main actor.
        package func addHandler(_ handler: @escaping @Sendable () -> Void) -> UUID {
            let token = UUID()
            handlers.withWriteLock { $0[token] = handler }
            return token
        }

        package func removeHandler(_ token: UUID) {
            handlers.withWriteLock { $0[token] = nil }
        }

        /// How many handlers are attached. Exposed so a test can confirm teardown unhooks them.
        var handlerCount: Int {
            handlers.withReadLock { $0.count }
        }

        package override func observeValue(
            forKeyPath keyPath: String?,
            of object: Any?,
            change: [NSKeyValueChangeKey: Any]?,
            context: UnsafeMutableRawPointer?
        ) {
            guard
                (object as? UserDefaults) === userDefaults,
                keyPath == key
            else {
                return unsafe super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            }

            callHandlers()
        }

        /// The fallback's counterpart to ``observeValue(forKeyPath:of:change:context:)``.
        ///
        /// The notification says only that *something* in the suite changed, so this re-reads the
        /// key and reports a change only when the value actually moved.
        private func notificationDidPost() {
            // The read belongs inside the lock. Two writers post concurrently, and reading first
            // would let the older callback take the mutex second and set the baseline backwards —
            // after which the next post for any key in the process compares against a value that
            // was never current and reports a change nobody made.
            let changed = lastValue.withLock { last -> Bool in
                let current = Snapshot(object: userDefaults.object(forKey: key) as? NSObject)
                let changed: Bool

                switch (last.object, current.object) {
                case (nil, nil):
                    changed = false
                case let (previous?, current?):
                    changed = !previous.isEqual(current)
                default:
                    changed = true
                }

                last = current

                return changed
            }

            guard changed else { return }

            callHandlers()
        }

        private func callHandlers() {
            // Snapshot inside the lock, call outside it. A handler is free to re-enter — an
            // `AsyncStream` terminating from within one calls ``removeHandler(_:)`` — and neither
            // lock is recursive. Copying the dictionary out is a COW retain rather than an
            // allocation, so the copy is paid by the next writer, which is the rare path;
            // building an `Array` here would instead allocate on every change.
            for handler in handlers.withReadLock({ $0 }).values {
                handler()
            }
        }
    }
}
