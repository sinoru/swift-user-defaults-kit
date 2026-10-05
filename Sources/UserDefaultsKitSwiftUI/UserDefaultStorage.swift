//
//  UserDefaultStorage.swift
//  UserDefaultsKitSwiftUI
//

#if canImport(SwiftUI)
import Combine
public import Foundation
public import SwiftUI
import UserDefaultsKitCore

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
    ///     landed in the gap.
    public init(wrappedValue defaultValue: Value, _ key: String, store: UserDefaults = .standard) {
        userDefault = UserDefault(key: key, defaultValue: defaultValue, userDefaults: store)
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
        // Capture the two pieces rather than `self`: the wrapper is not `Sendable`, and handing the
        // whole of it to a main-actor closure is what the region checker objects to.
        let storage = _coordinator
        let userDefault = userDefault

        MainActor.assumeIsolated {
            storage.wrappedValue.observe(userDefault)
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
final class Coordinator<Value>: ObservableObject where Value: Codable, Value: Sendable {
    private var observation: UserDefaults.Observation?

    /// Where the current subscription points. Readable so a test can confirm it follows the key.
    private(set) var observed: (key: String, store: UserDefaults)?

    /// Observes `userDefault`'s key, and does nothing when already observing the same key in the
    /// same store — which is every update but the first, so re-observing is the rare path.
    ///
    /// Stores are compared by instance because `UserDefaults` offers nothing else to compare: it
    /// will not say which suite it opened. That reads the caller's intent correctly as long as the
    /// caller holds its suite, and misreads it when the suite is built inline in the declaration —
    /// see the `store:` note on `UserDefaultStorage.init(wrappedValue:_:store:)`.
    func observe(_ userDefault: UserDefault<Value>) {
        let store = userDefault.userDefaults

        if let observed, observed.key == userDefault.key, observed.store === store {
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
        observation = UserDefaults.Observation(key: userDefault.key, userDefaults: store) {
            // KVO fires on the writing thread; invalidate on main.
            DispatchQueue.main.async {
                unsafe objectWillChange.send()
            }
        }
    }
}
#endif
