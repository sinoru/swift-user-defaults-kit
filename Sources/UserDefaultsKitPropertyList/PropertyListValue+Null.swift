//
//  PropertyListValue+Null.swift
//  UserDefaultsKitPropertyList
//

extension PropertyListValue {
    /// The value a `nil` is written as.
    ///
    /// A property list has no null, so an encoder that has to write one has to stand it up as
    /// something the format does have. Foundation picked the string `$null`, and this is the same
    /// string for the same reason a decoder has to know it: a value written by
    /// `PropertyListEncoder` has to read here, and one written here has to read in
    /// `PropertyListDecoder` and anything else that goes through it.
    ///
    /// The cost of any such sentinel is that a string which genuinely is `$null` cannot be told
    /// apart from a `nil`, and this one is no exception — Foundation's own scanners fold the two
    /// together while they are still reading bytes, so `PropertyListDecoder` cannot hand that string
    /// back at all. Choosing a different sentinel would move which string is unwritable, not remove
    /// the problem, and would give up reading anything Foundation wrote.
    static let null = PropertyListValue.string("$null")

    /// Whether this stands for a `nil` rather than for itself.
    var isNull: Bool {
        self == .null
    }
}
