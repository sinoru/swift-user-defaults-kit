//
//  PropertyListValueEncoder+SingleValueContainer.swift
//  UserDefaultsKitPropertyList
//

extension PropertyListValueEncoder._Encoder: SingleValueEncodingContainer {
    /// Fills the one slot this node has, and refuses to fill it twice.
    ///
    /// `Encoder` lets a value ask for exactly one container and write into it once. Silently
    /// dropping the first value would turn that mistake into a wrong property list rather than a
    /// stopped program.
    private func store(_ value: PropertyListValue) {
        precondition(
            singleValue == nil && array == nil && dictionary == nil,
            "Attempt to encode a value through a single value container where one has already been encoded."
        )

        singleValue = value
    }

    func encodeNil() throws {
        store(.null)
    }

    func encode(_ value: Bool) throws {
        store(wrapBool(value))
    }

    func encode(_ value: String) throws {
        store(wrapString(value))
    }

    func encode(_ value: Double) throws {
        store(wrapFloatingPoint(value))
    }

    func encode(_ value: Float) throws {
        store(wrapFloatingPoint(value))
    }

    func encode(_ value: Int) throws {
        try store(wrapInteger(value))
    }

    func encode(_ value: Int8) throws {
        try store(wrapInteger(value))
    }

    func encode(_ value: Int16) throws {
        try store(wrapInteger(value))
    }

    func encode(_ value: Int32) throws {
        try store(wrapInteger(value))
    }

    func encode(_ value: Int64) throws {
        try store(wrapInteger(value))
    }

    func encode(_ value: UInt) throws {
        try store(wrapInteger(value))
    }

    func encode(_ value: UInt8) throws {
        try store(wrapInteger(value))
    }

    func encode(_ value: UInt16) throws {
        try store(wrapInteger(value))
    }

    func encode(_ value: UInt32) throws {
        try store(wrapInteger(value))
    }

    func encode(_ value: UInt64) throws {
        try store(wrapInteger(value))
    }

    func encode<T>(_ value: T) throws where T: Encodable {
        try store(wrap(value, forKey: nil))
    }
}
