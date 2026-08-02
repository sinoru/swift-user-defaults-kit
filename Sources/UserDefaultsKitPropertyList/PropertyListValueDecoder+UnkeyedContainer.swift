//
//  PropertyListValueDecoder+UnkeyedContainer.swift
//  UserDefaultsKitPropertyList
//

extension PropertyListValueDecoder {
    struct UnkeyedContainer: UnkeyedDecodingContainer {
        let decoder: _Decoder
        let array: [PropertyListValue]

        var currentIndex = 0

        var codingPath: [any CodingKey] {
            decoder.codingPath
        }

        var count: Int? {
            array.count
        }

        var isAtEnd: Bool {
            currentIndex >= array.count
        }

        /// The element at the current position, and the key that names where it is.
        ///
        /// Deliberately does not consume it. Advancing is the caller's last step, taken only once
        /// the value has been read successfully, because a `Decodable` is allowed to catch a
        /// mismatch and try the same element as another type — and a read that consumed on failure
        /// would hand the retry the element after it, or the end. Foundation's own containers
        /// advance in the same place for the same reason.
        private func current<T>(as type: T.Type) throws -> (value: PropertyListValue, key: any CodingKey) {
            guard !isAtEnd else {
                throw DecodingError.valueNotFound(
                    type,
                    DecodingError.Context(
                        codingPath: codingPath + [PropertyListCodingKey.index(currentIndex)],
                        debugDescription: "Unkeyed container is at end."
                    )
                )
            }

            return (array[currentIndex], PropertyListCodingKey.index(currentIndex))
        }

        /// Whether the next element stands for `nil`, consuming it only when it does.
        ///
        /// Leaving the index alone otherwise is what `UnkeyedDecodingContainer` asks for: a caller
        /// that gets `false` back goes on to read the same element as a value.
        mutating func decodeNil() throws -> Bool {
            guard !isAtEnd else {
                throw DecodingError.valueNotFound(
                    Any?.self,
                    DecodingError.Context(
                        codingPath: codingPath + [PropertyListCodingKey.index(currentIndex)],
                        debugDescription: "Unkeyed container is at end."
                    )
                )
            }

            guard array[currentIndex].isNull else { return false }

            currentIndex += 1

            return true
        }

        mutating func decode(_ type: Bool.Type) throws -> Bool {
            let (value, key) = try current(as: type)
            let decoded = try decoder.unwrapBool(value, forKey: key)
            currentIndex += 1

            return decoded
        }

        mutating func decode(_ type: String.Type) throws -> String {
            let (value, key) = try current(as: type)
            let decoded = try decoder.unwrapString(value, forKey: key)
            currentIndex += 1

            return decoded
        }

        mutating func decode(_ type: Double.Type) throws -> Double {
            let (value, key) = try current(as: type)
            let decoded = try decoder.unwrapFloatingPoint(value, as: type, forKey: key)
            currentIndex += 1

            return decoded
        }

        mutating func decode(_ type: Float.Type) throws -> Float {
            let (value, key) = try current(as: type)
            let decoded = try decoder.unwrapFloatingPoint(value, as: type, forKey: key)
            currentIndex += 1

            return decoded
        }

        mutating func decode(_ type: Int.Type) throws -> Int {
            let (value, key) = try current(as: type)
            let decoded = try decoder.unwrapInteger(value, as: type, forKey: key)
            currentIndex += 1

            return decoded
        }

        mutating func decode(_ type: Int8.Type) throws -> Int8 {
            let (value, key) = try current(as: type)
            let decoded = try decoder.unwrapInteger(value, as: type, forKey: key)
            currentIndex += 1

            return decoded
        }

        mutating func decode(_ type: Int16.Type) throws -> Int16 {
            let (value, key) = try current(as: type)
            let decoded = try decoder.unwrapInteger(value, as: type, forKey: key)
            currentIndex += 1

            return decoded
        }

        mutating func decode(_ type: Int32.Type) throws -> Int32 {
            let (value, key) = try current(as: type)
            let decoded = try decoder.unwrapInteger(value, as: type, forKey: key)
            currentIndex += 1

            return decoded
        }

        mutating func decode(_ type: Int64.Type) throws -> Int64 {
            let (value, key) = try current(as: type)
            let decoded = try decoder.unwrapInteger(value, as: type, forKey: key)
            currentIndex += 1

            return decoded
        }

        mutating func decode(_ type: UInt.Type) throws -> UInt {
            let (value, key) = try current(as: type)
            let decoded = try decoder.unwrapInteger(value, as: type, forKey: key)
            currentIndex += 1

            return decoded
        }

        mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
            let (value, key) = try current(as: type)
            let decoded = try decoder.unwrapInteger(value, as: type, forKey: key)
            currentIndex += 1

            return decoded
        }

        mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
            let (value, key) = try current(as: type)
            let decoded = try decoder.unwrapInteger(value, as: type, forKey: key)
            currentIndex += 1

            return decoded
        }

        mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
            let (value, key) = try current(as: type)
            let decoded = try decoder.unwrapInteger(value, as: type, forKey: key)
            currentIndex += 1

            return decoded
        }

        mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
            let (value, key) = try current(as: type)
            let decoded = try decoder.unwrapInteger(value, as: type, forKey: key)
            currentIndex += 1

            return decoded
        }

        mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
            let (value, key) = try current(as: type)
            let decoded = try decoder.decoder(for: value, forKey: key).unwrap(as: type)
            currentIndex += 1

            return decoded
        }

        mutating func nestedContainer<NestedKey>(
            keyedBy type: NestedKey.Type
        ) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
            let (value, key) = try current(as: KeyedDecodingContainer<NestedKey>.self)
            let container = try decoder.decoder(for: value, forKey: key).container(keyedBy: type)
            currentIndex += 1

            return container
        }

        mutating func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer {
            let (value, key) = try current(as: UnkeyedDecodingContainer.self)
            let container = try decoder.decoder(for: value, forKey: key).unkeyedContainer()
            currentIndex += 1

            return container
        }

        mutating func superDecoder() throws -> any Decoder {
            let (value, key) = try current(as: Decoder.self)
            currentIndex += 1

            return decoder.decoder(for: value, forKey: key)
        }
    }
}
