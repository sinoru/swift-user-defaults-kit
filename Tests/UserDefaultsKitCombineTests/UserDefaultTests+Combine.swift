//
//  UserDefaultTests+Combine.swift
//  UserDefaultsKit
//
//  Created by Kang Jaehong on 7/12/26.
//

#if canImport(Combine)
import Combine
import Foundation
import Testing
import UserDefaultsKitTestSupport

@testable import UserDefaultsKitCore
@testable import UserDefaultsKitCombine

@Suite("UserDefault + Combine")
final class UserDefaultCombineTests: UserDefaultsTestCase {
    @Test
    func emitsTheCurrentValueWhenASubscriberAttaches() throws {
        userDefaults.set(5, forKey: "count")
        let count = UserDefault(key: "count", defaultValue: 0, userDefaults: userDefaults)

        let recorder = Recorder<Int>()
        count.publisher.receive(subscriber: recorder)
        defer { recorder.cancel() }

        #expect(recorder.values == [5])
    }

    @Test
    func emitsTheDefaultValueWhenTheKeyIsAbsent() {
        let count = UserDefault(key: "count", defaultValue: 7, userDefaults: userDefaults)

        let recorder = Recorder<Int>()
        count.publisher.receive(subscriber: recorder)
        defer { recorder.cancel() }

        #expect(recorder.values == [7])
    }

    @Test
    func deliversTheSubscriptionBeforeAnyValue() {
        let count = UserDefault(key: "count", defaultValue: 0, userDefaults: userDefaults)

        let recorder = Recorder<Int>()
        count.publisher.receive(subscriber: recorder)
        defer { recorder.cancel() }

        // Combine requires `receive(subscription:)` to precede every `receive(_:)`. Operators such
        // as `first()` and `receive(on:)` drop values that arrive before they hold a subscription.
        #expect(recorder.didReceiveValueBeforeSubscription == false)
    }

    @Test
    func emitsWhenTheKitWritesTheValue() throws {
        let count = UserDefault(key: "count", defaultValue: 0, userDefaults: userDefaults)

        let recorder = Recorder<Int>()
        count.publisher.receive(subscriber: recorder)
        defer { recorder.cancel() }

        count.wrappedValue = 1
        count.wrappedValue = 2

        #expect(recorder.values == [0, 1, 2])
    }

    @Test
    func emitsWhenFoundationWritesTheValue() {
        let count = UserDefault(key: "count", defaultValue: 0, userDefaults: userDefaults)

        let recorder = Recorder<Int>()
        count.publisher.receive(subscriber: recorder)
        defer { recorder.cancel() }

        userDefaults.set(1, forKey: "count")

        #expect(recorder.values == [0, 1])
    }

    @Test
    func emitsTheDefaultValueWhenTheKeyIsRemoved() {
        userDefaults.set(5, forKey: "count")
        let count = UserDefault(key: "count", defaultValue: 7, userDefaults: userDefaults)

        let recorder = Recorder<Int>()
        count.publisher.receive(subscriber: recorder)
        defer { recorder.cancel() }

        userDefaults.removeObject(forKey: "count")

        #expect(recorder.values == [5, 7])
    }

    @Test
    func ignoresChangesToOtherKeys() {
        let count = UserDefault(key: "count", defaultValue: 0, userDefaults: userDefaults)

        let recorder = Recorder<Int>()
        count.publisher.receive(subscriber: recorder)
        defer { recorder.cancel() }

        userDefaults.set(99, forKey: "somethingElse")

        #expect(recorder.values == [0])
    }

    @Test
    func stopsEmittingAfterCancellation() {
        let count = UserDefault(key: "count", defaultValue: 0, userDefaults: userDefaults)

        let recorder = Recorder<Int>()
        count.publisher.receive(subscriber: recorder)

        recorder.cancel()
        userDefaults.set(1, forKey: "count")

        #expect(recorder.values == [0])
    }

    @Test
    func honorsTheSubscribersDemand() {
        let count = UserDefault(key: "count", defaultValue: 0, userDefaults: userDefaults)

        let recorder = Recorder<Int>(demand: .max(1))
        count.publisher.receive(subscriber: recorder)
        defer { recorder.cancel() }

        userDefaults.set(1, forKey: "count")
        userDefaults.set(2, forKey: "count")

        // The subscriber asked for one value and returned `.none` from `receive(_:)`, so the
        // publisher must not send any more.
        #expect(recorder.values.count == 1)
    }
}

/// A `Subscriber` that records everything it is handed, so that a test can assert on the values,
/// on their order relative to the subscription, and on whether demand was honored.
private final class Recorder<Input>: Combine.Subscriber, @unchecked Sendable {
    typealias Failure = Never

    private let initialDemand: Subscribers.Demand
    private var subscription: (any Combine.Subscription)?

    private(set) var values: [Input] = []
    private(set) var didReceiveValueBeforeSubscription = false

    init(demand: Subscribers.Demand = .unlimited) {
        self.initialDemand = demand
    }

    func receive(subscription: any Combine.Subscription) {
        self.subscription = subscription
        subscription.request(initialDemand)
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        if subscription == nil {
            didReceiveValueBeforeSubscription = true
        }
        values.append(input)
        return .none
    }

    func receive(completion: Subscribers.Completion<Never>) {}

    func cancel() {
        subscription?.cancel()
        subscription = nil
    }
}
#endif
