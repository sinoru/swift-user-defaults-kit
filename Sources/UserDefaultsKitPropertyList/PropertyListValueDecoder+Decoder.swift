//
//  PropertyListValueDecoder+Decoder.swift
//  UserDefaultsKitPropertyList
//

import Foundation

extension PropertyListValueDecoder {
    /// One node of the tree, being read.
    ///
    /// A decoder is made per value that needs one, and points back at the one it came from rather
    /// than carrying a copy of the path to it. `codingPath` walks that chain, so the cost of
    /// keeping it is paid only by an error that reports it — which is the same trade
    /// `JSONEncoder`'s own encoder makes, and the reason nesting deeply does not turn into
    /// repeatedly copying a growing array.
    final class _Decoder {
        let value: PropertyListValue

        private let owner: _Decoder?
        private let codingKey: (any CodingKey)?

        init(value: PropertyListValue, owner: _Decoder?, codingKey: (any CodingKey)?) {
            self.value = value
            self.owner = owner
            self.codingKey = codingKey
        }

        /// A decoder for a value found inside this one.
        func decoder(for value: PropertyListValue, forKey key: any CodingKey) -> _Decoder {
            _Decoder(value: value, owner: self, codingKey: key)
        }
    }
}

// MARK: - Decoder

extension PropertyListValueDecoder._Decoder: Decoder {
    var codingPath: [any CodingKey] {
        var path = [any CodingKey]()
        var decoder = self as PropertyListValueDecoder._Decoder?

        while let current = decoder {
            if let key = current.codingKey {
                path.append(key)
            }

            decoder = current.owner
        }

        return path.reversed()
    }

    var userInfo: [CodingUserInfoKey: Any] {
        [:]
    }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
        guard !value.isNull else {
            throw DecodingError.valueNotFound(
                KeyedDecodingContainer<Key>.self,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Cannot get keyed decoding container -- found null value instead"
                )
            )
        }

        guard case .dictionary(let dictionary) = value else {
            throw typeMismatch([String: Any].self, found: value, forKey: nil)
        }

        return KeyedDecodingContainer(
            PropertyListValueDecoder.KeyedContainer(decoder: self, dictionary: dictionary)
        )
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        guard !value.isNull else {
            throw DecodingError.valueNotFound(
                UnkeyedDecodingContainer.self,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Cannot get unkeyed decoding container -- found null value instead"
                )
            )
        }

        guard case .array(let array) = value else {
            throw typeMismatch([Any].self, found: value, forKey: nil)
        }

        return PropertyListValueDecoder.UnkeyedContainer(decoder: self, array: array)
    }

    // Folded into the decoder rather than given a type of its own, the way Foundation's coders do
    // it: a single value container reads exactly the value the decoder is already sitting on.
    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        self
    }
}

// MARK: - Errors

extension PropertyListValueDecoder._Decoder {
    /// The path to this value, with the key of something inside it appended.
    ///
    /// Built only to report an error, which is why nothing keeps one of these around.
    private func codingPath(forKey key: (any CodingKey)?) -> [any CodingKey] {
        guard let key else { return codingPath }

        return codingPath + [key]
    }

    func typeMismatch<T>(
        _ type: T.Type,
        found value: PropertyListValue,
        forKey key: (any CodingKey)?
    ) -> DecodingError {
        DecodingError.typeMismatch(
            type,
            DecodingError.Context(
                codingPath: codingPath(forKey: key),
                debugDescription: "Expected to decode \(type) but found \(value.debugDataTypeDescription) instead."
            )
        )
    }

    func dataCorrupted(_ debugDescription: String, forKey key: (any CodingKey)?) -> DecodingError {
        DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: codingPath(forKey: key),
                debugDescription: debugDescription
            )
        )
    }

    /// Refuses a value standing in for `nil` where one is not allowed.
    ///
    /// Every unwrap starts here, because ``PropertyListValue/null`` is a string and would otherwise
    /// read as one.
    private func requireNotNull<T>(
        _ value: PropertyListValue,
        as type: T.Type,
        forKey key: (any CodingKey)?
    ) throws {
        guard value.isNull else { return }

        throw DecodingError.valueNotFound(
            type,
            DecodingError.Context(
                codingPath: codingPath(forKey: key),
                debugDescription: "Cannot get value of \(type) -- found null value instead"
            )
        )
    }
}

// MARK: - Unwrapping

extension PropertyListValueDecoder._Decoder {
    func unwrapBool(_ value: PropertyListValue, forKey key: (any CodingKey)? = nil) throws -> Bool {
        try requireNotNull(value, as: Bool.self, forKey: key)

        switch value {
        case .bool(let value):
            return value
        // A property list keeps no boolean/number distinction once a number is what got written, so
        // the two values a boolean can mean have to read from either spelling. What this will not
        // do is widen further: a stored `2` is a mismatch, where `bool(forKey:)` would call it
        // `true`.
        case .integer(let value) where value == 0 || value == 1:
            return value == 1
        case .unsignedInteger(let value) where value == 0 || value == 1:
            return value == 1
        case .real(let value) where value == 0 || value == 1:
            return value == 1
        default:
            throw typeMismatch(Bool.self, found: value, forKey: key)
        }
    }

    func unwrapInteger<T>(
        _ value: PropertyListValue,
        as type: T.Type,
        forKey key: (any CodingKey)? = nil
    ) throws -> T where T: FixedWidthInteger {
        try requireNotNull(value, as: type, forKey: key)

        let converted: T?

        switch value {
        case .integer(let value):
            converted = T(exactly: value)
        case .unsignedInteger(let value):
            converted = T(exactly: value)
        case .real(let value):
            // Truncated toward zero rather than refused. `<real>` is what `defaults(1)` writes for
            // any fractional literal, so rejecting one outright would drop a value another writer
            // meant as a number; this is also what `integer(forKey:)` does with the same storage.
            // `T(exactly:)` afterwards is what keeps a magnitude `T` cannot hold — or a NaN, which
            // rounds to itself — from trapping.
            converted = T(exactly: value.rounded(.towardZero))
        default:
            throw typeMismatch(type, found: value, forKey: key)
        }

        guard let converted else {
            throw dataCorrupted("Property list number <\(value)> does not fit in \(type).", forKey: key)
        }

        return converted
    }

    func unwrapFloatingPoint<T>(
        _ value: PropertyListValue,
        as type: T.Type,
        forKey key: (any CodingKey)? = nil
    ) throws -> T where T: BinaryFloatingPoint {
        try requireNotNull(value, as: type, forKey: key)

        switch value {
        // Converted rather than required to be exact. A property list has no `Float`, so demanding
        // one back would reject `1.1` — which has no binary32 form — and every other `Double`
        // another writer stored.
        case .real(let value):
            return T(value)
        case .integer(let value):
            return T(value)
        case .unsignedInteger(let value):
            return T(value)
        default:
            throw typeMismatch(type, found: value, forKey: key)
        }
    }

    func unwrapString(_ value: PropertyListValue, forKey key: (any CodingKey)? = nil) throws -> String {
        try requireNotNull(value, as: String.self, forKey: key)

        guard case .string(let value) = value else {
            throw typeMismatch(String.self, found: value, forKey: key)
        }

        return value
    }

    func unwrapDate(_ value: PropertyListValue, forKey key: (any CodingKey)? = nil) throws -> Date {
        try requireNotNull(value, as: Date.self, forKey: key)

        guard case .date(let value) = value else {
            throw typeMismatch(Date.self, found: value, forKey: key)
        }

        return value
    }

    func unwrapData(_ value: PropertyListValue, forKey key: (any CodingKey)? = nil) throws -> Data {
        try requireNotNull(value, as: Data.self, forKey: key)

        guard case .data(let value) = value else {
            throw typeMismatch(Data.self, found: value, forKey: key)
        }

        return value
    }

    /// Reads the value this decoder is sitting on as `type`.
    ///
    /// `Date` and `Data` are settled here rather than left to their own `Decodable` conformances,
    /// which would look for the numbers and bytes those encode to in a format that has neither. A
    /// property list stores both natively, and this is where that gets honoured.
    func unwrap<T>(as type: T.Type) throws -> T where T: Decodable {
        if type == Date.self {
            // Safe: the branch is only entered when `T` is `Date`.
            return try unwrapDate(value) as! T
        }

        if type == Data.self {
            // Safe: the branch is only entered when `T` is `Data`.
            return try unwrapData(value) as! T
        }

        return try T(from: self)
    }
}
