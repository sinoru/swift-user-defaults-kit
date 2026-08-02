//
//  NilEncodingValue.swift
//  UserDefaultsKitTestSupport
//

/// A value that is not optional and still writes itself as `nil`.
///
/// `Codable` lets a type call `encodeNil()` and answer `decodeNil()` for itself, which is not the
/// same thing as being an `Optional`: the nil is part of what the type means rather than a statement
/// that there is no value. Nothing reading it can tell the two apart without asking the type, which
/// is what makes this worth having a fixture for.
///
/// Named for what it does rather than for something it could plausibly model. It exists to be
/// encoded and decoded, and a reader meeting it in a test should not have to work out which of its
/// properties the test is about.
package enum NilEncodingValue: Codable, Equatable, Sendable {
    case absent
    case present(Int)

    package init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .absent
        } else {
            self = .present(try container.decode(Int.self))
        }
    }

    package func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .absent:
            try container.encodeNil()
        case .present(let value):
            try container.encode(value)
        }
    }
}
