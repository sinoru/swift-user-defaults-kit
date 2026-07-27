//
//  UserDefault+Binding.swift
//  UserDefaultsKitSwiftUI
//

#if canImport(SwiftUI)
import SwiftUI
import UserDefaultsKitCore

extension UserDefault {
    /// A binding to the stored value, for the SwiftUI controls that take one.
    ///
    /// ```swift
    /// @UserDefault("username") var username = "anonymous"
    ///
    /// TextField("Name", text: $username.binding)
    /// ```
    ///
    /// This binding only reads and writes — it does not refresh the view on its own. For a value that
    /// also updates the view when it changes, declare it with ``UserDefaultStorage``, whose `$value` is
    /// a binding too.
    public var binding: Binding<Value> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
}
#endif
