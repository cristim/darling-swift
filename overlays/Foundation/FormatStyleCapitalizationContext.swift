//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

// FormatStyleCapitalizationContext, taken from swift-foundation's
// Sources/FoundationInternationalization/Formatting/Number/NumberFormatStyleConfiguration.swift
// at the commit overlays/build.sh pins. It is not fetched with the rest of that file because the
// file's other types need Decimal, String and RangeExpression internals the overlay does not
// carry, and two ICU-typed members. The public API below is upstream's verbatim; the only removal
// is the internal `icuContext` accessor, which maps the option onto ICU's UDisplayContext and has
// no consumer until the ICU-backed number and date styles land. The relative date styles are that
// consumer, so `icuContext` is restored below over Darling's ICU 66; the rest of upstream's file
// still cannot be compiled here.

internal import DarlingICU


// swift-foundation spells these in its own ICU/ICU+Enums.swift, which is not fetched here.
// Reproduced verbatim: each is an alias for the ICU constant of the same meaning.
extension UDisplayContext {
    static let beginningOfSentence = UDISPCTX_CAPITALIZATION_FOR_BEGINNING_OF_SENTENCE
    static let listItem = UDISPCTX_CAPITALIZATION_FOR_UI_LIST_OR_MENU
    static let middleOfSentence = UDISPCTX_CAPITALIZATION_FOR_MIDDLE_OF_SENTENCE
    static let standalone = UDISPCTX_CAPITALIZATION_FOR_STANDALONE
    static let unknown = UDISPCTX_CAPITALIZATION_NONE
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public struct FormatStyleCapitalizationContext : Codable, Hashable, Sendable {

    internal enum Option: Int, Codable, Hashable {
        case unknown
        case standalone
        case listItem
        case beginningOfSentence
        case middleOfSentence
    }

    internal var option: Option

    private init(_ option: Option) {
        self.option = option
    }

    var icuContext: UDisplayContext {
        switch self.option {
        case .unknown:
            return .unknown
        case .standalone:
            return .standalone
        case .listItem:
            return .listItem
        case .beginningOfSentence:
            return .beginningOfSentence
        case .middleOfSentence:
            return .middleOfSentence
        }
    }

#if FOUNDATION_FRAMEWORK
    var formatterContext: Formatter.Context {
        switch option {
        case .unknown:
            return .unknown
        case .standalone:
            return .standalone
        case .listItem:
            return .listItem
        case .beginningOfSentence:
            return .beginningOfSentence
        case .middleOfSentence:
            return .middleOfSentence
        }
    }
#endif // FOUNDATION_FRAMEWORK

    public static var unknown : FormatStyleCapitalizationContext {
        .init(.unknown)
    }

    /// For stand-alone usage, such as an isolated name on a calendar page.
    public static var standalone : FormatStyleCapitalizationContext {
        .init(.standalone)
    }

    /// For use in a UI list or menu item.
    public static var listItem : FormatStyleCapitalizationContext {
        .init(.listItem)
    }

    public static var beginningOfSentence : FormatStyleCapitalizationContext {
        .init(.beginningOfSentence)
    }

    public static var middleOfSentence : FormatStyleCapitalizationContext {
        .init(.middleOfSentence)
    }
}
