//===----------------------------------------------------------------------===//
//
// Darling: the small ICU helpers swift-foundation keeps in ICU/ICU+Enums.swift,
// ICU/ICU+Foundation.swift, Date+ICU.swift and FoundationEssentials/Formatting/FormatterCache.swift.
// Those four files are not fetched: between them they also carry the ICU 69/70 constants Darling's
// ICU 66 does not have, plus Locale and Calendar plumbing that collides with this overlay's own.
// Only the declarations the date styles here actually use are reproduced, each an alias for the
// ICU constant of the same meaning.
//
//===----------------------------------------------------------------------===//

internal import DarlingICU

extension UErrorCode {
    var isSuccess: Bool { self.rawValue <= U_ZERO_ERROR.rawValue }
}

extension UDateRelativeDateTimeFormatterStyle {
    static let long = UDAT_STYLE_LONG
    static let short = UDAT_STYLE_SHORT
    static let narrow = UDAT_STYLE_NARROW
}

extension URelativeDateTimeUnit {
    static let year = UDAT_REL_UNIT_YEAR
    static let quarter = UDAT_REL_UNIT_QUARTER
    static let month = UDAT_REL_UNIT_MONTH
    static let week = UDAT_REL_UNIT_WEEK
    static let day = UDAT_REL_UNIT_DAY
    static let hour = UDAT_REL_UNIT_HOUR
    static let minute = UDAT_REL_UNIT_MINUTE
    static let second = UDAT_REL_UNIT_SECOND
}

extension UNumberFormatStyle {
    static let decimal = UNUM_DECIMAL
    static let spellout = UNUM_SPELLOUT
}

extension Date {
    var udate: UDate { timeIntervalSince1970 * 1000 }

    init(udate: UDate) {
        self = Date(timeIntervalSince1970: udate / 1000)
    }
}

/// Allocate a UChar buffer, run `body`, and retry once on overflow. Upstream's shape.
internal func _withResizingUCharBuffer(initialSize: Int32 = 32,
                                       _ body: (UnsafeMutablePointer<UChar>, Int32, inout UErrorCode) -> Int32?) -> String? {
    withUnsafeTemporaryAllocation(of: UChar.self, capacity: Int(initialSize)) { buffer in
        var status = U_ZERO_ERROR
        guard let len = body(buffer.baseAddress!, initialSize, &status) else { return nil }
        if status == U_BUFFER_OVERFLOW_ERROR {
            return withUnsafeTemporaryAllocation(of: UChar.self, capacity: Int(len + 1)) { inner in
                var innerStatus = U_ZERO_ERROR
                guard let innerLen = body(inner.baseAddress!, len + 1, &innerStatus),
                      innerStatus.isSuccess, innerLen > 0 else { return nil }
                return String(decoding: UnsafeBufferPointer(start: inner.baseAddress!, count: Int(innerLen)), as: UTF16.self)
            }
        }
        guard status.isSuccess, len > 0 else { return nil }
        return String(decoding: UnsafeBufferPointer(start: buffer.baseAddress!, count: Int(len)), as: UTF16.self)
    }
}

/// Upstream's FormatterCache, reduced to the one operation these styles call.
internal final class FormatterCache<Signature: Hashable, Formatter>: @unchecked Sendable {
    private let lock = LockedState<[Signature: Formatter]>(initialState: [:])

    func formatter(for signature: Signature, creator: () -> Formatter) -> Formatter {
        if let existing = lock.withLock({ $0[signature] }) { return existing }
        let new = creator()
        lock.withLock { $0[signature] = new }
        return new
    }
}
