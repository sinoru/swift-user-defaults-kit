//
//  PropertyListValue+Descriptions.swift
//  UserDefaultsKitPropertyList
//

extension PropertyListValue {
    /// How this value is named in a `DecodingError` that reports finding it.
    ///
    /// Reads into the sentence `Expected to decode Int but found a string instead.`, which is the
    /// shape Foundation's own coders use.
    var debugDataTypeDescription: String {
        switch self {
        case .dictionary:
            "a dictionary"
        case .array:
            "an array"
        case .string:
            "a string"
        case .data:
            "a data value"
        case .date:
            "a date"
        case .bool:
            "a boolean"
        case .integer, .unsignedInteger:
            "an integer"
        case .real:
            "a real number"
        }
    }
}
