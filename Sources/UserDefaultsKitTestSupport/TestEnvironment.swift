//
//  TestEnvironment.swift
//  UserDefaultsKitTestSupport
//

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

/// Whether the ThreadSanitizer runtime is loaded into this process.
///
/// Asked of the runtime rather than of `__has_feature`, which would answer for whichever compiler
/// saw the file rather than for the process the tests run in.
///
/// What asks: the measurement suites, which have nothing to say under an instrumented build and
/// whose XCTest worker is not reliable there either. Not for CI's benefit — it skips those suites
/// outright — but for the run that asks for them by name, which is a developer's, and which has no
/// reason to remember whether a sanitizer is attached to the build they last made.
///
/// Windows has no `dlopen` to ask and no ThreadSanitizer to ask about, so it answers without a
/// loader.
#if canImport(Darwin) || canImport(Glibc) || canImport(Musl) || canImport(Android)
package let threadSanitizerIsLoaded: Bool = {
    guard let program = unsafe dlopen(nil, RTLD_LAZY) else {
        return false
    }

    return unsafe dlsym(program, "__tsan_init") != nil
}()
#else
package let threadSanitizerIsLoaded = false
#endif
