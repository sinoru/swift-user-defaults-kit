//
//  UserDefault+Combine.swift
//  UserDefaultsKit
//
//  Created by Kang Jaehong on 7/12/26.
//

#if canImport(Combine)
import Combine
import Foundation
import UserDefaultsKitCore

extension UserDefault {
    /// The current value, followed by the value after every change to `key`.
    ///
    /// `CurrentValueSubject` is what delivers the current value on subscribe, and it is also what
    /// keeps the Combine contract: it hands the subscriber its subscription before any value, and
    /// it drops values a subscriber has not asked for rather than over-sending. Hand-rolling a
    /// `Subscription` to do the same means reimplementing both, which is easy to get wrong.
    ///
    /// Values arrive on whichever thread performed the write. Add `.receive(on:)` if a consumer
    /// needs a particular one.
    public var publisher: AnyPublisher<Value, Never> {
        Deferred {
            // Combine predates Swift concurrency and never marked its subjects `Sendable`. Apple
            // does not document `send(_:)` as callable from any thread either, so this opt-out is
            // an assumption rather than a guarantee. The handler runs on whichever thread performed
            // the write, so two threads writing the same key deliver concurrently: a subscriber
            // holding mutable state should serialize it rather than lean on Combine's usual
            // one-at-a-time delivery.
            nonisolated(unsafe) let subject = CurrentValueSubject<Value, Never>(wrappedValue)
            let observation = unsafe UserDefaults.Observation(key: key, userDefaults: userDefaults)

            // `self` is a `Sendable` value, and re-reading `wrappedValue` goes back to
            // `UserDefaults` every time. Capturing the value instead would freeze it at
            // subscribe time.
            let token = observation.addHandler {
                unsafe subject.send(self.wrappedValue)
            }

            // Re-seed now that the handler is attached: a write that landed between constructing
            // the subject and attaching would otherwise be lost, leaving the subject holding a
            // value nobody will ever correct. This narrows the window rather than closing it —
            // reading `wrappedValue` and assigning it are two steps, so a write landing between
            // them is published by the handler and then overwritten by the older read. Reaching it
            // takes a concurrent writer. Do not hold a lock across the assignment: `send(_:)` runs
            // downstream synchronously, which turns that into a re-entrancy hazard.
            unsafe subject.value = wrappedValue

            return unsafe subject
                .handleEvents(receiveCancel: { observation.removeHandler(token) })
        }
        .eraseToAnyPublisher()
    }
}
#endif
