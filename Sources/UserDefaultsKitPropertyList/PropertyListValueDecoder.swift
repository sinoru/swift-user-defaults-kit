//
//  PropertyListValueDecoder.swift
//  UserDefaultsKitPropertyList
//

/// Decodes a `Decodable` value out of a ``PropertyListValue``.
///
/// This is what `PropertyListDecoder` would be if it took a property list rather than the bytes of
/// one. Nothing here parses: the tree is already a tree, so a value that came out of `UserDefaults`
/// is read once instead of being serialized to `Data` and scanned back.
///
/// Where it reads a number differently from `PropertyListDecoder`, it does so on purpose. A property
/// list keeps no `Int`/`Float`/`Double` distinction — every number is `<integer>` or `<real>` — so
/// asking for one and finding the other is not a mismatch, and refusing it would drop a value
/// another writer meant as a number. `PropertyListDecoder` refuses; this converts, at every depth
/// rather than only at the top:
///
/// - An integer type reads a `<real>` by truncating toward zero, and a value it cannot hold — or a
///   NaN — is an error rather than a trap.
/// - A floating-point type reads whatever is stored, without requiring the result to be exact.
///   `PropertyListDecoder` would reject `1.1` read as a `Float`, since it has no binary32 form.
/// - `Bool` reads `<true/>`, `<false/>`, and a number that is exactly `0` or `1`. Anything else is a
///   mismatch, including the non-zero numbers `bool(forKey:)` would flatten into `true`.
///
/// Everything else is read strictly: a string is a string, and a value of an unrelated kind is an
/// error.
package struct PropertyListValueDecoder: Sendable {
    package init() {}

    /// Decodes a value of the given type from a property list value.
    ///
    /// - Parameters:
    ///   - type: The type to decode.
    ///   - value: The property list value to read.
    /// - Returns: The decoded value.
    /// - Throws: A `DecodingError` when the value cannot be read as `type`.
    package func decode<T>(_ type: T.Type, from value: PropertyListValue) throws -> T where T: Decodable {
        try _Decoder(value: value, owner: nil, codingKey: nil).unwrap(as: type)
    }
}
