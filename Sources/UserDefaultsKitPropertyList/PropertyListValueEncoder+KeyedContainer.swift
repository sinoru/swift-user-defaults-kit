//
//  PropertyListValueEncoder+KeyedContainer.swift
//  UserDefaultsKitPropertyList
//

extension PropertyListValueEncoder {
    struct KeyedContainer<Key>: KeyedEncodingContainerProtocol where Key: CodingKey {
        let encoder: _Encoder
        let dictionary: PropertyListFuture.RefDictionary

        var codingPath: [any CodingKey] {
            encoder.codingPath
        }

        // A synthesized `Encodable` reaches this only for a property it was told to write even when
        // nil — `encodeIfPresent` omits the key instead, which is what a property list would rather
        // have. What lands here is a caller who asked for the sentinel on purpose.
        mutating func encodeNil(forKey key: Key) throws {
            dictionary.set(.null, for: key.stringValue)
        }

        mutating func encode(_ value: Bool, forKey key: Key) throws {
            dictionary.set(encoder.wrapBool(value), for: key.stringValue)
        }

        mutating func encode(_ value: String, forKey key: Key) throws {
            dictionary.set(encoder.wrapString(value), for: key.stringValue)
        }

        mutating func encode(_ value: Double, forKey key: Key) throws {
            dictionary.set(encoder.wrapFloatingPoint(value), for: key.stringValue)
        }

        mutating func encode(_ value: Float, forKey key: Key) throws {
            dictionary.set(encoder.wrapFloatingPoint(value), for: key.stringValue)
        }

        mutating func encode(_ value: Int, forKey key: Key) throws {
            try dictionary.set(encoder.wrapInteger(value, forKey: key), for: key.stringValue)
        }

        mutating func encode(_ value: Int8, forKey key: Key) throws {
            try dictionary.set(encoder.wrapInteger(value, forKey: key), for: key.stringValue)
        }

        mutating func encode(_ value: Int16, forKey key: Key) throws {
            try dictionary.set(encoder.wrapInteger(value, forKey: key), for: key.stringValue)
        }

        mutating func encode(_ value: Int32, forKey key: Key) throws {
            try dictionary.set(encoder.wrapInteger(value, forKey: key), for: key.stringValue)
        }

        mutating func encode(_ value: Int64, forKey key: Key) throws {
            try dictionary.set(encoder.wrapInteger(value, forKey: key), for: key.stringValue)
        }

        mutating func encode(_ value: UInt, forKey key: Key) throws {
            try dictionary.set(encoder.wrapInteger(value, forKey: key), for: key.stringValue)
        }

        mutating func encode(_ value: UInt8, forKey key: Key) throws {
            try dictionary.set(encoder.wrapInteger(value, forKey: key), for: key.stringValue)
        }

        mutating func encode(_ value: UInt16, forKey key: Key) throws {
            try dictionary.set(encoder.wrapInteger(value, forKey: key), for: key.stringValue)
        }

        mutating func encode(_ value: UInt32, forKey key: Key) throws {
            try dictionary.set(encoder.wrapInteger(value, forKey: key), for: key.stringValue)
        }

        mutating func encode(_ value: UInt64, forKey key: Key) throws {
            try dictionary.set(encoder.wrapInteger(value, forKey: key), for: key.stringValue)
        }

        mutating func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
            try dictionary.set(encoder.wrap(value, forKey: key), for: key.stringValue)
        }

        mutating func nestedContainer<NestedKey>(
            keyedBy keyType: NestedKey.Type,
            forKey key: Key
        ) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
            KeyedEncodingContainer(
                KeyedContainer<NestedKey>(
                    encoder: encoder.encoder(forKey: key),
                    dictionary: dictionary.setDictionary(for: key.stringValue)
                )
            )
        }

        mutating func nestedUnkeyedContainer(forKey key: Key) -> any UnkeyedEncodingContainer {
            UnkeyedContainer(
                encoder: encoder.encoder(forKey: key),
                array: dictionary.setArray(for: key.stringValue)
            )
        }

        mutating func superEncoder() -> any Encoder {
            _ReferencingEncoder(
                owner: encoder,
                key: PropertyListCodingKey.super,
                wrapping: dictionary
            )
        }

        mutating func superEncoder(forKey key: Key) -> any Encoder {
            _ReferencingEncoder(owner: encoder, key: key, wrapping: dictionary)
        }
    }
}
