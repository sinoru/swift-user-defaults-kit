//
//  UserDefaults+Codable.swift
//  UserDefaultsKit
//
//  Created by Kang Jaehong on 7/12/26.
//

import Foundation

extension UserDefaults {
    /// Accesses the `Codable` value stored under a key.
    ///
    /// A value that has a property-list form is stored in it, and anything else is *encoded into*
    /// one: a struct lands as a dictionary, a `String`-backed enum as a string. Nothing this
    /// package encodes becomes an opaque archive, so a type Foundation had no way to write stays as
    /// legible to `defaults(1)`, to `@AppStorage`, and to any other process sharing the domain as
    /// one it did — which is the whole point.
    ///
    /// ```swift
    /// userDefaults["username"] = "anonymous"          // stored as a string
    /// userDefaults["profile"] = Profile(name: "Kim")  // stored as a dictionary
    ///
    /// let name = userDefaults["username", type: String.self]
    /// ```
    ///
    /// Assigning `nil` removes the key rather than storing a null. An assignment that cannot be
    /// encoded is ignored and the key keeps whatever it held — a write is all-or-nothing. A
    /// property-wrapper setter cannot throw, so the failure is silent; in debug it trips an
    /// assertion.
    ///
    /// Reading follows the defaults system's storage model rather than Swift's type identity:
    ///
    /// - The numeric types read one another. A property list keeps no `Float`/`Double`/`Int`
    ///   distinction, so refusing a `Double` when asked for a `Float` would reject a value the
    ///   defaults system never promised to keep apart. Reading a fractional value as an `Int`
    ///   truncates toward zero; one too large to represent — or a NaN — reads as `nil` rather
    ///   than trapping.
    /// - `Bool` reads what a property list can mean by it: `true`/`false`, or a number that is
    ///   exactly `0` or `1`. A stored `2` reads as `nil`, where `bool(forKey:)` would say `true`.
    /// - A value of an unrelated kind reads back as `nil`, letting a caller's default take over.
    ///   This is deliberately stricter than `integer(forKey:)` and its siblings, which flatten a
    ///   mismatch into `0`.
    /// - `String` and `URL` inherit the coercions of `string(forKey:)` and `url(forKey:)`. Reading a
    ///   stored `123` as a `String` therefore yields `"123"`, while the reverse yields `nil`.
    ///   Inheriting them costs `URL` away from Darwin: swift-corelibs-foundation's
    ///   `set(_:forKey:)` keeps only `url.path`, dropping the scheme and host before anything here
    ///   can see them, and its `url(forKey:)` reads whatever is left back as a file path. Only a
    ///   file URL survives the round trip there.
    /// - `Data` means stored data. A value this package encoded into a dictionary or a string does
    ///   not read back as the bytes it was built from.
    ///
    /// - Parameters:
    ///   - defaultName: The key to read and write.
    ///   - type: The type to read the value as. Inferred from the context of use where there is one.
    /// - Returns: The stored value, or `nil` when the key holds nothing readable as `T`.
    public subscript<T>(defaultName: String, type type: T.Type = T.self) -> T? where T: Codable {
        get {
            switch T.self {
            case is String.Type, is String?.Type:
                guard let string = string(forKey: defaultName) else { return nil }

                return string as? T
            case is Data.Type, is Data?.Type:
                guard let data = data(forKey: defaultName) else { return nil }

                return data as? T
            case is URL.Type, is URL?.Type:
                guard let url = url(forKey: defaultName) else { return nil }

                return url as? T
            case is Bool.Type, is Bool?.Type:
                // `<true/>` and a number that is exactly `0` or `1` both read; anything else is
                // missing. Spelled out rather than left to bridging for two reasons. `bool(forKey:)`
                // would call any non-zero number `true`, flattening a mismatch the way the doc above
                // says it will not. And the bridging that lets the `Bool` case catch a stored number
                // at all is Darwin's — swift-corelibs-foundation hands back a plain `Int`, `Double`
                // or `Float` — so the three numeric cases are what make this mean the same thing on
                // both. They are unreachable on Darwin, where `as Bool` has already matched.
                switch object(forKey: defaultName) {
                case let value as Bool:
                    return value as? T
                case let value as Int where value == 0 || value == 1:
                    return (value == 1) as? T
                case let value as Double where value == 0 || value == 1:
                    return (value == 1) as? T
                case let value as Float where value == 0 || value == 1:
                    return (value == 1) as? T
                default:
                    return nil
                }
            case is Int.Type, is Int?.Type:
                // Same reasoning as `Float` below: a property list keeps no `Int`/`real`
                // distinction, so rejecting a stored `<real>` outright would drop a value another
                // writer meant as a number. `Int(exactly:)` after truncating is what keeps that
                // from trapping on a NaN or on a magnitude `Int` cannot hold — both reachable by
                // anyone who can write the domain, `defaults(1)` included.
                //
                // The conversion is unwrapped before the cast rather than after. `Int(exactly:)`
                // yields an `Int?`, and casting *that* with `as? T` where `T` is itself `Int?`
                // succeeds on the failure — the outer optional comes back `.some(.none)`, which
                // reads as a value that is present and nil, so the `??` in
                // ``subscript(_:type:default:)`` never fires and the caller's default is lost.
                switch object(forKey: defaultName) {
                case let value as Int:
                    return value as? T
                case let value as Double:
                    guard let value = Int(exactly: value.rounded(.towardZero)) else { return nil }

                    return value as? T
                case let value as Float:
                    guard let value = Int(exactly: value.rounded(.towardZero)) else { return nil }

                    return value as? T
                default:
                    return nil
                }
            case is Float.Type, is Float?.Type:
                // A property list has no `Float`: every number lands as `<integer>` or `<real>`, so
                // whether a writer used `Float`, `Double` or `Int` is not preserved. Asking for an
                // exact `Float` back would reject a `Double` the moment it is not representable in
                // binary32 — `1.1` written by anyone else would silently fall back to the default.
                switch object(forKey: defaultName) {
                case let value as Float:
                    return value as? T
                case let value as Double:
                    return Float(value) as? T
                case let value as Int:
                    return Float(value) as? T
                default:
                    return nil
                }
            case is Double.Type, is Double?.Type:
                // Spelled out for the same reason. `Double` happens to read `Float` and `Int`
                // storage today, but only by way of `NSNumber` bridging; naming the Swift types
                // keeps that working if `object(forKey:)` ever hands back native ones.
                switch object(forKey: defaultName) {
                case let value as Double:
                    return value as? T
                case let value as Float:
                    return Double(value) as? T
                case let value as Int:
                    return Double(value) as? T
                default:
                    return nil
                }
            default:
                guard let value = object(forKey: defaultName) else { return nil }

                // Decoding gets first refusal, and the cast is the fallback rather than the other
                // way round. A property list has no null, so `PropertyListEncoder` writes one as
                // the string `$null` — and a stored `["a", "$null", "b"]` casts cleanly to
                // `[String?]`, handing that sentinel back as a value instead of the `nil` it stands
                // for. Only the decoder knows to read it back.
                //
                // Trying the cast afterwards is what keeps a string that genuinely is `$null`:
                // decoding one into a non-optional `String` fails, and the cast returns what was
                // stored. It also covers whatever the decoder has no way to build.
                //
                // No array wrapper on this side. The fragment restriction the setter works around
                // belongs to `PropertyListEncoder` alone; the decoder takes a top-level fragment,
                // which is what a `String`-backed enum was stored as.
                if
                    let data = try? PropertyListSerialization.data(
                        fromPropertyList: value,
                        format: .binary,
                        options: 0
                    ),
                    let decoded = try? PropertyListDecoder().decode(T.self, from: data)
                {
                    return decoded
                }

                return value as? T
            }
        }
        set {
            guard newValue.isNil == false, let newValue else {
                removeObject(forKey: defaultName)
                return
            }

            switch newValue {
            case let newValue as Bool:
                self.set(newValue, forKey: defaultName)
            case let newValue as Int:
                self.set(newValue, forKey: defaultName)
            case let newValue as Float:
                self.set(newValue, forKey: defaultName)
            case let newValue as Double:
                self.set(newValue, forKey: defaultName)
            case let newValue as URL:
                self.set(newValue, forKey: defaultName)
            case let newValue where PropertyListSerialization.propertyList(newValue as Any, isValidFor: .binary):
                self.set(newValue as Any, forKey: defaultName)
            default:
                do {
                    // `PropertyListEncoder` refuses a top-level fragment, and a `String`-backed enum
                    // encodes to exactly that, so the value rides inside a single-element array and
                    // is unwrapped again before it is stored. The array is transport and never
                    // storage: what lands under the key is the value's own property-list shape.
                    let data = try PropertyListEncoder().encode([newValue])
                    let list = try unsafe PropertyListSerialization.propertyList(from: data, format: nil)

                    guard let encoded = (list as? [Any])?.first else {
                        // Unreachable: what went in was a single-element array, so what comes back
                        // is one.
                        assertionFailure("encoding a single-element array did not produce an array")
                        return
                    }

                    self.set(encoded, forKey: defaultName)
                } catch {
                    // Interpolated, not localized: `EncodingError.localizedDescription` is a generic
                    // "operation couldn't be completed" and drops the `codingPath` that says which
                    // property refused to encode.
                    assertionFailure("\(error)")
                }
            }
        }
    }

    /// Accesses the `Codable` value stored under a key, falling back to a default while the key
    /// holds nothing.
    ///
    /// ```swift
    /// let launches = userDefaults["launchCount", default: 0]
    /// ```
    ///
    /// The default is evaluated only when it is needed, and it is never written back: reading a key
    /// does not create it. Storage and coercion are otherwise the same as for the subscript without
    /// a default.
    ///
    /// - Parameters:
    ///   - defaultName: The key to read and write.
    ///   - type: The type to read the value as. Inferred from `defaultValue` where there is one.
    ///   - defaultValue: The value to return while the key holds nothing readable as `T`.
    /// - Returns: The stored value, or `defaultValue` when the key holds nothing readable as `T`.
    public subscript<T>(
        defaultName: String,
        type type: T.Type = T.self,
        default defaultValue: @autoclosure () -> T
    ) -> T where T: Codable {
        get {
            self[defaultName, type: type] ?? defaultValue()
        }
        set {
            self[defaultName, type: type] = newValue
        }
    }
}
