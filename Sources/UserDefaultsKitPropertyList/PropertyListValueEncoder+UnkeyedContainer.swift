//
//  PropertyListValueEncoder+UnkeyedContainer.swift
//  UserDefaultsKitPropertyList
//

extension PropertyListValueEncoder {
    struct UnkeyedContainer: UnkeyedEncodingContainer {
        let encoder: _Encoder
        let array: PropertyListFuture.RefArray

        var codingPath: [any CodingKey] {
            encoder.codingPath
        }

        var count: Int {
            array.count
        }

        /// The key naming where the next element will go, for an error that has to say.
        private var nextKey: PropertyListCodingKey {
            .index(array.count)
        }

        // The one place a `nil` inside a property list has nowhere else to go. A keyed container
        // omits the key; an array cannot omit an element without moving every one after it, so the
        // position has to be held by something — and ``PropertyListValue/null`` is what Foundation
        // holds it with.
        mutating func encodeNil() throws {
            array.append(.null)
        }

        mutating func encode(_ value: Bool) throws {
            array.append(encoder.wrapBool(value))
        }

        mutating func encode(_ value: String) throws {
            array.append(encoder.wrapString(value))
        }

        mutating func encode(_ value: Double) throws {
            array.append(encoder.wrapFloatingPoint(value))
        }

        mutating func encode(_ value: Float) throws {
            array.append(encoder.wrapFloatingPoint(value))
        }

        mutating func encode(_ value: Int) throws {
            try array.append(encoder.wrapInteger(value, forKey: nextKey))
        }

        mutating func encode(_ value: Int8) throws {
            try array.append(encoder.wrapInteger(value, forKey: nextKey))
        }

        mutating func encode(_ value: Int16) throws {
            try array.append(encoder.wrapInteger(value, forKey: nextKey))
        }

        mutating func encode(_ value: Int32) throws {
            try array.append(encoder.wrapInteger(value, forKey: nextKey))
        }

        mutating func encode(_ value: Int64) throws {
            try array.append(encoder.wrapInteger(value, forKey: nextKey))
        }

        mutating func encode(_ value: UInt) throws {
            try array.append(encoder.wrapInteger(value, forKey: nextKey))
        }

        mutating func encode(_ value: UInt8) throws {
            try array.append(encoder.wrapInteger(value, forKey: nextKey))
        }

        mutating func encode(_ value: UInt16) throws {
            try array.append(encoder.wrapInteger(value, forKey: nextKey))
        }

        mutating func encode(_ value: UInt32) throws {
            try array.append(encoder.wrapInteger(value, forKey: nextKey))
        }

        mutating func encode(_ value: UInt64) throws {
            try array.append(encoder.wrapInteger(value, forKey: nextKey))
        }

        mutating func encode<T>(_ value: T) throws where T: Encodable {
            try array.append(encoder.wrap(value, forKey: nextKey))
        }

        mutating func nestedContainer<NestedKey>(
            keyedBy keyType: NestedKey.Type
        ) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
            let key = nextKey

            return KeyedEncodingContainer(
                KeyedContainer<NestedKey>(
                    encoder: encoder.encoder(forKey: key),
                    dictionary: array.appendDictionary()
                )
            )
        }

        mutating func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer {
            let key = nextKey

            return UnkeyedContainer(
                encoder: encoder.encoder(forKey: key),
                array: array.appendArray()
            )
        }

        mutating func superEncoder() -> any Encoder {
            _ReferencingEncoder(owner: encoder, at: array.count, wrapping: array)
        }
    }
}
