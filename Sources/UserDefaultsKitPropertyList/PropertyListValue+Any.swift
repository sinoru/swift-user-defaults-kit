//
//  PropertyListValue+Any.swift
//  UserDefaultsKitPropertyList
//

import Foundation

extension PropertyListValue {
    /// Reads the `Any` that `UserDefaults.object(forKey:)` and `PropertyListSerialization` deal in.
    ///
    /// This is the one place that knows what those hand back, and it differs by platform: Darwin
    /// returns Objective-C objects, and swift-corelibs-foundation returns Swift ones. Keeping the
    /// difference here is what lets everything above it read a `PropertyListValue` and stop caring.
    ///
    /// - Parameter value: A property list value. Anything else — a type the format cannot hold, or a
    ///   collection with one nested somewhere inside it — is not one, and yields `nil`.
    package init?(propertyList value: Any) {
        switch value {
        case let value as String:
            self = .string(value)
        case let value as Data:
            self = .data(value)
        case let value as Date:
            self = .date(value)
        case let value as [Any]:
            var array = [PropertyListValue]()
            array.reserveCapacity(value.count)

            for element in value {
                guard let element = PropertyListValue(propertyList: element) else { return nil }

                array.append(element)
            }

            self = .array(array)
        case let value as [String: Any]:
            var dictionary = [String: PropertyListValue](minimumCapacity: value.count)

            for (key, element) in value {
                guard let element = PropertyListValue(propertyList: element) else { return nil }

                dictionary[key] = element
            }

            self = .dictionary(dictionary)
        default:
            guard let value = PropertyListValue(number: value) else { return nil }

            self = value
        }
    }

    /// Reads the numbers, which are where the two platforms disagree.
    private init?(number value: Any) {
#if canImport(ObjectiveC)
        // Darwin hands every number back as an `NSNumber`, booleans included, and
        // `NSNumber(value: 1) as? Bool` succeeds — so a ladder of Swift casts cannot tell `<true/>`
        // from `<integer>1</integer>`. The CoreFoundation type ID is what can. A Swift `Bool`
        // arriving here rather than out of the defaults system bridges to a boolean `NSNumber`, so
        // it takes the same branch.
        guard let value = value as? NSNumber else { return nil }

        if CFGetTypeID(value) == CFBooleanGetTypeID() {
            self = .bool(value.boolValue)
            return
        }

        // Asked before the integer casts rather than after, for the same reason. `NSNumber`
        // bridging succeeds whenever the value is exactly representable, so a stored `<real>2</real>`
        // would otherwise pass `as? Int64` and arrive as an integer.
        if CFNumberIsFloatType(value as CFNumber) {
            self = .real(value.doubleValue)
            return
        }

        // That same exactness check is what makes this ordering safe: a value above `Int64.max`
        // fails the first cast and reaches the second rather than coming back truncated.
        if let value = value as? Int64 {
            self = .integer(value)
        } else if let value = value as? UInt64 {
            self = .unsignedInteger(value)
        } else {
            return nil
        }
#else
        // swift-corelibs-foundation unboxes `NSNumber` before returning, so a number arrives as
        // whichever Swift type `NSNumber._swiftValueOfOptimalType` chose for it: `Bool` for the two
        // `CFBoolean` singletons, `Int` for a signed value below `Int.max`, `Int64` for `Int.max`
        // itself, `UInt64` for one that needed 128 bits but fit in the low half, and `Float` or
        // `Double` for the reals. Matching the two existentials rather than each of those spellings
        // is what keeps this from depending on that list staying as it is.
        switch value {
        case let value as Bool:
            self = .bool(value)
        case let value as any FixedWidthInteger:
            if let value = Int64(exactly: value) {
                self = .integer(value)
            } else if let value = UInt64(exactly: value) {
                self = .unsignedInteger(value)
            } else {
                // Wider than either carrier. Unreachable through the spellings above — a value
                // needing the high half of 128 bits comes back as `CFSInt128Struct`, which is
                // private to swift-corelibs-foundation and so matches neither existential, and
                // falls out of the `default` below instead. Kept because being wider than `UInt64`
                // is the reason to refuse either way.
                return nil
            }
        case let value as any BinaryFloatingPoint:
            self = .real(Double(value))
        default:
            return nil
        }
#endif
    }

    /// The `Any` to hand `UserDefaults.set(_:forKey:)`.
    ///
    /// Both platforms take the Swift types this produces: Darwin bridges them, and
    /// swift-corelibs-foundation's own `set(_:forKey:)` accepts each one by name.
    package var propertyList: Any {
        switch self {
        case .dictionary(let value):
            return value.mapValues(\.propertyList)
        case .array(let value):
            return value.map(\.propertyList)
        case .string(let value):
            return value
        case .data(let value):
            return value
        case .date(let value):
            return value
        case .bool(let value):
            return value
        case .integer(let value):
            // Narrowed to `Int` where it fits, which is every value but the far ends of the range.
            // Both spellings store the same number, and on Darwin both bridge to the same
            // `NSNumber`; the difference shows on Linux, where `Int64` is a separate type and
            // anyone reading `object(forKey:)` with an `as? Int` of their own would miss it.
            if let value = Int(exactly: value) {
                return value
            }

            return value
        case .unsignedInteger(let value):
            return value
        case .real(let value):
            return value
        }
    }
}
