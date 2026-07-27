//
//  Profile.swift
//  UserDefaultsKit
//
//  Created by Kang Jaehong on 7/18/26.
//

package struct Profile: Codable, Equatable, Sendable {
    package var name: String
    package var age: Int
    package var tags: [String]

    package init(name: String, age: Int, tags: [String]) {
        self.name = name
        self.age = age
        self.tags = tags
    }
}
