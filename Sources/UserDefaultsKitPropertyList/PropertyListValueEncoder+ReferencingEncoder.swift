//
//  PropertyListValueEncoder+ReferencingEncoder.swift
//  UserDefaultsKitPropertyList
//

extension PropertyListValueEncoder {
    /// The encoder `superEncoder()` hands out.
    ///
    /// A superclass is written through an encoder of its own, and nothing tells that encoder when
    /// the superclass is finished with it — so the only moment it is known to be done is when it is
    /// released. It keeps its own storage and writes it into the container it came from in `deinit`,
    /// which is how both of Foundation's coders solve the same problem.
    ///
    /// The position it writes to is taken when it is made, not when it is released. Anything the
    /// caller encodes in between lands after it, which is the order it asked for.
    final class _ReferencingEncoder: _Encoder {
        private enum Reference {
            case array(PropertyListFuture.RefArray, Int)
            case dictionary(PropertyListFuture.RefDictionary, String)
        }

        private let reference: Reference

        init(owner: _Encoder, key: any CodingKey, wrapping dictionary: PropertyListFuture.RefDictionary) {
            reference = .dictionary(dictionary, key.stringValue)

            super.init(owner: owner, codingKey: key)
        }

        init(owner: _Encoder, at index: Int, wrapping array: PropertyListFuture.RefArray) {
            reference = .array(array, index)

            super.init(owner: owner, codingKey: PropertyListCodingKey.index(index))
        }

        deinit {
            // A superclass that stored nothing asked for no container, and an empty dictionary is
            // what it reads back as — the same stand-in ``PropertyListValueEncoder/_Encoder/wrap(_:forKey:)``
            // uses, and what the decoder's `superDecoder()` invents when the key is absent.
            let value = takeValue() ?? .dictionary([:])

            switch reference {
            case .array(let array, let index):
                array.insert(value, at: index)
            case .dictionary(let dictionary, let key):
                dictionary.set(value, for: key)
            }
        }
    }
}
