//===----------------------------------------------------------------------===//
//
// Darling-written. Stands in for swift-foundation's ICUDateFormatter, which is built on the
// vendored `_FoundationICU`. This is the same construction over Darling's ICU 66.1, reached
// through `shims/DarlingICU.h`. See DARLING-CHANGES.md for why CoreFoundation is not used.
//
//===----------------------------------------------------------------------===//

internal import DarlingICU

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
final class DarlingDateFormatter: @unchecked Sendable {
    private let udat: UnsafeMutablePointer<UDateFormat?>

    private init?(localeIdentifier: String, timeZoneIdentifier: String, pattern: String) {
        var status = U_ZERO_ERROR
        let tz = Array(timeZoneIdentifier.utf16)
        let pat = Array(pattern.utf16)
        guard let f = udat_open(UDAT_PATTERN, UDAT_PATTERN, localeIdentifier,
                                tz, Int32(tz.count), pat, Int32(pat.count), &status),
              status.rawValue <= U_ZERO_ERROR.rawValue else { return nil }
        udat = f
    }

    deinit { udat_close(udat) }

    func format(_ date: Date) -> String? {
        let millis = UDate(date.timeIntervalSince1970 * 1000)
        var buf = [UInt16](repeating: 0, count: 256)
        var status = U_ZERO_ERROR
        let n = udat_format(udat, millis, &buf, Int32(buf.count), nil, &status)
        guard n > 0, status.rawValue <= U_ZERO_ERROR.rawValue else { return nil }
        if Int(n) > buf.count {
            buf = [UInt16](repeating: 0, count: Int(n) + 1)
            status = U_ZERO_ERROR
            let n2 = udat_format(udat, millis, &buf, Int32(buf.count), nil, &status)
            guard n2 > 0, status.rawValue <= U_ZERO_ERROR.rawValue else { return nil }
            return String(decoding: buf[0..<Int(n2)], as: UTF16.self)
        }
        return String(decoding: buf[0..<Int(n)], as: UTF16.self)
    }

    func parse(_ string: String) -> Date? {
        let u = Array(string.utf16)
        var pos: Int32 = 0
        var status = U_ZERO_ERROR
        let millis = udat_parse(udat, u, Int32(u.count), &pos, &status)
        guard status.rawValue <= U_ZERO_ERROR.rawValue, Int(pos) == u.count else { return nil }
        return Date(timeIntervalSince1970: Double(millis) / 1000)
    }

    func parse(_ string: String, in range: Range<String.Index>) -> (String.Index, Date)? {
        let sub = String(string[range])
        let u = Array(sub.utf16)
        var pos: Int32 = 0
        var status = U_ZERO_ERROR
        let millis = udat_parse(udat, u, Int32(u.count), &pos, &status)
        guard status.rawValue <= U_ZERO_ERROR.rawValue, pos > 0,
              let end = String.Index(sub.utf16.index(sub.utf16.startIndex, offsetBy: Int(pos)), within: sub),
              let upper = string.index(range.lowerBound, offsetBy: sub.distance(from: sub.startIndex, to: end),
                                       limitedBy: range.upperBound)
        else { return nil }
        return (upper, Date(timeIntervalSince1970: Double(millis) / 1000))
    }

    // MARK: pattern generation

    /// The locale identifier ICU needs in order to honour a non-default calendar.
    static func localeIdentifier(_ locale: Locale, _ calendar: Calendar) -> String {
        let base = locale.identifier
        guard let keyword = cldrKeyword(calendar.identifier) else { return base }
        return base.contains("@") ? "\(base);calendar=\(keyword)" : "\(base)@calendar=\(keyword)"
    }

    /// CLDR calendar keyword. swift-foundation reads this from Calendar_ICU, which Darling does
    /// not carry. `islamicUmmAlQura` has no case on Darling's Calendar.Identifier, so it is absent
    /// here too rather than being mapped onto a neighbouring calendar.
    static func cldrKeyword(_ id: Calendar.Identifier) -> String? {
        switch id {
        case .gregorian: return nil
        case .buddhist: return "buddhist"
        case .chinese: return "chinese"
        case .coptic: return "coptic"
        case .ethiopicAmeteMihret: return "ethiopic"
        case .ethiopicAmeteAlem: return "ethiopic-amete-alem"
        case .hebrew: return "hebrew"
        case .iso8601: return "iso8601"
        case .indian: return "indian"
        case .islamic: return "islamic"
        case .islamicCivil: return "islamic-civil"
        case .japanese: return "japanese"
        case .persian: return "persian"
        case .republicOfChina: return "roc"
        case .islamicTabular: return "islamic-tbla"
        @unknown default: return nil
        }
    }

    /// udatpg_getBestPatternWithOptions, with the field-length matching upstream asks for.
    /// CFDateFormatterCreateDateFormatFromTemplate cannot be used here: it discards its `options`
    /// argument, so `.hour(.twoDigits)` would silently widen or narrow to the locale's default.
    static func bestPattern(skeleton: String, localeIdentifier: String) -> String? {
        var status = U_ZERO_ERROR
        guard let gen = udatpg_open(localeIdentifier, &status),
              status.rawValue <= U_ZERO_ERROR.rawValue else { return nil }
        defer { udatpg_close(gen) }
        let sk = Array(skeleton.utf16)
        var buf = [UInt16](repeating: 0, count: 256)
        status = U_ZERO_ERROR
        let n = udatpg_getBestPatternWithOptions(gen, sk, Int32(sk.count),
                                                 UDATPG_MATCH_ALL_FIELDS_LENGTH,
                                                 &buf, Int32(buf.count), &status)
        guard n > 0, status.rawValue <= U_ZERO_ERROR.rawValue else { return nil }
        return String(decoding: buf[0..<Int(n)], as: UTF16.self)
    }

    static func cached(for style: Date.FormatStyle) -> DarlingDateFormatter? {
        let localeID = localeIdentifier(style.locale, style.calendar)
        let skeleton = style.symbols.formatterTemplate(overridingDayPeriodWithLocale: style.locale)
        guard let pattern = bestPattern(skeleton: skeleton, localeIdentifier: localeID) else { return nil }
        return DarlingDateFormatter(localeIdentifier: localeID,
                                    timeZoneIdentifier: style.timeZone.identifier,
                                    pattern: pattern)
    }
}

/// swift-foundation declares these in FoundationEssentials/Calendar/Date+FormatStyle.swift, which
/// cannot be fetched here: it spells its constraints `FoundationEssentials.FormatStyle` and
/// `Foundation.FormatStyle` behind module checks, and this overlay compiles everything as one
/// module named Foundation, so neither name resolves. The two declarations are reproduced
/// unqualified; their signatures are upstream's.
extension Date {
    public func formatted<F: Foundation.FormatStyle>(_ format: F) -> F.FormatOutput where F.FormatInput == Date {
        format.format(self)
    }
}

extension DateComponents {
    public func formatted<F: Foundation.FormatStyle>(_ format: F) -> F.FormatOutput where F.FormatInput == DateComponents {
        format.format(self)
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Locale {
    /// swift-foundation reads this with `udatpg_getDefaultHourCycle`, which is ICU 67 and absent
    /// from Darling's ICU 66. It is not approximated: `j` is defined by CLDR as the locale's
    /// preferred hour field, which is the same datum the ICU 67 call reports, so the cycle is read
    /// off the pattern `j` resolves to. Checked against ten locales whose conventions are known
    /// independently; see DARLING-CHANGES.md.
    var hourCycle: Locale.HourCycle {
        guard let pattern = DarlingDateFormatter.bestPattern(skeleton: "j", localeIdentifier: identifier) else {
            return .zeroToTwentyThree
        }
        var inLiteral = false
        for ch in pattern {
            if ch == "'" { inLiteral.toggle(); continue }
            if inLiteral { continue }
            switch ch {
            case "h": return .oneToTwelve
            case "K": return .zeroToEleven
            case "H": return .zeroToTwentyThree
            case "k": return .oneToTwentyFour
            default: continue
            }
        }
        return .zeroToTwentyThree
    }
}
