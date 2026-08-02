//
//  UserDefaults+Codable.swift
//  UserDefaultsKit
//
//  Created by Kang Jaehong on 7/12/26.
//

import Foundation

// `internal` rather than `package`, which is as far as the module's own access level would allow.
// Nothing here puts a `PropertyListValue` in a signature — the subscript is generic over `Codable`
// and the tree only exists inside these bodies — so the tighter spelling is the accurate one, and it
// keeps the module from reaching a consumer through this one.
internal import UserDefaultsKitPropertyList

extension UserDefaults {
    /// Accesses the `Codable` value stored under a key.
    ///
    /// A value that has a property-list form is stored in it, and anything else is *encoded into*
    /// one: a struct lands as a dictionary, a `String`-backed enum as a string. Nothing this
    /// package encodes becomes an opaque archive, so a type Foundation had no way to write stays as
    /// legible to `defaults(1)`, to `@AppStorage`, and to any other process sharing the domain as
    /// one it did — which is the whole point.
    ///
    /// One kind of value is not encoded here and so is not covered by that: a top-level `URL` is
    /// handed to `set(_:forKey:)`, which stores what it stores. On Darwin that is a path for a file
    /// URL and a keyed archive for anything else — the one opaque thing a key written through this
    /// can hold. Writing it any other way would mean `url(forKey:)` and `@AppStorage` could no
    /// longer read it, which is a worse trade than the blob. A `URL` *inside* a value takes the
    /// ordinary path and lands as a dictionary on both platforms.
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
    /// - The numeric types read one another, at any depth. A property list keeps no
    ///   `Float`/`Double`/`Int` distinction, so refusing a `Double` when asked for a `Float` would
    ///   reject a value the defaults system never promised to keep apart — and refusing it inside
    ///   an array while allowing it at the top would be a rule that is true only where it is easy.
    ///   Reading a fractional value as an `Int` truncates toward zero; one too large to represent —
    ///   or a NaN — reads as `nil` rather than trapping.
    /// - `Bool` reads what a property list can mean by it: `true`/`false`, or a number that is
    ///   exactly `0` or `1`. A stored `2` reads as `nil`, where `bool(forKey:)` would say `true`.
    ///   This does not run the other way: a stored `<true/>` asked for as a number reads as `nil`,
    ///   because a property list does keep those apart and `defaults(1)` prints them differently.
    /// - A value of an unrelated kind reads back as `nil`, letting a caller's default take over.
    ///   This is deliberately stricter than `integer(forKey:)` and its siblings, which flatten a
    ///   mismatch into `0`.
    /// - `String` and `URL` inherit the coercions of `string(forKey:)` and `url(forKey:)`, and only
    ///   at the top: unlike the numeric rules above, these are Foundation's accessors rather than
    ///   this package's, and there is no accessor to inherit from inside a collection. Reading a
    ///   stored `123` as a `String` therefore yields `"123"` while a stored `[123]` read as
    ///   `[String]` yields `nil`, and a top-level `URL` and one inside a value are stored in
    ///   different shapes that do not read each other.
    ///   Inheriting them costs `URL` away from Darwin: swift-corelibs-foundation's
    ///   `set(_:forKey:)` keeps only `url.path`, dropping the scheme and host before anything here
    ///   can see them, and its `url(forKey:)` reads whatever is left back as a file path. Only a
    ///   file URL survives the round trip there — `https://swift.org/blog` comes back as
    ///   `file:///blog`. A `URL` inside a value loses nothing on either platform, since that one is
    ///   encoded rather than handed over.
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
            default:
                guard let value = object(forKey: defaultName) else { return nil }

                // Decoding gets first refusal, and the cast is the fallback rather than the other
                // way round. A property list has no null, so a `nil` inside one is written as the
                // string `$null` — and a stored `["a", "$null", "b"]` casts cleanly to `[String?]`,
                // handing that sentinel back as a value instead of the `nil` it stands for. Only
                // the decoder knows to read it back.
                //
                // Trying the cast afterwards is what keeps a string that genuinely is `$null`:
                // decoding one into a non-optional `String` fails, and the cast returns what was
                // stored. It also covers whatever the decoder has no way to build — including a
                // stored value too wide for `PropertyListValue` to carry.
                //
                // The stored object is walked once here. Reaching `PropertyListDecoder` meant
                // serializing it to `Data` and scanning that back first, and meant living with what
                // that decoder will not do: it refuses a top-level fragment, which is what a
                // `String`-backed enum is stored as, and it applies its numeric coercions only at
                // the top rather than at every depth.
                guard let propertyList = PropertyListValue(propertyList: value) else {
                    // Nothing the value model can carry, which takes a 128-bit stored number to
                    // reach. The cast is unlikely to do better — on Linux such a value arrives as a
                    // type private to swift-corelibs-foundation, so it answers nothing — but it
                    // costs a line and is the only thing left to try.
                    return value as? T
                }

                // A sentinel standing where the whole value should be says what an absent key says —
                // but only to a `T` that has nothing else to make of it. A type that handles
                // `decodeNil()` itself means something concrete by it, and has to be left to say so;
                // only `Optional` decodes it to a `nil` that would then come back as `.some(.none)`,
                // which the `??` in ``subscript(_:type:default:)`` takes for a value and never
                // replaces, losing the caller's default.
                //
                // The two tests are in this order because of what they cost. Asking whether the
                // stored value is the sentinel is one comparison against something already in hand;
                // asking whether `T` is optional is a conformance lookup, and putting it second
                // means only a stored sentinel ever pays for it. Asking the *decoded result*
                // instead — which is what this did first — put a dynamic cast to an existential on
                // every read of every type.
                if propertyList.isNull, T.self is any OptionalProtocol.Type {
                    return nil
                }

                do {
                    return try PropertyListValueDecoder().decode(T.self, from: propertyList)
                } catch DecodingError.valueNotFound {
                    // Where the stored object can answer better than the decoder, which now means
                    // a sentinel found *inside* a value rather than as the whole of one: a stored
                    // `["a", "$null", "b"]` read as `[String]` is three strings to the cast and a
                    // missing element to the decoder, and the cast is the one that keeps a string
                    // which genuinely is `$null`. The guard above already answered the whole-value
                    // case.
                    //
                    // `valueNotFound` also covers an unkeyed container run off its end, which the
                    // cast has nothing better to say about: it fails too, and the result is the
                    // `nil` the other branch would have returned.
                    return value as? T
                } catch {
                    // Every other refusal is a real one, and casting would put back exactly what
                    // the decoder just turned down. It is also where the two platforms would stop
                    // agreeing: `NSNumber` bridging answers `as? Int` for a stored `<true/>` with
                    // `1`, while swift-corelibs-foundation hands back a `Bool` that matches
                    // nothing. A property list tells those two apart, so this does too.
                    return nil
                }
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
                    // Built once, rather than encoded to `Data` and parsed back to get at the
                    // objects inside. It also takes the value as it is: `PropertyListEncoder`
                    // refuses a top-level fragment, and a `String`-backed enum encodes to exactly
                    // that, so reaching it meant sending the value through a single-element array
                    // and unwrapping the result again.
                    let encoded = try PropertyListValueEncoder().encode(newValue)

                    self.set(encoded.propertyList, forKey: defaultName)
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
