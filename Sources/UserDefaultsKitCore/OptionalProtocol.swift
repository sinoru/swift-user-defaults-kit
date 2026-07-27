//
//  OptionalProtocol.swift
//  UserDefaultsKit
//
//  Created by Kang Jaehong on 7/12/26.
//

protocol OptionalProtocol {
    var isNil: Bool { get }
}

extension Optional: OptionalProtocol {
    var isNil: Bool {
        switch self {
        case .none:
            return true
        case .some(let wrapped as OptionalProtocol):
            return wrapped.isNil
        case .some(_):
            return false
        }
    }
}
