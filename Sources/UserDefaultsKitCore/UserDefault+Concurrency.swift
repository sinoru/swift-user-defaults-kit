//
//  UserDefault+Concurrency.swift
//  UserDefaultsKit
//

import Foundation

extension UserDefault {
    /// The current value, followed by the value after every change to ``key``.
    ///
    /// A slow consumer sees only the newest value rather than a backlog, which is what a setting
    /// wants: `bufferingNewest(1)` is the async counterpart of the demand a Combine subscriber
    /// would apply.
    ///
    /// Values are produced on whichever thread performed the write; iterate from wherever suits.
    public var values: AsyncStream<Value> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let observation = unsafe UserDefaults.Observation(key: key, userDefaults: userDefaults)

            // Attach before seeding. The other order would drop a write that landed in between.
            // This order usually only repeats a value, since the handler re-reads from
            // `UserDefaults`, but it does not close the window: reading `wrappedValue` and yielding
            // it are two steps, so a write landing between them is yielded by the handler first and
            // then displaced by the older read — under `.bufferingNewest(1)` the newer value is the
            // one dropped. Reaching it takes a concurrent writer.
            let token = observation.addHandler {
                continuation.yield(self.wrappedValue)
            }

            continuation.yield(wrappedValue)

            continuation.onTermination = { _ in
                observation.removeHandler(token)
            }
        }
    }
}
