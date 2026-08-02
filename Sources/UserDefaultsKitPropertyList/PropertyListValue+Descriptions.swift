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

    /// The number as it was stored, for an error that has to name the value rather than its kind.
    ///
    /// Kept apart from the unwrap that reports it so it is built only when one fails. Interpolating
    /// the value itself there would name the case instead — `<real(1e+300)>` where the reader is
    /// looking for `<1e+300>`.
    var numberDescription: String {
        switch self {
        case .integer(let value):
            "\(value)"
        case .unsignedInteger(let value):
            "\(value)"
        case .real(let value):
            "\(value)"
        // Unreachable from the only caller, which has already refused anything else as a mismatch.
        case .dictionary, .array, .string, .data, .date, .bool:
            debugDataTypeDescription
        }
    }
}
