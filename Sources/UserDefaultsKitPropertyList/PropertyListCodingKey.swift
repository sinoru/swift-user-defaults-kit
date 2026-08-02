//
//  PropertyListCodingKey.swift
//  UserDefaultsKitPropertyList
//

/// The keys a container has to invent, for the two places `Codable` has no key of its own to give.
///
/// An unkeyed container names its elements by position, and `superDecoder()`/`superEncoder()` name
/// a slot that no `CodingKey` the caller wrote ever points at. Both only ever reach a caller inside
/// the `codingPath` of an error.
enum PropertyListCodingKey: CodingKey {
    case index(Int)
    case `super`

    var stringValue: String {
        switch self {
        case .index(let index):
            "Index \(index)"
        case .super:
            "super"
        }
    }

    var intValue: Int? {
        switch self {
        case .index(let index):
            index
        case .super:
            nil
        }
    }

    init?(stringValue: String) {
        guard stringValue == "super" else { return nil }

        self = .super
    }

    init?(intValue: Int) {
        self = .index(intValue)
    }
}
