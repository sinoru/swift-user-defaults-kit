//
//  PropertyListValueDecoder+KeyedContainer.swift
//  UserDefaultsKitPropertyList
//

extension PropertyListValueDecoder {
    struct KeyedContainer<Key>: KeyedDecodingContainerProtocol where Key: CodingKey {
        let decoder: _Decoder
        let dictionary: [String: PropertyListValue]

        var codingPath: [any CodingKey] {
            decoder.codingPath
        }

        var allKeys: [Key] {
            dictionary.keys.compactMap(Key.init(stringValue:))
        }

        func contains(_ key: Key) -> Bool {
            dictionary[key.stringValue] != nil
        }

        /// The value under a key, or the error that says there is none.
        ///
        /// A missing key and a key holding ``PropertyListValue/null`` are different things, and only
        /// the first is reported here — a synthesized `Decodable` reaches `decodeNil(forKey:)` for
        /// the second.
        private func value(forKey key: Key) throws -> PropertyListValue {
            guard let value = dictionary[key.stringValue] else {
                throw DecodingError.keyNotFound(
                    key,
                    DecodingError.Context(
                        codingPath: codingPath,
                        debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."
                    )
                )
            }

            return value
        }

        func decodeNil(forKey key: Key) throws -> Bool {
            try value(forKey: key).isNull
        }

        func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
            try decoder.unwrapBool(value(forKey: key), forKey: key)
        }

        func decode(_ type: String.Type, forKey key: Key) throws -> String {
            try decoder.unwrapString(value(forKey: key), forKey: key)
        }

        func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
            try decoder.unwrapFloatingPoint(value(forKey: key), as: type, forKey: key)
        }

        func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
            try decoder.unwrapFloatingPoint(value(forKey: key), as: type, forKey: key)
        }

        func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
            try decoder.unwrapInteger(value(forKey: key), as: type, forKey: key)
        }

        func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
            try decoder.unwrapInteger(value(forKey: key), as: type, forKey: key)
        }

        func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
            try decoder.unwrapInteger(value(forKey: key), as: type, forKey: key)
        }

        func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
            try decoder.unwrapInteger(value(forKey: key), as: type, forKey: key)
        }

        func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
            try decoder.unwrapInteger(value(forKey: key), as: type, forKey: key)
        }

        func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
            try decoder.unwrapInteger(value(forKey: key), as: type, forKey: key)
        }

        func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
            try decoder.unwrapInteger(value(forKey: key), as: type, forKey: key)
        }

        func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
            try decoder.unwrapInteger(value(forKey: key), as: type, forKey: key)
        }

        func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
            try decoder.unwrapInteger(value(forKey: key), as: type, forKey: key)
        }

        func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
            try decoder.unwrapInteger(value(forKey: key), as: type, forKey: key)
        }

        func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
            try decoder.decoder(for: value(forKey: key), forKey: key).unwrap(as: type)
        }

        func nestedContainer<NestedKey>(
            keyedBy type: NestedKey.Type,
            forKey key: Key
        ) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
            try decoder.decoder(for: value(forKey: key), forKey: key).container(keyedBy: type)
        }

        func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
            try decoder.decoder(for: value(forKey: key), forKey: key).unkeyedContainer()
        }

        /// The decoder a subclass reads itself from.
        ///
        /// A class that inherits `Decodable` encodes its superclass's half under `super` unless it
        /// says otherwise. An absent key stands in as ``PropertyListValue/null`` rather than as an
        /// empty dictionary: a superclass that stores nothing asks for no container and so never
        /// looks at it, while one that does ask gets the same `valueNotFound` Foundation gives it.
        /// Standing in with an empty dictionary instead would answer that ask by inventing a
        /// superclass with every property missing, which is a decode that should have failed.
        func superDecoder() throws -> any Decoder {
            try superDecoder(forKey: PropertyListCodingKey.super)
        }

        func superDecoder(forKey key: Key) throws -> any Decoder {
            try superDecoder(forKey: key as any CodingKey)
        }

        private func superDecoder(forKey key: any CodingKey) throws -> any Decoder {
            decoder.decoder(for: dictionary[key.stringValue] ?? .null, forKey: key)
        }
    }
}
