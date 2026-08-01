//
//  UserDefaultsKit.swift
//  UserDefaultsKit
//
//  Created by Kang Jaehong on 7/18/26.
//

// Which of these exist is decided in `Package.swift`, where each is a dependency only
// `.when(platforms:traits:)` says so. Asking `canImport` asks that same question directly instead
// of restating the answer: a target left out — wrong platform, or the trait turned off — is not
// importable, and this is false. Spelling the platforms out here once meant maintaining the list
// twice, and it had already drifted; `os(macCatalyst)` is not a condition Swift has, so that
// disjunct was always false and nothing said so.
@_exported import UserDefaultsKitCore

#if canImport(UserDefaultsKitCombine)
@_exported import UserDefaultsKitCombine
#endif

#if canImport(UserDefaultsKitSwiftUI)
@_exported import UserDefaultsKitSwiftUI
#endif
