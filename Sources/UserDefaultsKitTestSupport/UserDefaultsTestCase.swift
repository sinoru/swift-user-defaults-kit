//
//  UserDefaultsTestCase.swift
//  UserDefaultsKit
//

import Foundation
import Testing

/// Gives each test its own `UserDefaults` suite, removed once the test finishes.
///
/// Swift Testing runs tests in parallel and `UserDefaults` persists through `cfprefsd` to disk, so
/// tests must not share a domain. Suites that need defaults inherit from this type; do not declare
/// `@Test` functions here, or this base type would register as a suite of its own.
open class UserDefaultsTestCase {
    package let suiteName: String
    package let userDefaults: UserDefaults

    package init() throws {
        let suiteName = "UserDefaultsKitTests.\(UUID().uuidString)"
        self.suiteName = suiteName
        self.userDefaults = try #require(UserDefaults(suiteName: suiteName))
    }

    deinit {
        userDefaults.removePersistentDomain(forName: suiteName)
    }
}
