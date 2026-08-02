//
//  Profile.swift
//  UserDefaultsKit
//
//  Created by Kang Jaehong on 7/18/26.
//

/// A value with no property-list form of its own, which the kit therefore has to encode into one.
///
/// One property is optional so that both halves of what a synthesized `Codable` does with `nil` are
/// reachable from a single fixture: `encodeIfPresent` leaves the key out rather than writing the
/// sentinel, and `decodeIfPresent` reads a key that holds the sentinel back as `nil`. It defaults to
/// `nil` so a test that has nothing to say about it can go on ignoring it.
package struct Profile: Codable, Equatable, Sendable {
    package var name: String
    package var age: Int
    package var tags: [String]
    package var nickname: String?

    package init(name: String, age: Int, tags: [String], nickname: String? = nil) {
        self.name = name
        self.age = age
        self.tags = tags
        self.nickname = nickname
    }
}
