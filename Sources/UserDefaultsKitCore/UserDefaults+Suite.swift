//
//  UserDefaults+Suite.swift
//  UserDefaultsKit
//

package import Foundation

extension UserDefaults {
    /// Returns a new instance of the suite named `suiteName`.
    ///
    /// New on every call, as `UserDefaults(suiteName:)` is — which is why this is not spelled as
    /// though it looked one up.
    ///
    /// `UserDefaults(suiteName:)` is failable, and a property wrapper's attribute has nowhere to
    /// put a `nil`. The names it refuses are not ones a running app arrives at by accident —
    /// `UserDefaults.globalDomain`, which its documentation says not to pass, is one — so a refusal
    /// is a mistake in the declaration, and trapping where the wrapper is made says so. Falling
    /// back to `standard` would instead write a value meant for an app group into the app's own
    /// domain, and say nothing.
    ///
    /// - Precondition: `suiteName` is a name `UserDefaults(suiteName:)` opens. One it refuses,
    ///   `UserDefaults.globalDomain` among them, traps.
    package static func makeSuite(named suiteName: String) -> UserDefaults {
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            preconditionFailure(
                "UserDefaults(suiteName:) refused \"\(suiteName)\". Pass an app group identifier or "
                    + "another suite name, not UserDefaults.globalDomain."
            )
        }

        return userDefaults
    }
}
