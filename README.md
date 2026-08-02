# Swift User Defaults Kit

[![GitHub Actions — CI](https://github.com/sinoru/swift-user-defaults-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/sinoru/swift-user-defaults-kit/actions/workflows/ci.yml)
[![GitHub Actions — Apple Platforms](https://github.com/sinoru/swift-user-defaults-kit/actions/workflows/apple-platforms.yml/badge.svg)](https://github.com/sinoru/swift-user-defaults-kit/actions/workflows/apple-platforms.yml)

[![Swift Package Index — Swift Versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fsinoru%2Fswift-user-defaults-kit%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/sinoru/swift-user-defaults-kit)
[![Swift Package Index — Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fsinoru%2Fswift-user-defaults-kit%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/sinoru/swift-user-defaults-kit)

**UserDefaultsKit** stores any `Codable` value in `UserDefaults` — encoded
*into* a property list rather than archived into a blob. A struct lands as a
dictionary and a `String`-backed enum as a string, so a value written through
this package stays as legible to `defaults(1)`, to `@AppStorage`, and to any
other process sharing the domain as a `String` or an `Int` would.

## Table of Contents

* [Getting Started](#getting-started)
* [Reading and Writing](#reading-and-writing)
* [Observing Changes](#observing-changes)
* [Platform Support](#platform-support)
* [Using Swift User Defaults Kit in Your Project](#using-swift-user-defaults-kit-in-your-project)
* [Contributing](#contributing)
* [License](#license)

## Getting Started

```swift
import UserDefaultsKit

struct Appearance: Codable, Sendable {
    enum Theme: String, Codable, Sendable {
        case system, light, dark
    }

    var theme: Theme = .system
    var accentColor: String?
}

final class Settings {
    @UserDefault("appearance") var appearance = Appearance()
    @UserDefault("launchCount") var launchCount = 0
}

let settings = Settings()
settings.appearance.theme = .dark
```

`@AppStorage` would not take `Appearance` at all, and `NSKeyedArchiver` would
take it as bytes. This stores the shape:

```sh
$ defaults read com.example.app appearance
{
    theme = dark;
}
```

A property left `nil` is left out rather than written as a null, which is what
a synthesized `Encodable` asks for and what keeps an unset value legible as
unset to everything else reading the domain.

Nothing is cached: every read goes to `UserDefaults`, so a value can never be
stale, and every write goes through at once. Reading a key does not create it —
the default lives in the declaration and is never written back.

## Reading and Writing

The wrapper is a thin layer over a subscript on `UserDefaults`, which is usable
on its own:

```swift
UserDefaults.standard["username"] = "anonymous"

let name = UserDefaults.standard["username", type: String.self]  // String?
let launches = UserDefaults.standard["launchCount", default: 0]  // Int
```

Assigning `nil` removes the key rather than storing a null. A value that fails
to encode is ignored and the key keeps what it held — a write is
all-or-nothing. A property-wrapper setter cannot throw, so that failure is
silent; in debug it trips an assertion.

Reading follows the defaults system's storage model rather than Swift's type
identity:

* **Numbers read one another, at any depth.** A property list keeps no
  `Float`/`Double`/`Int` distinction, so refusing a `Double` asked for as a
  `Float` would reject a value the defaults system never promised to keep
  apart. A fractional value read as an `Int` truncates toward zero; one too
  large to represent — or a NaN — reads as `nil` rather than trapping.
* **`Bool` reads what a property list can mean by it:** `true`/`false`, or a
  number that is exactly `0` or `1`. This does not run the other way — a stored
  `<true/>` asked for as a number reads as `nil`, because a property list does
  keep those apart and `defaults(1)` prints them differently.
* **A value of an unrelated kind reads as `nil`,** letting the default take
  over. Deliberately stricter than `integer(forKey:)` and its siblings, which
  flatten a mismatch into `0`.
* **`String` and `URL` inherit the coercions of `string(forKey:)` and
  `url(forKey:)`, and only at the top.** Those are Foundation's accessors
  rather than this package's, and there is no accessor to inherit from inside a
  collection: a stored `123` read as a `String` yields `"123"`, while a stored
  `[123]` read as `[String]` yields `nil`.

A top-level `URL` is the one value handed to Foundation as it is rather than
encoded, so that `url(forKey:)` and `@AppStorage` can still read it. On Darwin
that means a non-file URL is stored as a keyed archive — the one opaque thing a
key written through this package can hold — and on
swift-corelibs-foundation it means only a file URL survives the round trip at
all, since `set(_:forKey:)` there keeps `url.path` and drops the rest. A `URL`
*inside* a value takes the ordinary path and loses nothing on either platform.

## Observing Changes

The projected value is the wrapper itself, so the observation surfaces hang off
`$`:

```swift
@UserDefault("username") var username = "anonymous"

$username.publisher.sink { ... }             // Combine
for await name in $username.values { ... }   // AsyncStream
TextField("Name", text: $username.binding)   // SwiftUI
```

In a SwiftUI view, declare the value with `UserDefaultStorage` instead. It is
the `Codable` analogue of `@AppStorage`: SwiftUI owns the observation for the
lifetime of the view, its projected value is a `Binding`, and the view
refreshes when the value changes — including when the change was made by
another process sharing the suite.

```swift
struct SettingsView: View {
    @UserDefaultStorage("username") var username = "anonymous"

    var body: some View {
        TextField("Name", text: $username)
    }
}
```

Nothing here is process-lifetime state. Each subscription, stream, and view
creates and holds its own observation and unregisters when it goes away.

Key-Value Observing is what carries the cross-process promise, and it reads a
key as a *key path* — so an empty key, or one containing `.` or `@`, cannot be
observed as the literal key it is. Such a key still reads and writes correctly
and its changes are still delivered, but by a weaker fallback that sees only
this process. Prefer a key without `.`/`@` for anything that has to follow an
app extension or another app-group member.

## Platform Support

The package supports macOS 12, Mac Catalyst 15, iOS 15, tvOS 15, watchOS 8, and
visionOS 1 or later, along with every platform Foundation builds for. Storage
works everywhere; observation does not:

| Platform | Reading and writing | Observing |
| --- | --- | --- |
| Apple platforms | Supported | Key-Value Observing, which reports a change whichever process made it — falling back to `didChangeNotification` for a key KVO cannot take |
| Linux, Windows, and elsewhere | Supported | Absent |

swift-corelibs-foundation has no KVO, and its `UserDefaults` posts
`didChangeNotification` only for whole-domain changes rather than for a
`set(_:forKey:)` write — so neither backend exists there. `publisher`,
`values`, and `UserDefaultStorage` are absent on those platforms rather than
present and silent.

Building the package requires Swift 6.3 or later.

### Running the tests

`swift test` needs no arguments and takes no environment variables.

The one thing a plain run leaves out is the measurements, which a debug build
skips because an unoptimized one says nothing, and which skip themselves when
ThreadSanitizer is attached. They compare this package's property-list coder
against the `Data` round trip it replaced, and the subscript against
`object(forKey:)` and `integer(forKey:)`. Read the numbers; nothing there fails
on a regression, because a number means something next to the number beside it
rather than next to one from another machine.

```sh
swift test -c release -Xswiftc -enable-testing --filter PerformanceTests
```

CI builds and tests in both configurations on macOS and Linux, and under
ThreadSanitizer on both. Release is what ships and the only configuration
Swift's default cross-module optimization applies to — every read and write
here crosses a module boundary. Debug is where `assertionFailure` still exists:
it is compiled out under `-O`, which was measured rather than assumed, so the
encode failure the setter reports is reachable in that configuration alone.
`precondition` survives both, which is why the exit tests do.

`swift build` compiles for the host and nothing else, so a separate workflow
drives the same manifest through the Xcode build system for every Apple
platform the manifest claims — device and simulator each, since those are
separate SDKs that fail independently. The watchOS device row is the only place
`Int` is 32 bits, which is the width the property-list value model narrows
against.

## Using Swift User Defaults Kit in Your Project

To use this package in a SwiftPM project, add the following to your
`Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/sinoru/swift-user-defaults-kit.git",
        "0.0.1"..<"0.1.0"
    ),
]
```

Then add `UserDefaultsKit` as a dependency of your target:

```swift
.target(
    name: "MyTarget",
    dependencies: [
        .product(name: "UserDefaultsKit", package: "swift-user-defaults-kit"),
    ]
),
```

The Combine and SwiftUI surfaces each live behind a
[package trait](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md)
of the same name, both enabled by default. To leave one out, enable traits
explicitly:

```swift
.package(
    url: "https://github.com/sinoru/swift-user-defaults-kit.git",
    "0.0.1"..<"0.1.0",
    traits: ["Combine"]
),
```

`Combine` provides `publisher`. `SwiftUI` provides `binding` and
`UserDefaultStorage`, and enables `Combine` with it, since the view's refresh
is driven by the publisher. Turning both off leaves the wrapper, the
subscripts, and `values` — which is everything the package offers away from
Apple platforms anyway, where the two targets are not built regardless of the
trait set.

## Contributing

Bug reports, feature ideas, and pull requests are welcome on
[GitHub](https://github.com/sinoru/swift-user-defaults-kit).

## License

[Apache License 2.0](LICENSE)
