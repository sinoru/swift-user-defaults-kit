//
//  UserDefaultStorage.swift
//  UserDefaultsKitSwiftUI
//

#if canImport(SwiftUI)
import Combine
public import Foundation
public import SwiftUI
package import UserDefaultsKitCore

/// Reads and writes a `Codable` value in `UserDefaults` and refreshes the view when it changes —
/// including a change made by another process sharing the suite.
///
/// This is the SwiftUI-reactive counterpart to `UserDefault`, and the `Codable` analogue of
/// `@AppStorage`: SwiftUI owns the observation for the lifetime of the view, so there is no shared,
/// process-lifetime state, and it is torn down with the view. Its projected value is a `Binding`, so
/// it drops into any control that takes one.
///
/// ```swift
/// struct SettingsView: View {
///     @UserDefaultStorage("username") var username = "anonymous"
///
///     var body: some View {
///         TextField("Name", text: $username)
///     }
/// }
/// ```
///
/// - Note: A key containing `.` or `@` falls back to an observation that sees only this process, so
///   the view refreshes for a write this app made but not for one another app-group member made.
///   See `UserDefault.key`.
@propertyWrapper
public struct UserDefaultStorage<Value>: DynamicProperty where Value: Codable, Value: Sendable {
    @StateObject private var coordinator = Coordinator<Value>()
    private let userDefault: UserDefault<Value>

    /// The name the suite was opened by, and `nil` when the wrapper was handed an instance.
    ///
    /// Kept because it is the only thing that says two instances are the same suite; see
    /// ``init(wrappedValue:_:suiteName:)``.
    private let suiteName: String?

    /// Creates a storage wrapper over the value stored under a key.
    ///
    /// - Parameters:
    ///   - defaultValue: The value to report while the key holds nothing. Supplied as the wrapper's
    ///     initial value (`@UserDefaultStorage("k") var x = 0`).
    ///   - key: The key to read and write. A key containing `.` or `@` only observes this process's
    ///     own writes; see `UserDefault.key`.
    ///   - store: The defaults database. Pass a suite to share with an app extension or app group —
    ///     and hold that suite somewhere rather than building it in the declaration.
    ///     `UserDefaults(suiteName:)` returns a new instance on every call, so one written inline in
    ///     a view is a different instance each update, and the observation can only tell stores
    ///     apart by instance. It would tear down and rebuild on every update, losing any write that
    ///     landed in the gap. ``init(wrappedValue:_:suiteName:)`` takes the name instead and has
    ///     nothing to hold.
    public init(wrappedValue defaultValue: Value, _ key: String, store: UserDefaults = .standard) {
        userDefault = UserDefault(key: key, defaultValue: defaultValue, userDefaults: store)
        suiteName = nil
    }

    /// Creates a storage wrapper over the value stored under a key in a suite, named rather than
    /// passed.
    ///
    /// ```swift
    /// @UserDefaultStorage("username", suiteName: "group.com.example.app") var username = "anonymous"
    /// ```
    ///
    /// This is the spelling for a value shared with an app extension or an app group. A
    /// `UserDefaults` will not say which suite it opened, so an instance can only be told apart
    /// from another by identity; a name can be compared. The observation therefore stays where it
    /// is for as long as the name does, however many times the view is rebuilt, and the suite can
    /// be named right in the declaration with nothing held anywhere.
    ///
    /// - Parameters:
    ///   - defaultValue: The value to report while the key holds nothing. Supplied as the wrapper's
    ///     initial value.
    ///   - key: The key to read and write. A key containing `.` or `@` only observes this process's
    ///     own writes; see `UserDefault.key`.
    ///   - suiteName: The app group identifier, or other suite name, to read and write — what
    ///     `UserDefaults(suiteName:)` takes.
    ///
    /// - Precondition: `suiteName` is a name `UserDefaults(suiteName:)` opens. One it refuses,
    ///   `UserDefaults.globalDomain` among them, is a mistake in the declaration and traps.
    public init(wrappedValue defaultValue: Value, _ key: String, suiteName: String) {
        userDefault = UserDefault(key: key, defaultValue: defaultValue, suiteName: suiteName)
        self.suiteName = suiteName
    }

    /// Points the observation at the current key and store, and re-points it when either changes.
    ///
    /// `@StateObject` builds its object once per view identity and discards every later one, so a
    /// view that keeps its identity while its key changes — a row in a `ForEach`, say — would go on
    /// observing whichever key it was first given while ``wrappedValue`` reads and writes the new
    /// one. Writes still land correctly; the view just stops refreshing, which is why the bug hides.
    /// Re-pointing here is what `@AppStorage` does by re-resolving its location on every update.
    ///
    /// This deliberately does not invalidate. `update()` runs immediately before `body`, so sending
    /// `objectWillChange` from here would be a state change during view update — and the new key
    /// needs no invalidation anyway, since ``wrappedValue`` reads it directly.
    ///
    /// `DynamicProperty.update()` is not itself declared on the main actor, but SwiftUI only ever
    /// calls it while updating a view, which is main-actor work — hence `assumeIsolated` rather
    /// than a hop that would land after `body` had already read the wrong subscription.
    public func update() {
        // Capture the pieces rather than `self`: the wrapper is not `Sendable`, and handing the
        // whole of it to a main-actor closure is what the region checker objects to.
        let storage = _coordinator
        let userDefault = userDefault
        let suiteName = suiteName

        MainActor.assumeIsolated {
            storage.wrappedValue.observe(userDefault, suiteName: suiteName)
        }
    }

    public var wrappedValue: Value {
        get { userDefault.wrappedValue }
        nonmutating set { userDefault.wrappedValue = newValue }
    }

    public var projectedValue: Binding<Value> {
        let userDefault = userDefault
        return Binding(
            get: { userDefault.wrappedValue },
            set: { userDefault.wrappedValue = $0 }
        )
    }
}

/// Bridges a change to a `UserDefault`'s key to SwiftUI's view invalidation. `@StateObject` keeps
/// one alive per view and releases it when the view goes away, which lets the underlying observation
/// deinitialize — so nothing is retained process-wide.
///
/// The observation is made from `UserDefaultStorage.update()` rather than from `init`, which is
/// what lets it follow a key that changes under a view that kept its identity.
package final class Coordinator<Value>: ObservableObject where Value: Codable, Value: Sendable {
    /// The current subscription. Readable so a test can confirm one was kept rather than remade.
    package private(set) var observation: UserDefaults.Observation?

    /// Spelled out: a `package` type's implicit initializer stays `internal`, and the tests make
    /// one of these without a view around it.
    package init() {}

    /// Where the current subscription points. Readable so a test can confirm it follows the key.
    package private(set) var observed: (key: String, store: ObservedStore)?

    /// Observes `userDefault`'s key, and does nothing when already observing the same key in the
    /// same store — which is every update but the first, so re-observing is the rare path.
    ///
    /// What "the same store" means is ``ObservedStore``'s to say: the name where `suiteName` is
    /// given, and the instance where it is not. Under a name, the wrapper opens a new instance of
    /// the suite each time the view is rebuilt, and the one already observed goes on reporting
    /// what any of them writes — so it is kept.
    package func observe(_ userDefault: UserDefault<Value>, suiteName: String? = nil) {
        let userDefaults = userDefault.userDefaults
        let store = suiteName.map(ObservedStore.suite(named:)) ?? .instance(userDefaults)

        if let observed, observed.key == userDefault.key, observed.store == store {
            return
        }

        // The publisher rather than `self`, which is not `Sendable` and which the handler has no
        // other use for. Combine never marked its publishers `Sendable` either; this one is only
        // ever sent from the main queue, here.
        nonisolated(unsafe) let objectWillChange = objectWillChange

        // A change is all a view needs to hear of. `UserDefault.publisher` would read and decode
        // the value to say so, on the writing thread, and the view reads it again in `body`
        // regardless.
        observed = (userDefault.key, store)
        observation = UserDefaults.Observation(key: userDefault.key, userDefaults: userDefaults) {
            // KVO fires on the writing thread; invalidate on main.
            DispatchQueue.main.async {
                unsafe objectWillChange.send()
            }
        }
    }
}

/// What tells one store from another, as far as an observation has to know.
///
/// One or the other, never both: a name where the wrapper was given one, since a name can be
/// compared, and an instance where it was not. An instance is compared by identity because
/// `UserDefaults` offers nothing else — it will not say which suite it opened. That reads the
/// caller's intent correctly as long as the caller holds its suite, and misreads it when the suite
/// is built inline in the declaration; see the `store:` note on
/// `UserDefaultStorage.init(wrappedValue:_:store:)`.
///
/// The two never compare equal to each other, even over one suite. Nothing can tell that they are
/// the same, and a view that goes from one spelling to the other is re-observed once.
package enum ObservedStore: Equatable {
    /// A suite the wrapper was given the name of, compared by that name.
    case suite(named: String)

    /// A store the wrapper was handed, compared by identity.
    case instance(UserDefaults)

    package static func == (lhs: ObservedStore, rhs: ObservedStore) -> Bool {
        switch (lhs, rhs) {
        case let (.suite(lhs), .suite(rhs)):
            lhs == rhs
        case let (.instance(lhs), .instance(rhs)):
            lhs === rhs
        case (.suite, .instance), (.instance, .suite):
            false
        }
    }
}
#endif
