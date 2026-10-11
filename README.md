<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="Assets/wordmark-dark.svg">
    <img src="Assets/wordmark.svg" alt="SwiftDiscovery" width="440">
  </picture>
</p>

<p align="center">
  <a href="https://github.com/OlafAndreas/swift-discovery/actions/workflows/ci.yml"><img src="https://github.com/OlafAndreas/swift-discovery/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-2F5F9E.svg" alt="MIT license"></a>
  <img src="https://img.shields.io/badge/Swift-6.3%2B-1B8A8F.svg" alt="Swift 6.3+">
  <img src="https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20Linux-2F5F9E.svg" alt="macOS, iOS, Linux">
</p>

Find every type that opted in. No registration code, no reflection, no Objective-C runtime.

```swift
import SwiftDiscovery

enum Plugins: DiscoveryKey {}

@Discoverable(Plugins.self)
struct SpellChecker: Plugin { ... }

for case let plugin as any Plugin.Type in Discoverable.types(for: Plugins.self) {
    register(plugin)
}
```

`@Discoverable` expands to a constant record in a dedicated binary section, the same
technique Swift Testing uses to find `@Test`. `Discoverable.types(for:)` walks the loaded
images once and caches the result. Nothing runs at load time.

## Install

```swift
.package(url: "https://github.com/OlafAndreas/swift-discovery.git", from: "0.1.1")
```

Requires Swift 6.3 or later (the `@section` and `@used` attributes from SE-0492; Swift 6.2 does not have them). Supported on Apple
platforms and ELF platforms (Linux, Android, FreeBSD). Windows is not implemented yet.

## API

- `DiscoveryKey`: a marker protocol. Keys are usually caseless enums owned by the framework that enumerates them.
- `@Discoverable(Key.self, ...)`: marks a struct, class, actor or enum under one or more keys. Apply it once per type.
- `Discoverable.types(for:)`: every loaded type under a key, sorted by qualified name, without duplicates.
- `Discoverable.types(for:in:)`: the same, restricted to a `DiscoveryScope` such as `.thisModule()` or `.modules([...])`.
- `Discoverable.rescan()`: re-walks the images, for code that loads plugins after first use.

## For framework authors

A framework that wants its own attribute, such as `@Handler`, depends on the
`SwiftDiscoveryMacroSupport` product from its macro target and emits the same record:

```swift
let placement = try DiscoveryRecordSyntax.placement(of: node, on: declaration, in: context)
return DiscoveryRecordSyntax.declarations(
    recording: placement,
    under: ["MyFramework.Handlers"],
    identifierPrefix: "__myframework_record_"
)
```

The expansion spells out the record type and erases metadata with `unsafeBitCast`, so the
adopting module needs no import beyond the key's. [SwiftMediator](https://github.com/OlafAndreas/swift-mediator)
is built this way.

## Limits

- Records are stored globals or static properties, so the attribute is rejected on local
  types and on types nested in generic types.
- Discovery sees what is linked and loaded. A type in a static-archive member that nothing
  references is never linked, and its record goes with it.
- On ELF the section bounds come from the linker's start and stop symbols of the image the
  package is linked into. Images loaded later with `dlopen` are not seen.

## License

MIT. See [LICENSE](LICENSE).
