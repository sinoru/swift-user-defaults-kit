//
//  PropertyListValue.swift
//  UserDefaultsKitPropertyList
//

import Foundation

/// A value in one of the shapes a property list can hold.
///
/// This is the model a property list actually has, not the one Swift would pick for it. It exists so
/// that encoding and decoding can happen against a typed tree instead of against `Any`, which is
/// what `UserDefaults` and `PropertyListSerialization` deal in — see ``init(propertyList:)`` and
/// ``propertyList``.
///
/// Three of the choices are worth spelling out, because each of them is a place where the format and
/// Swift disagree:
///
/// - There is no null. A property list has no such value, so a `nil` inside one is a convention
///   between an encoder and a decoder rather than something the format can carry. That convention
///   belongs to whoever writes those, not here.
/// - ``bool(_:)`` is separate from ``integer(_:)``. `<true/>` and `<integer>1</integer>` are
///   different values in the format, `defaults(1)` prints them differently, and a reader asking for
///   one when the other is stored is asking about the writer's intent — which is only answerable
///   while the two are still distinguishable.
/// - ``unsignedInteger(_:)`` exists only for what ``integer(_:)`` cannot hold, which is every value
///   above `Int64.max`. Keeping it to that leaves one spelling per number, so two values that are
///   the same number are also `==`. Anything building a `PropertyListValue` is expected to try
///   `Int64` first.
///
/// A `Float` widens into ``real(_:)`` rather than getting a case of its own. Nothing is lost by it:
/// every `Float` converts to `Double` exactly and converts back exactly, so the only difference is
/// four bytes in a binary property list.
package enum PropertyListValue: Hashable, Sendable {
    case dictionary([String: PropertyListValue])
    case array([PropertyListValue])
    case string(String)
    case data(Data)
    case date(Date)
    case bool(Bool)
    case integer(Int64)
    case unsignedInteger(UInt64)
    case real(Double)
}
