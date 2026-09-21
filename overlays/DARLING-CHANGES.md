# Darling changes to vendored upstream sources

`build.sh` fetches [apple/swift-foundation](https://github.com/apple/swift-foundation) at a pinned
commit (`dbacc67779dc0a41ddc9493acbaa332d76c9fb03`, tag `swift-6.3.3-RELEASE`) and compiles 35 files
from it in place. Those 35 are byte-identical to upstream, so they are not vendored here. Four of
the 39 swift-foundation files this overlay uses are not taken from the checkout, because they
diverge; those live in `Foundation/` and each one's reason is below, measured rather than assumed.
[apple/swift-collections](https://github.com/apple/swift-collections) is fetched the same way, at
`c11818f3cae0780656baa430b49e7f163f08dffd` (tag `1.1.6`), and nothing of it is vendored.

Set `SWIFT_FOUNDATION_SRC` or `SWIFT_COLLECTIONS_SRC` to an existing checkout of the matching commit
to build offline. Neither checkout is ever written to, so no patch is applied to a tree you supply.
To see exactly how one of the three diverges, diff it against the checkout, for example
`diff -u "$src/Sources/FoundationEssentials/AttributedString/AttributedStringProtocol.swift" overlays/Foundation/AttributedStringProtocol.swift`.

Both projects are Apache License v2.0 with the Runtime Library Exception. Upstream file headers are
preserved in the four files kept here, and swift-foundation's `LICENSE.md` and `NOTICE.txt` sit
beside them.

`Foundation/Locale+Language.swift` was vendored by the Locale work and is byte-identical to
`dbacc67`, so it moves into the fetch list here. `Foundation/Locale+Components.swift` stays, because
it diverges by 7 lines, and `Foundation/Locale+Darling.swift` stays because it is Darling-written
rather than upstream code. Both are documented below.

`_FoundationICU` is **not** pulled in. `Locale.Language`, `Locale.LanguageCode`, `Locale.Region` and
`Locale.Currency` all live in `FoundationEssentials`, which does not link ICU: they are value
wrappers over a string identifier plus static ISO code tables. Only the accessors that *reach* them
from a `Locale` live in `FoundationInternationalization`, and those are reimplemented over Darling's
`NSLocale` instead (below).

`CoreGraphics/CGGeometry.swift` comes from
[swift-corelibs-foundation](https://github.com/swiftlang/swift-corelibs-foundation) (`release/5.4`,
`Sources/Foundation/NSGeometry.swift`). It is vendored rather than fetched because only five
extension blocks of that one file are wanted, not the file or the package: the rest defines
`CGPoint`, `CGSize` and `CGRect` as Swift structs, which Darling imports from C instead, and pulls
in `NSSpecialValueCoding`, `NSEdgeInsets` and the `NS*` geometry functions. The five blocks taken
are byte-identical to upstream; the only additions are the file header and the
`import _DarlingCoreGraphicsShims` line that brings the C structs into scope.
Apache License v2.0 with the Runtime Library Exception; the upstream file header is preserved.

Taken: the `CGPoint` and `CGSize` extensions (`zero`, the `Int` and `Double` initializers) with
their `Equatable` conformances, and the `CGRect` extensions (`zero`, the three initializers, `null`,
`infinite`, `width`, `height`, `minX`, `midX`, `maxX`, `minY`, `midY`, `maxY`, `isEmpty`,
`isInfinite`, `isNull`, `contains(_:)` for a point and for a rect, `standardized`, `integral`,
`insetBy(dx:dy:)`, `union(_:)`, `intersection(_:)`, `intersects(_:)`, `offsetBy(dx:dy:)`,
`divided(atDistance:from:)`) with its `Equatable` conformance.

`CoreGraphics/CGGeometry.swift` also carries the `CGSize: Codable` block from the same upstream
file, byte-identical.

`CoreGraphics/CGAffineTransform.swift` carries three blocks from
[swiftlang/swift](https://github.com/swiftlang/swift) (`release/5.4`,
`stdlib/public/Darwin/CoreGraphics/CoreGraphics.swift`): the `Equatable` conformance,
`CGAffineTransform.identity` and the `Codable` conformance. `CoreGraphics.swift`'s `CGColor.components`
body comes from the same upstream file. Apache License v2.0 with the Runtime
Library Exception; the upstream file header is preserved. Upstream's `==` calls `__equalTo`, which
is the name the macOS SDK's `CoreGraphics.apinotes` gives `CGAffineTransformEqualToTransform`;
Darling ships no apinotes, so the C function is called under its own name. That one-word change is
the only departure.

The rest of `CGAffineTransform.swift`, and everything appended to `CoreGraphics.swift`, has no Swift
source upstream: on macOS those members reach Swift as Clang-importer renames driven by
`CoreGraphics.apinotes` (`CGAffineTransformInvert` becomes `CGAffineTransform.inverted()`,
`CGImageGetColorSpace` becomes `getter:CGImage.colorSpace(self:)`, `kCGColorSpaceSRGB` becomes
`CGColorSpace.sRGB`). They are written here over the C functions and constants that Darling's own
headers declare, the same way `CGImage.width` and `CGRect.applying(_:)` already were.

## CoreGraphics members that cannot live in this overlay

Four renames Apple's apinotes supply are **initializers on CF types**, and Swift rejects those in an
extension ("designated initializer cannot be declared in an extension", "convenience initializers
are not supported in extensions of CF types"). They need a `CoreGraphics.apinotes` in Darling's SDK,
or `CF_SWIFT_NAME` on the C declarations, not overlay code:

- `CGColorSpace.init?(name:)` (`CGColorSpaceCreateWithName`)
- `CGColor.init?(colorSpace:components:)` (`CGColorCreate`)
- `CGPath.init(rect:transform:)` (`CGPathCreateWithRect`)
- `CGMutablePath.init()` (`CGPathCreateMutable`)

Three more are absent from Darling's C CoreGraphics altogether, so there is nothing for an overlay
member to call: `CGColorCreateCopyByMatchingToColorSpace` (which backs
`CGColor.converted(to:intent:options:)`), `CGColorSpaceIsHLGBased` and `CGColorSpaceUsesITUR_2100TF`.

## Darling-specific adaptations

The other files in `Foundation/` come from the Swift 5.4 Darwin overlay and predate this mechanism;
`README.md` describes them.

## Which files are swift-foundation's, and how to check

The count of 39 is a provenance claim, and provenance cannot be settled by diffing against
swift-foundation alone: this overlay's other lineage is the Swift 5.4 Darwin overlay, and both
descend from the same original code, so a file being close to swift-foundation proves nothing.
Diffing against **both** lineages does settle it. Against
`release-5.4/stdlib/public/Darwin/Foundation` and `swift-foundation/Sources/FoundationEssentials`,
counting changed lines:

- `Pointers+DataProtocol.swift`, `Collections+DataProtocol.swift`, `ContiguousBytes.swift` and
  `DataProtocol.swift` are **byte-identical to the 5.4 overlay** while differing from
  swift-foundation by 2, 7, 11 and 38 lines. They look like near-pristine swift-foundation files and
  are not; they are 5.4's.
- `Codable.swift` is closer to 5.4 (52 changed lines against 66).
- The four files kept here have **no 5.4 counterpart at all**, which is what fixes their lineage.

One file is genuinely undetermined and is flagged rather than assumed: `DateInterval.swift` is
closer to swift-foundation (57 changed lines) than to 5.4 (87), while `README.md` attributes it to
the 5.4 overlay. It is identical to neither, so it is adapted, and this file does not claim to know
from which. Anyone recounting should run the two-way diff rather than a one-way one, and should
expect to reach 39 only if they use the same provenance list.

## The swift-foundation files that are not taken from the checkout

Four files, three of them described here and `Locale+Components.swift` under the `Locale` entries
below.

### Why these are override files rather than patches

The general rule is to carry a divergence in whichever form is smaller, counted as **lines the
repository carries**. That convention matters and belongs next to any such table: a stricter count
on the patch side, dropping diff metadata or a patch's own explanatory header, biases the comparison
by exactly what it strips, while an override file is carried whole including its upstream licence
header and any comment explaining the reduction. `CodableUtilities.swift` is the clean example of
the mirror image: of its 19 lines, 11 are the Apache header and about 4 are the comment saying what
was dropped, so a divergence-only count would score it at about 4 and flatter the override form by
the same mechanism a metadata-stripped count flatters the patch form. Count what lands in the tree,
on both sides.

Per file, that gives a split answer:

| file | patch | file | smaller |
|---|---|---|---|
| `CodableUtilities.swift` | 696 lines | 19 lines | override |
| `String+Comparison.swift` | 775 lines | 21 lines | override |
| `AttributedStringProtocol.swift` | 57 lines | 271 lines | patch |
| `Locale+Components.swift` | 23 lines | 2,086 lines | patch |

The patch column is raw `diff -u` output; a committed patch file would also carry a short header
saying why it exists, which adds a handful of lines to that side and changes none of the four
directions. All four are kept as override files anyway, so that this overlay has one mechanism rather than two
for a saving of 57 lines on one file. That is a deliberate departure from the rule and is recorded
here rather than left to look like the rule endorsing it. If a patch step is ever added,
`Locale+Components.swift` is the strongest candidate by a factor of ninety, and the patch must be
applied to a copy of the checkout, never to the checkout itself, since `SWIFT_FOUNDATION_SRC` can
point at a shared or read-only tree.

- **`CodableUtilities.swift`, reduced to two declarations.** Only `EmptyCodingKeys` and
  `DefaultAssociatedValueCodingKeys1` are kept, which is all that `AttributedString`'s
  `CodableWithConfiguration` conformances reference. Taking the file whole was measured and does not
  work: it needs `JSON/`, which needs `Decimal/` and `Base64.swift`, and that stack then collides
  with the 5.4 JSON and property-list code this overlay already ships. The collisions are
  `invalid redeclaration of '_plistNull'`, `invalid redeclaration of '_PlistDecodingStorage'` and
  `'_PlistDecodingStorage' is ambiguous for type lookup`, plus 22 further errors inside
  `PlistEncoder.swift` and 6 inside `JSONEncoder.swift`. Replacing the 5.4 JSON and property-list
  stack with swift-foundation's is a separate piece of work with its own symbol-diff acceptance, not
  a side effect of adding `AttributedString`.

- **`String+Comparison.swift`, reduced to the two UTF-8 code-unit constants.** `StringBlocks.swift`
  needs `UTF8.CodeUnit.newline` and `.carriageReturn`. Taking the file whole was measured: with
  `UnicodeScalar.swift` and `BidirectionalCollection.swift` added it still fails with 80 errors, 72
  of which are the same defect that forces the next entry, `String.CompareOptions` importing as a
  plain raw-value struct instead of an `OptionSet`. The remaining 8 are `BuiltInUnicodeScalarSet`
  (whose file imports the `_FoundationCShims` C target) and `RegexPatternCache`.

- **`AttributedStringProtocol.swift`, with `range(of:options:locale:)` and its `_range` helper
  omitted.** Both declare a `String.CompareOptions = []` default argument, which does not type-check
  for the same reason. The root cause is not `NSString.h`, which declares the type correctly with
  `NS_OPTIONS`; it is `src/external/foundation/include/Foundation/NSObjCRuntime.h`, whose
  `NS_OPTIONS` macro omits the `flag_enum` and `enum_extensibility(open)` attributes that make the
  Clang importer present the type as an `OptionSet`. `CFAvailability.h` in the same project already
  applies both through `__CF_OPTIONS_ATTRIBUTES`, so `CF_OPTIONS` types always imported correctly
  and `NS_OPTIONS` was the lone holdout, across 46 typedefs in 28 headers. It is fixed in
  darling-foundation#38, which needs a darling-swift companion because correcting the import also
  changes how those constants are spelled in Swift. When both land, this entry and the one above
  should be revisited and should disappear. No binary in the macOS 26 app corpus binds either
  omitted symbol.

- **swift-collections built without library evolution and linked into `libswiftFoundation`.**
  `InternalCollectionsUtilities` and `_RopeModule` are an implementation detail of
  `AttributedString`'s storage, not part of the SDK, so `build.sh` compiles them to objects and
  links those into the Foundation dylib rather than shipping them as dylibs. Apple links
  `CollectionsInternal` into `Foundation.framework` the same way, and hides its symbols, so
  `build.sh` passes ld64 an `-unexported_symbols_list` naming both module prefixes to keep their
  1,159 symbols out of the dylib's export table. Their own sources are unmodified; this is a
  choice about how they are built, not a change to them.

- **`build.sh` passes `-package-name swift-foundation`.** Without it, `package`-level declarations
  such as `LockedState` silently degrade to `fileprivate` and the module does not compile. The value
  matches swift-foundation's own package identity so `package` symbols mangle as upstream does.

- **`CGGeometry.swift` follows Apple's semantics where Darling's C CoreGraphics does not.** The
  vendored code is unmodified, so where cocotron's `CGGeometry.m` disagrees with it, the Swift and
  the C answer differ. Three measured cases, all of them cocotron departing from Apple rather than
  the overlay departing from C:
  - `CGRect.infinite` is Apple's `{-CGFloat.greatestFiniteMagnitude / 2, ..., .greatestFiniteMagnitude, ...}`.
    Darling's C global `CGRectInfinite` is `{{0, 0}, {INFINITY, INFINITY}}`, and its own header
    comment asks whether that matches Apple. It does not.
  - `CGRect.intersection(_:)` returns `.null` for disjoint rectangles, as documented. C
    `CGRectIntersection` returns `CGRectZero`.
  - `CGRect.isInfinite` is true only for the infinite rectangle. C `CGRectIsInfinite` is true for any
    rectangle with an infinite field.
  `CGRectNull` agrees in both, which is the one that matters for the null sentinel. Fixing the three
  belongs in cocotron's `CGGeometry.m`, not here.

- **`applying(_:)` and `CGImage.width`/`.height` are written for Darling, in
  `CoreGraphics/CoreGraphics.swift`.** No open-source Swift implementation of them exists: on macOS
  they are Clang-importer renames of `CGRectApplyAffineTransform`, `CGPointApplyAffineTransform`,
  `CGSizeApplyAffineTransform`, `CGImageGetWidth` and `CGImageGetHeight` driven by
  `CoreGraphics.apinotes`, and swift-corelibs-foundation has no `CGAffineTransform` or `CGImage` to
  extend. They call those same C functions, the way the `CGContext` methods beside them do. The two
  `Apply` ones Darling declares as `static inline` behind a macro, so the overlay calls
  `__CGPointApplyAffineTransform` and `__CGSizeApplyAffineTransform` by their real names.

## Not vendored, and why

Nothing here is stubbed or approximated. These are left out because no honest source exists in the
tree:

- The `#if FOUNDATION_FRAMEWORK`-guarded parts of the vendored files. The files themselves are
  vendored whole and their unguarded declarations do compile, so `AttributeScopes` and
  `FoundationAttributes` exist; what is missing is the guarded half, which is where the attribute
  scope's dynamic registration, `AttributedString`'s `Codable` conformances and
  `AttributedString(NSAttributedString)` live. That mode needs the Clang modules `MachO.dyld`,
  `ReflectionInternal`, `CollectionsInternal` and `Foundation_Private.NSAttributedString`, none of
  which Darling has.
- The ICU-backed `FormatStyle` implementations and `AttributedString(localized:)`. They need
  `_FoundationICU` from swift-foundation-icu.
- `AttributedString(markdown:)` and `MarkdownParsingOptions`, which need swift-cmark.
- `InlinePresentationIntent`. It is not declared anywhere in swift-foundation, and
  `NSInlinePresentationIntent` is absent from darling-foundation's headers, so there is nothing to
  vendor. It is not invented here.

## Reproducibility

`build.sh` is deterministic in its inputs (the swift-collections pin is by commit, and source lists
are sorted with `LC_ALL=C`), but its output is not byte-for-byte reproducible, because `swiftc`
6.3.3 is not. Measured by compiling the untouched `overlays/ObjectiveC/ObjectiveC.swift` twice in
the same directory with identical flags: the two objects differ by 16 bytes, the whole of the
`__swift_modhash` section. Two builds of this branch's `libswiftFoundation.dylib` differ by 26 of
4,110,348 bytes in the arm64 slice: the 16-byte `LC_UUID`, which ld64 derives from the content, and
five 2-byte immediates in `__text`. This predates the AttributedString work and is unrelated to
whether a dependency is vendored or fetched.

## Upstreamable

Nothing so far. No upstream bug was found while vendoring these files.
- **`Locale.Components` is excluded from the build.** In
  `Foundation/Locale+Components.swift` it is kept verbatim but wrapped in `#if
  DARLING_LOCALE_COMPONENTS`, which nothing defines. Two things block it, both in Darling's
  `Calendar` and `TimeZone` rather than in the type itself: its `icuIdentifier` property calls
  `Calendar.Identifier.cldrIdentifier`, `Calendar.Identifier.legacyKeywordKey` and
  `TimeZone.legacyKeywordKey`, and its synthesised `Codable` conformance needs a `Codable`
  `Calendar.Identifier`. This overlay's `Calendar` and `TimeZone` come from the Swift 5.4 Darwin
  overlay, not from swift-foundation, and have none of those. `icuIdentifier` is the whole point of
  the type (it is how a `Locale.Components` turns back into a locale identifier), so a copy without
  it would be a public type that cannot do the one job it exists for. Excluding it costs nothing
  against measured demand: no binary in the macOS 26 app corpus binds a `Locale.Components` symbol.
  Everything else in the file, including `Locale.Script`, `Locale.Collation`,
  `Locale.NumberingSystem`, `Locale.Weekday`, `Locale.HourCycle`, `Locale.MeasurementSystem`,
  `Locale.Subdivision`, `Locale.Variant`, `ICULegacyKey` and the ISO language, region and script
  tables, is compiled unmodified.
- **`Foundation/Locale+Darling.swift` is a Darling reimplementation, not upstream code.** It
  supplies the four accessors that reach the vendored types from a `Locale`: `Locale.language`,
  `Locale.region`, `Locale.currency` and `Locale.Language.languageCode`. Upstream implements these
  in `FoundationInternationalization/Locale/Locale+Components_ICU.swift` and the `_Locale` protocol,
  reading components straight out of ICU through `uloc_getLanguage`, `uloc_getCountry` and friends.
  This overlay's `Locale` is the Swift 5.4 SDK overlay's wrapper around `NSLocale`, which has no
  such internals, so the components are read from `NSLocale` instead: `languageCode`, `scriptCode`,
  `regionCode` and `currencyCode`, which Darling's CoreFoundation backs with its own ICU-backed
  `CFLocale`. That is the same data upstream reads, reached through Darling's own locale machinery.
  Two behavioural differences follow, and neither invents a value:
  - `Locale.region` reads `NSLocaleCountryCode`, so an `rg` override in the identifier is honoured
    only as far as Darling's `CFLocale` honours it. Upstream distinguishes `Locale.region` from
    `Locale.language.region` on exactly that key.
  - `Locale.Language.languageCode` returns the stored `components.languageCode` with no fallback.
    Upstream falls back to `uloc_getLanguage(components.identifier)` when the stored code is nil.
    Every `Locale.Language` initializer this overlay ships stores the code directly, so there is no
    identifier left to parse and the stored value is the complete answer; nil means the language
    genuinely has no code.
- **`Locale.Language.script` and `Locale.Language.region` are not provided.** They are the other two
  members of the same upstream ICU file. Nothing in the app corpus binds them, and adding them would
  be more Darling reimplementation for no measured demand.

## How the fetched code is built

- **swift-collections is built without library evolution and linked into `libswiftFoundation`.**
  `InternalCollectionsUtilities` and `_RopeModule` are an implementation detail of
  `AttributedString`'s storage, not part of the SDK, so `build.sh` compiles them to objects and
  links those into the Foundation dylib rather than shipping them as dylibs. Apple links
  `CollectionsInternal` into `Foundation.framework` the same way, and hides its symbols, so
  `build.sh` passes ld64 an `-unexported_symbols_list` naming both module prefixes to keep their
  1,159 symbols out of the dylib's export table. Their own sources are unmodified; this is a choice
  about how they are built, not a change to them.

- **`build.sh` passes `-package-name swift-foundation`.** Without it, `package`-level declarations
  such as `LockedState` silently degrade to `fileprivate` and the module does not compile. The value
  matches swift-foundation's own package identity so `package` symbols mangle as upstream does.

## Not built at all, and why

Nothing here is stubbed or approximated. These are left out because no honest source exists in the
tree:

- The `#if FOUNDATION_FRAMEWORK`-guarded parts of the fetched files. The files themselves are
  compiled whole and their unguarded declarations do work, so `AttributeScopes` and
  `FoundationAttributes` exist; what is missing is the guarded half, which is where the attribute
  scope's dynamic registration, `AttributedString`'s `Codable` conformances and
  `AttributedString(NSAttributedString)` live. That mode needs the Clang modules `MachO.dyld`,
  `ReflectionInternal`, `CollectionsInternal` and `Foundation_Private.NSAttributedString`, none of
  which Darling has.
- The ICU-backed `FormatStyle` implementations and `AttributedString(localized:)`. They need
  `_FoundationICU` from swift-foundation-icu.
- `AttributedString(markdown:)` and `MarkdownParsingOptions`, which need swift-cmark.
- `InlinePresentationIntent`. It is not declared anywhere in swift-foundation, and
  `NSInlinePresentationIntent` is absent from darling-foundation's headers, so there is nothing to
  take. It is not invented here.

## Fixes worth sending upstream
None. Nothing in these two files needed correcting; the only changes are the exclusion above, which
is a statement about Darling's `Calendar` and `TimeZone`, not about swift-foundation.

## Reproducibility

`build.sh` is bit-reproducible when run twice from the same directory: wiping `overlays/build` and
rebuilding produces an identical `libswiftFoundation.dylib`.

It is not reproducible across different build directories. Two builds of the same commit at
different paths give an arm64 slice differing by 26 of 4,110,348 bytes: the 16-byte `LC_UUID`,
which ld64 derives from the content, and five `mov w2, #imm` immediates in `__text` whose values
track the build root's path length exactly (a 41-character root gives 76, an 81-character root 116,
an 83-character root 118). `__swift_modhash` never reaches the dylib; the linker drops it.

This predates the AttributedString work and is not related to whether a dependency is vendored or
fetched. Measured on the tree of #33, which is master plus a CryptoKit framework and contains none
of this branch's changes: built at two different paths, `libswiftFoundation.dylib` differs by 21
bytes and `libswiftDispatch.dylib` by 27, while `Darwin`, `ObjectiveC`, `CoreFoundation`, `os`,
`XPC`, `CoreGraphics`, `AppKit` and `CryptoKit` are all bit-identical.
