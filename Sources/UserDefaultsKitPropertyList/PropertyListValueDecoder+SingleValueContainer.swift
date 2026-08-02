//
//  PropertyListValueDecoder+SingleValueContainer.swift
//  UserDefaultsKitPropertyList
//

extension PropertyListValueDecoder._Decoder: SingleValueDecodingContainer {
    func decodeNil() -> Bool {
        value.isNull
    }

    func decode(_ type: Bool.Type) throws -> Bool {
        try unwrapBool(value)
    }

    func decode(_ type: String.Type) throws -> String {
        try unwrapString(value)
    }

    func decode(_ type: Double.Type) throws -> Double {
        try unwrapFloatingPoint(value, as: type)
    }

    func decode(_ type: Float.Type) throws -> Float {
        try unwrapFloatingPoint(value, as: type)
    }

    func decode(_ type: Int.Type) throws -> Int {
        try unwrapInteger(value, as: type)
    }

    func decode(_ type: Int8.Type) throws -> Int8 {
        try unwrapInteger(value, as: type)
    }

    func decode(_ type: Int16.Type) throws -> Int16 {
        try unwrapInteger(value, as: type)
    }

    func decode(_ type: Int32.Type) throws -> Int32 {
        try unwrapInteger(value, as: type)
    }

    func decode(_ type: Int64.Type) throws -> Int64 {
        try unwrapInteger(value, as: type)
    }

    func decode(_ type: UInt.Type) throws -> UInt {
        try unwrapInteger(value, as: type)
    }

    func decode(_ type: UInt8.Type) throws -> UInt8 {
        try unwrapInteger(value, as: type)
    }

    func decode(_ type: UInt16.Type) throws -> UInt16 {
        try unwrapInteger(value, as: type)
    }

    func decode(_ type: UInt32.Type) throws -> UInt32 {
        try unwrapInteger(value, as: type)
    }

    func decode(_ type: UInt64.Type) throws -> UInt64 {
        try unwrapInteger(value, as: type)
    }

    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        try unwrap(as: type)
    }
}
