//
//  PropertyListValueEncoder.swift
//  UserDefaultsKitPropertyList
//

/// Encodes an `Encodable` value into a ``PropertyListValue``.
///
/// This is what `PropertyListEncoder` would be if it stopped before serializing. What comes back is
/// the tree, so a value on its way into `UserDefaults` is built once instead of being written to
/// `Data` and parsed back out to get at the objects inside.
///
/// It also takes a top-level fragment, which `PropertyListEncoder` refuses. A `String`-backed enum
/// encodes to exactly that, and getting one through the other encoder means wrapping it in a
/// single-element array and unwrapping the result afterwards.
///
/// Numbers are written in the shape the format has: an integer becomes ``PropertyListValue/integer``
/// where `Int64` can hold it and ``PropertyListValue/unsignedInteger`` above that, and `Float` and
/// `Double` both become ``PropertyListValue/real``. A `nil` becomes ``PropertyListValue/null``,
/// which is the string Foundation writes one as.
package struct PropertyListValueEncoder: Sendable {
    package init() {}

    /// Encodes a value into its property list form.
    ///
    /// - Parameter value: The value to encode.
    /// - Returns: The property list value it encoded to.
    /// - Throws: An `EncodingError` when the value cannot be written as a property list — a number
    ///   too wide to store, or a type that encodes nothing at all.
    package func encode<T>(_ value: T) throws -> PropertyListValue where T: Encodable {
        try _Encoder(owner: nil, codingKey: nil).wrapTopLevel(value)
    }
}
