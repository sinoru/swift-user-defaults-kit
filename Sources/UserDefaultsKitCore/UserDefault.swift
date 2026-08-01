//
//  UserDefault.swift
//  UserDefaultsKit
//
//  Created by Kang Jaehong on 7/12/26.
//

import Foundation

/// Reads and writes a `Codable` value in `UserDefaults`.
///
/// Unlike `@AppStorage`, `Value` is not limited to the property-list types: anything `Codable`
/// works, encoded *into* a property list when it has no native form of its own — a struct as a
/// dictionary, a `String`-backed enum as a string. Nothing this package encodes is archived, so
/// those defaults stay readable by `defaults(1)`, by `@AppStorage`, and by any other process
/// sharing the domain.
///
/// Observe changes with `publisher` from `UserDefaultsKitCombine`, or with ``values``
/// (`AsyncSequence`). For a SwiftUI view that updates when the value changes — including a change
/// made by another process sharing the suite — use `UserDefaultStorage` from
/// `UserDefaultsKitSwiftUI`.
///
/// Reading and writing works wherever Foundation does; those three do not. Watching a key needs the
/// Objective-C runtime, which swift-corelibs-foundation has no equivalent for, so all three are
/// Darwin-only and simply absent elsewhere rather than present and silent.
///
/// The projected value is the wrapper itself, so the observation surfaces hang off `$`:
///
/// ```swift
/// @UserDefault("username") var username = "anonymous"
///
/// $username.publisher.sink { ... }             // Combine
/// for await name in $username.values { ... }   // AsyncSequence
/// TextField("Name", text: $username.binding)   // SwiftUI, via UserDefaultsKitSwiftUI
/// ```
@propertyWrapper
public struct UserDefault<Value>: Sendable where Value: Codable, Value: Sendable {
    /// The key the value is stored under.
    ///
    /// Key-Value Observing reads a key as a *key path*, so an empty key — or one containing `.` or
    /// `@` — cannot be observed as the literal key it is. Such a key still reads and writes
    /// correctly and its changes are still delivered, but by a weaker fallback that sees only this
    /// process: `publisher`, ``values`` and a SwiftUI view all keep working for a write this app
    /// made, and none of them notices one made by an app extension or another app-group member.
    /// Prefer a key without `.`/`@` for anything that has to follow another process.
    public let key: String

    /// The value to report while ``key`` holds nothing readable as `Value`.
    ///
    /// This value is never written to ``userDefaults``. Reading a key does not create it, so the
    /// key stays absent from the defaults database — and legible as absent to every other process —
    /// until something assigns to it.
    public let defaultValue: Value

    /// The defaults database the value lives in.
    ///
    /// `UserDefaults.standard` unless the wrapper was given a suite, which is how a value is shared
    /// with an app extension or with another member of an app group.
    public var userDefaults: UserDefaults { unsafe _userDefaults }

    /// Backs ``userDefaults``, and the reason that one is computed.
    ///
    /// `UserDefaults` carries no `Sendable` conformance — it is an `open` class, so Apple cannot
    /// add one — while its documentation says "The `UserDefaults` type is thread-safe, and you can
    /// use the same object in multiple threads or tasks simultaneously." Opting out here is the
    /// only way for this wrapper to be `Sendable`, and it is sound.
    ///
    /// Keeping the storage private is what stops that opt-out from spreading: on a `public let`,
    /// every client compiling with strict memory safety has to write `unsafe` to read a property
    /// whose safety this package has already established. Absorbing it is what ``wrappedValue``
    /// does too.
    private nonisolated(unsafe) let _userDefaults: UserDefaults

    /// The wrapper itself, which is what puts the observation surfaces behind `$`.
    ///
    /// ```swift
    /// $username.publisher   // Combine
    /// $username.values      // AsyncSequence
    /// $username.binding     // SwiftUI, via UserDefaultsKitSwiftUI
    /// ```
    public var projectedValue: UserDefault<Value> { self }

    /// The value stored under ``key``, or ``defaultValue`` when the key holds nothing.
    ///
    /// Nothing is cached: every read goes to ``userDefaults``, so the value can never be stale. To
    /// react to changes, observe `publisher` or ``values``, or drive a SwiftUI view with
    /// `UserDefaultStorage`.
    ///
    /// Assigning writes through at once. Where `Value` is optional, assigning `nil` removes the key
    /// rather than storing a null, and subsequent reads report ``defaultValue`` again.
    ///
    /// A setter cannot throw, so an assignment whose value fails to encode is ignored rather than
    /// reported: ``key`` keeps whatever it held, and reading afterwards reports neither the assigned
    /// value nor ``defaultValue`` but the previous one. In debug this trips an assertion.
    public var wrappedValue: Value {
        get {
            userDefaults[key, default: defaultValue]
        }
        nonmutating set {
            userDefaults[key] = newValue
        }
    }

    /// Creates a wrapper over the value stored under a key.
    ///
    /// - Parameters:
    ///   - key: The key to read and write. A key containing `.` or `@` only observes this process's
    ///     own writes; see ``key``.
    ///   - defaultValue: The value to report while the key holds nothing readable as `Value`.
    ///   - userDefaults: The defaults database to read and write. Pass a suite to share the value
    ///     with an app extension or another member of an app group.
    public init(key: String, defaultValue: Value, userDefaults: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        unsafe self._userDefaults = userDefaults
    }

    /// Creates a wrapper that takes its default from the declaration it is attached to.
    ///
    /// This is how a property wrapper is normally spelled, and it is the same shape `@AppStorage`
    /// and `UserDefaultStorage` take:
    ///
    /// ```swift
    /// @UserDefault("username") var username = "anonymous"
    /// ```
    ///
    /// ``init(key:defaultValue:userDefaults:)`` is the one to reach for away from a declaration —
    /// building a wrapper to hand around, rather than attaching one.
    ///
    /// - Parameters:
    ///   - defaultValue: The value to report while the key holds nothing readable as `Value`,
    ///     supplied as the wrapped property's initial value.
    ///   - key: The key to read and write. A key containing `.` or `@` only observes this process's
    ///     own writes; see ``key``.
    ///   - store: The defaults database to read and write. Pass a suite to share the value with an
    ///     app extension or another member of an app group.
    public init(wrappedValue defaultValue: Value, _ key: String, store: UserDefaults = .standard) {
        self.init(key: key, defaultValue: defaultValue, userDefaults: store)
    }
}
