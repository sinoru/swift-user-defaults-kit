# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.1] - 2026-08-03

### Added

- `UserDefault`, a property wrapper reading and writing any `Codable` value in
  `UserDefaults`. Unlike `@AppStorage`, `Value` is not limited to the
  property-list types — a struct, an enum, or anything else that conforms.
  Nothing is cached, so a read can never be stale, and nothing is written back
  on a read, so a key stays absent from the database until something assigns to
  it. The wrapper is `Sendable` and a suite can be passed to share a value with
  an app extension or another app-group member.
- Subscripts on `UserDefaults` taking a `Codable` type, with and without a
  default: `defaults["username", type: String.self]` and
  `defaults["launchCount", default: 0]`. The wrapper is a thin layer over these
  and either can be used on its own.
- Property-list storage rather than archives. A value with no property-list
  form of its own is encoded *into* one — a struct as a dictionary, a
  `String`-backed enum as a string — rather than being handed to
  `NSKeyedArchiver` and stored as bytes. That is what keeps a value written
  through this package legible to `defaults(1)`, to `@AppStorage`, and to any
  other process sharing the domain. A property left `nil` is left out rather
  than written as a null.
- Writes that are all-or-nothing. Assigning `nil` to a key removes it rather
  than storing a null, and a value that fails to encode is ignored — the key
  keeps what it held rather than being left half-written. A property-wrapper
  setter cannot throw, so that failure is silent; in debug it trips an
  assertion carrying the `codingPath` that says which property refused.
- Reading rules that follow the defaults system's storage model rather than
  Swift's type identity, and that hold at every depth rather than only at the
  top, but for the one pair Foundation owns. The numeric types read one another,
  since a property list keeps no `Float`/`Double`/`Int` distinction to enforce;
  a fractional value read as an integer truncates toward zero, and one too large
  to represent reads as `nil` rather than trapping. `Bool` reads `true`/`false`
  or a number that is exactly `0` or `1`, and not the reverse — a stored
  `<true/>` asked for as a number reads as `nil`, because a property list does
  tell those apart. A value of an unrelated kind reads as `nil` and the caller's
  default takes over, which is deliberately stricter than `integer(forKey:)` and
  its siblings flattening a mismatch into `0`. The pair that does not reach past
  the top is `String` and `URL`, which inherit the coercions of
  `string(forKey:)` and `url(forKey:)` — Foundation's accessors rather than this
  package's, with no accessor to inherit from inside a collection. A stored
  `123` read as a `String` yields `"123"`, while a stored `[123]` read as
  `[String]` yields `nil`.
- A top-level `URL` handed to Foundation as it is rather than encoded, so that
  `url(forKey:)` and `@AppStorage` can still read it. On Darwin that means a
  non-file URL is stored as a keyed archive — the one opaque thing a key written
  through this package can hold — and on swift-corelibs-foundation it means only
  a file URL survives the round trip at all, since `set(_:forKey:)` there keeps
  `url.path` and drops the scheme and host before anything here can see them. A
  `URL` *inside* a value takes the ordinary path and loses nothing on either
  platform.
- A property-list encoder and decoder that work on a value tree directly rather
  than on `Data`. Foundation exposes no coder that takes a property list
  object — the one it has internally is compiled into the Darwin framework
  alone — so reading meant serializing the stored object and scanning it back
  first, and writing meant the reverse. Neither hop remains, and with them go
  `PropertyListEncoder`'s refusal of a top-level fragment, which a
  `String`-backed enum is, and its numeric coercions applying only at the top.
  Neither coder is part of the public surface: the target is left out of
  `products` and everything in it is `package` rather than `public`. What it
  supports is the subscripts above.
- Change observation on Apple platforms, in three shapes over one backend:
  `publisher` (Combine), `values` (`AsyncStream`), and `UserDefaultStorage`, a
  SwiftUI `DynamicProperty` whose projected value is a `Binding` and whose view
  refreshes when the value changes — including when the change was made by
  another process sharing the suite. Each subscription, stream, and view owns
  its own observation and unregisters when it goes away, so none of this is
  process-lifetime state. `UserDefault.binding` is the non-refreshing binding
  for a value declared outside a view.
- A fallback for the keys Key-Value Observing cannot take. KVO reads a key as a
  *key path*, so an empty key raises at registration and one holding `.` or `@`
  raises inside delivery — both `NSException`, which Swift cannot catch, and
  neither confined to debug. Such a key falls back to
  `didChangeNotification`, which is strictly weaker: it names no key, so the
  fallback compares the stored value against the last one it saw, and it is not
  posted for another process's write, so only this app's own changes are
  delivered.
- Package traits `Combine` and `SwiftUI`, both enabled by default, so a client
  can leave out the surfaces it does not use. `SwiftUI` enables `Combine` with
  it, since the view's refresh is driven by the publisher. Both targets are
  Apple-only regardless of the trait set; turning both off leaves the wrapper,
  the subscripts, and `values`, which is everything the package offers
  elsewhere.
- Support for macOS 12, Mac Catalyst 15, iOS 15, tvOS 15, watchOS 8, and
  visionOS 1 or later, and for every other platform Foundation builds for.
  Reading and writing works wherever Foundation does; observing is Darwin-only
  and absent elsewhere rather than present and silent, since
  swift-corelibs-foundation has no KVO and posts `didChangeNotification` only
  for whole-domain changes. Building the package requires Swift 6.3 or later.

[unreleased]: https://github.com/sinoru/swift-user-defaults-kit/compare/v0.0.1...HEAD
[0.0.1]: https://github.com/sinoru/swift-user-defaults-kit/releases/tag/v0.0.1
