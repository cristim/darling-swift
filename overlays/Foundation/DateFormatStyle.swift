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

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

// Darling 1/6: upstream imports swift-foundation's `_FoundationICU`, which vendors ICU 72 or
// newer. Darling has ICU 66.1 already, exposed by `shims/DarlingICU.h`. See DARLING-CHANGES.md.
internal import DarlingICU

// MARK: Date Extensions

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date {
    /// Converts `self` to its textual representation that contains both the date and time parts. The exact format depends on the user's preferences.
    /// - Parameters:
    ///   - date: The style for describing the date part.
    ///   - time: The style for describing the time part.
    /// - Returns: A `String` describing `self`.
    public func formatted(date: FormatStyle.DateStyle, time: FormatStyle.TimeStyle) -> String {
        let f = FormatStyle(date: date, time: time)
        return f.format(self)
    }

    public func formatted() -> String {
        self.formatted(Date.FormatStyle(date: .numeric, time: .shortened))
    }
}

// MARK: DateFieldCollection

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.FormatStyle {
    internal struct DateFieldCollection : Codable, Hashable {
        var era: Symbol.SymbolType.EraOption?
        var year: Symbol.SymbolType.YearOption?
        var quarter: Symbol.SymbolType.QuarterOption?
        var month: Symbol.SymbolType.MonthOption?
        var week: Symbol.SymbolType.WeekOption?
        var day: Symbol.SymbolType.DayOption?
        var dayOfYear: Symbol.SymbolType.DayOfYearOption?
        var weekday: Symbol.SymbolType.WeekdayOption?
        var dayPeriod: Symbol.SymbolType.DayPeriodOption?
        var hour: Symbol.SymbolType.HourOption?
        var minute: Symbol.SymbolType.MinuteOption?
        var second: Symbol.SymbolType.SecondOption?
        var secondFraction: Symbol.SymbolType.SecondFractionOption?
        var timeZoneSymbol: Symbol.SymbolType.TimeZoneSymbolOption?

        // Swap regular hour for conversational-style hour option if needed
        func preferredHour(withLocale locale: Locale?) -> Symbol.SymbolType.HourOption? {
            guard let hour, let locale else {
                return nil
            }

            var showingDayPeriod: Bool
            switch locale.hourCycle {
            case .zeroToEleven:
                showingDayPeriod = true
            case .oneToTwelve:
                showingDayPeriod = true
            case .zeroToTwentyThree:
                showingDayPeriod = false
            case .oneToTwentyFour:
                showingDayPeriod = false
            }

            // default options (template "J" or "j") may display the hour as
            // 12-hour and 24-hour depending on regional preferences, while
            // conversational options (template "C") always shows 12-hour.
            // Only proceed to override J/j with C if displaying 12-hour.
            guard showingDayPeriod else {
                return hour
            }

            var preferredHour: Symbol.SymbolType.HourOption?

            if locale.language.languageCode == .chinese && locale.region == .taiwan {
                switch hour {
                case .defaultDigitsWithAbbreviatedAMPM:
                    preferredHour = .conversationalDefaultDigitsWithAbbreviatedAMPM
                case .twoDigitsWithAbbreviatedAMPM:
                    preferredHour = .conversationalTwoDigitsWithAbbreviatedAMPM
                case .defaultDigitsWithWideAMPM:
                    preferredHour = .conversationalDefaultDigitsWithWideAMPM
                case .twoDigitsWithWideAMPM:
                    preferredHour = .conversationalTwoDigitsWithWideAMPM
                case .defaultDigitsWithNarrowAMPM:
                    preferredHour = .conversationalDefaultDigitsWithNarrowAMPM
                case .twoDigitsWithNarrowAMPM:
                    preferredHour = .conversationalTwoDigitsWithNarrowAMPM
                case .defaultDigitsNoAMPM, .twoDigitsNoAMPM, .conversationalDefaultDigitsWithAbbreviatedAMPM, .conversationalTwoDigitsWithAbbreviatedAMPM, .conversationalDefaultDigitsWithWideAMPM, .conversationalTwoDigitsWithWideAMPM, .conversationalDefaultDigitsWithNarrowAMPM, .conversationalTwoDigitsWithNarrowAMPM:
                    preferredHour = hour
                }
            } else {
                preferredHour = hour
            }

            return preferredHour
        }

        func formatterTemplate(overridingDayPeriodWithLocale locale: Locale?) -> String {
            var ret = ""
            ret.append(era?.rawValue ?? "")
            ret.append(year?.rawValue ?? "")
            ret.append(quarter?.rawValue ?? "")
            ret.append(month?.rawValue ?? "")
            ret.append(week?.rawValue ?? "")
            ret.append(day?.rawValue ?? "")
            ret.append(dayOfYear?.rawValue ?? "")
            ret.append(weekday?.rawValue ?? "")
            ret.append(dayPeriod?.rawValue ?? "")
            let preferredHour = preferredHour(withLocale: locale)
            ret.append(preferredHour?.rawValue ?? "")
            ret.append(minute?.rawValue ?? "")
            ret.append(second?.rawValue ?? "")
            ret.append(secondFraction?.rawValue ?? "")
            ret.append(timeZoneSymbol?.rawValue ?? "")
            return ret
        }

        // Only contains fields greater or equal than `day`, excluding time parts.
        var dateFields: Self {
            DateFieldCollection(era: era, year: year, quarter: quarter, month: month, week: week, day: day, dayOfYear: dayOfYear, weekday: weekday, dayPeriod: dayPeriod)
        }

        mutating func add(_ rhs: Self) {
            era = rhs.era ?? era
            year = rhs.year ?? year
            quarter = rhs.quarter ?? quarter
            month = rhs.month ?? month
            week = rhs.week ?? week
            day = rhs.day ?? day
            dayOfYear = rhs.dayOfYear ?? dayOfYear
            weekday = rhs.weekday ?? weekday
            dayPeriod = rhs.dayPeriod ?? dayPeriod
            hour = rhs.hour ?? hour
            minute = rhs.minute ?? minute
            second = rhs.second ?? second
            secondFraction = rhs.secondFraction ?? secondFraction
            timeZoneSymbol = rhs.timeZoneSymbol ?? timeZoneSymbol
        }

        var empty: Bool {
            if era == nil &&
                year == nil &&
                quarter == nil &&
                month == nil &&
                week == nil &&
                day == nil &&
                dayOfYear == nil &&
                weekday == nil &&
                dayPeriod == nil &&
                hour == nil &&
                minute == nil &&
                second == nil &&
                secondFraction == nil &&
                timeZoneSymbol == nil {
                return true
            } else {
                return false
            }
        }

        func collection(date len: DateStyle)-> DateFieldCollection {
            var new = self
            if len == .omitted {
                return new
            }

            new.day = .defaultDigits
            new.year = .defaultDigits
            if len == .numeric {
                new.month = .defaultDigits
            } else if len == .abbreviated {
                new.month = .abbreviated
            } else if len == .long {
                new.month = .wide
            } else if len == .complete {
                new.month = .wide
                new.weekday = .wide
            }
            return new
        }

        func collection(time len: TimeStyle) -> DateFieldCollection {
            var new = self
            if len == .omitted {
                return new
            }

            new.hour = .defaultDigitsWithAbbreviatedAMPM
            new.minute = .twoDigits
            if len == .standard {
                new.second = .twoDigits
            } else if len == .complete {
                new.second = .twoDigits
                new.timeZoneSymbol = .shortSpecificName
            }
            return new
        }
    }
}

// MARK: Date.FormatStyle Definition

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date {
    /// Strategies for formatting a `Date`.
    public struct FormatStyle : Sendable {

        var _symbols: DateFieldCollection?
        var symbols: DateFieldCollection {
            if let _symbols {
                return _symbols
            }

            return DateFieldCollection().collection(date: .numeric).collection(time: .shortened)
        }

        var _dateStyle: DateStyle? // For accessing locale pref's custom date format

        /// The locale to use when formatting date and time values.
        public var locale: Locale

        /// The time zone with which to specify date and time values.
        public var timeZone: TimeZone

        /// The calendar to use for date values.
        public var calendar: Calendar

        /// The capitalization formatting context used when formatting date and time values.
        public var capitalizationContext: FormatStyleCapitalizationContext

        // Darling 2/6: `attributed` returned Date.AttributedStyle, whose format() goes through
        // ICUDateFormatter.attributedFormat and so through udat_formatForFields. Attributed date
        // output is not supplied yet; the property is removed so its use is a compile error.

        var parseLenient: Bool = true

        /// Creates a new `FormatStyle` with the given configurations.
        /// - Parameters:
        ///   - date:  The date style for formatting the date.
        ///   - time:  The time style for formatting the date.
        ///   - locale: The locale to use when formatting date and time values.
        ///   - calendar: The calendar to use for date values.
        ///   - timeZone: The time zone with which to specify date and time values.
        ///   - capitalizationContext: The capitalization formatting context used when formatting date and time values.
        /// - Note: Always specify the date style, time style, or the date components to be included in the formatted string with the symbol modifiers. Otherwise, an empty string will be returned when you use the instance to format a `Date`.
        public init(date: DateStyle? = nil, time: TimeStyle? = nil, locale: Locale = .autoupdatingCurrent, calendar: Calendar = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent, capitalizationContext: FormatStyleCapitalizationContext = .unknown) {
            if let dateStyle = date, dateStyle != .omitted {
                _dateStyle = dateStyle
                _symbols = (_symbols ?? .init()).collection(date: dateStyle)
            }

            if let timeStyle = time, timeStyle != .omitted {
                _symbols = (_symbols ?? .init()).collection(time: timeStyle)
            }

            self.locale = locale
            self.calendar = calendar
            self.timeZone = timeZone
            self.capitalizationContext = capitalizationContext
        }

        private init(symbols: DateFieldCollection, dateStyle: DateStyle?, locale: Locale, timeZone: TimeZone, calendar: Calendar, capitalizationContext: FormatStyleCapitalizationContext) {
            self._symbols = symbols
            self._dateStyle = dateStyle
            self.locale = locale
            self.timeZone = timeZone
            self.calendar = calendar
            self.capitalizationContext = capitalizationContext
        }
    }

    // Darling 3/6: Date.AttributedStyle removed with the property above.
}

// Darling: its FormatStyle conformance goes with it.

// Darling 4/6: Date.FormatStyle.Attributed removed, same reason; `attributedStyle` goes with it.

// MARK: Symbol Modifiers

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.FormatStyle {
    /// Change the representation of the era in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func era(_ format: Symbol.Era = .abbreviated) -> Self {
        var new = self
        if new._symbols == nil {
            new._symbols = format.option == nil ? new.symbols : .init()
        }
        new._symbols?.era = format.option
        return new
    }

    /// Change the representation of the year in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func year(_ format: Symbol.Year = .defaultDigits) -> Self {
        var new = self
        if new._symbols == nil {
            new._symbols = format.option == nil ? new.symbols : .init()
        }
        new._symbols?.year = format.option
        return new
    }

    /// Change the representation of the quarter in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func quarter(_ format: Symbol.Quarter = .abbreviated) -> Self {
        var new = self
        if new._symbols == nil {
            new._symbols = format.option == nil ? new.symbols : .init()
        }
        new._symbols?.quarter = format.option
        return new
    }

    /// Change the representation of the month in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func month(_ format: Symbol.Month = .abbreviated) -> Self {
        var new = self
        if new._symbols == nil {
            new._symbols = format.option == nil ? new.symbols : .init()
        }
        new._symbols?.month = format.option
        return new
    }

    /// Change the representation of the week in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func week(_ format: Symbol.Week = .defaultDigits) -> Self {
        var new = self
        if new._symbols == nil {
            new._symbols = format.option == nil ? new.symbols : .init()
        }
        new._symbols?.week = format.option
        return new
    }

    /// Change the representation of the day of the month in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func day(_ format: Symbol.Day = .defaultDigits) -> Self {
        var new = self
        if new._symbols == nil {
            new._symbols = format.option == nil ? new.symbols : .init()
        }
        new._symbols?.day = format.option
        return new
    }

    /// Change the representation of the day of the year in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func dayOfYear(_ format: Symbol.DayOfYear = .defaultDigits) -> Self {
        var new = self
        if new._symbols == nil {
            new._symbols = format.option == nil ? new.symbols : .init()
        }
        new._symbols?.dayOfYear = format.option
        return new
    }

    /// Change the representation of the weekday in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func weekday(_ format: Symbol.Weekday = .abbreviated) -> Self {
        var new = self
        if new._symbols == nil {
            new._symbols = format.option == nil ? new.symbols : .init()
        }
        new._symbols?.weekday = format.option
        return new
    }

    /// Change the representation of the hour in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func hour(_ format: Symbol.Hour = .defaultDigits(amPM: .abbreviated)) -> Self {
        var new = self
        if new._symbols == nil {
            new._symbols = format.option == nil ? new.symbols : .init()
        }
        new._symbols?.hour = format.option
        return new
    }

    /// Change the representation of the minute in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func minute(_ format: Symbol.Minute = .defaultDigits) -> Self {
        var new = self
        if new._symbols == nil {
            new._symbols = format.option == nil ? new.symbols : .init()
        }
        new._symbols?.minute = format.option
        return new
    }

    /// Change the representation of the second in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func second(_ format: Symbol.Second = .defaultDigits) -> Self {
        var new = self
        if new._symbols == nil {
            new._symbols = format.option == nil ? new.symbols : .init()
        }
        new._symbols?.second = format.option
        return new
    }

    /// Change the representation of the second fraction in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func secondFraction(_ format: Symbol.SecondFraction) -> Self {
        var new = self
        if new._symbols == nil {
            new._symbols = format.option == nil ? new.symbols : .init()
        }
        new._symbols?.secondFraction = format.option
        return new
    }

    /// Change the representation of the time zone in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func timeZone(_ format: Symbol.TimeZone = .specificName(.short)) -> Self {
        var new = self
        if new._symbols == nil {
            new._symbols = format.option == nil ? new.symbols : .init()
        }
        new._symbols?.timeZoneSymbol = format.option
        return new
    }
}

// Darling: symbol modifiers for the removed Attributed type.

// MARK: FormatStyle Conformance

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.FormatStyle : FormatStyle {
    public func format(_ value: Date) -> String {
        // Darling: upstream goes through ICUDateFormatter, which is built on swift-foundation's
        // vendored ICU. DarlingDateFormatter is the same construction over Darling's ICU 66.
        guard let fm = DarlingDateFormatter.cached(for: self), let result = fm.format(value) else {
            return ""
        }
        return result
    }

    public func locale(_ locale: Locale) -> Self {
        var new = self
        new.locale = locale
        return new
    }
}

// MARK: ParseStrategy Conformance

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.FormatStyle : ParseStrategy {
    public func parse(_ value: String) throws -> Date {
        // Darling: as for format(_:) above.
        guard let fm = DarlingDateFormatter.cached(for: self) else {
            throw CocoaError(CocoaError.formatting, userInfo: [ NSDebugDescriptionErrorKey: "Error creating icu date formatter" ])
        }

        guard let date = fm.parse(value) else {
            // Darling: upstream calls parseError() from FoundationEssentials'
            // FormatParsingUtilities.swift, which needs BufferViewIterator and OutputBuffer that
            // this overlay does not carry. The same CocoaError is built here instead.
            let example = fm.format(Date.now)
            let described = example.map { "Cannot parse \(value). String should adhere to the specified format, such as \($0)" }
                ?? "Cannot parse \(value)."
            throw CocoaError(CocoaError.formatting, userInfo: [ NSDebugDescriptionErrorKey: described ])
        }

        return date
    }
}

// MARK: Codable+Hashable Conformance

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.FormatStyle : Codable, Hashable {

    enum CodingKeys: CodingKey {
        case symbols
        case locale
        case timeZone
        case calendar
        case capitalizationContext
        case dateStyle
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.symbols, forKey: .symbols)
        try container.encode(self.locale, forKey: .locale)
        try container.encode(self.timeZone, forKey: .timeZone)
        try container.encode(self.calendar, forKey: .calendar)
        try container.encode(self.capitalizationContext, forKey: .capitalizationContext)
        try container.encodeIfPresent(self._dateStyle, forKey: .dateStyle)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let symbols = try container.decode(DateFieldCollection.self, forKey: .symbols)
        let locale = try container.decode(Locale.self, forKey: .locale)
        let timeZone = try container.decode(TimeZone.self, forKey: .timeZone)
        let calendar = try container.decode(Calendar.self, forKey: .calendar)
        let context = try container.decode(FormatStyleCapitalizationContext.self, forKey: .capitalizationContext)
        let dateStyle = try container.decodeIfPresent(DateStyle.self, forKey: .dateStyle)
        self.init(symbols: symbols, dateStyle: dateStyle, locale: locale, timeZone: timeZone, calendar: calendar, capitalizationContext: context)
    }
}

// MARK: Date/Time Style

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.FormatStyle {
    /// Predefined date styles varied in lengths or the components included. The exact format depends on the locale.
    public struct DateStyle : Codable, Hashable, Sendable {

        /// Excludes the date part.
        public static let omitted: DateStyle = DateStyle(rawValue: 0)

        /// Shows date components in their numeric form. For example, "10/21/2015".
        public static let numeric: DateStyle = DateStyle(rawValue: 1)

        /// Shows date components in their abbreviated form if possible. For example, "Oct 21, 2015".
        public static let abbreviated: DateStyle = DateStyle(rawValue: 2)

        /// Shows date components in their long form if possible. For example, "October 21, 2015".
        public static let long: DateStyle = DateStyle(rawValue: 3)

        /// Shows the complete day. For example, "Wednesday, October 21, 2015".
        public static let complete: DateStyle = DateStyle(rawValue: 4)

        let rawValue : UInt
    }

    /// Predefined time styles varied in lengths or the components included. The exact format depends on the locale.
    public struct TimeStyle : Codable, Hashable, Sendable {

        /// Excludes the time part.
        public static let omitted: TimeStyle = TimeStyle(rawValue: 0)

        /// For example, `04:29 PM`, `16:29`.
        public static let shortened: TimeStyle = TimeStyle(rawValue: 1)

        /// For example, `4:29:24 PM`, `16:29:24`.
        public static let standard: TimeStyle = TimeStyle(rawValue: 2)

        /// For example, `4:29:24 PM PDT`, `16:29:24 GMT`.
        public static let complete: TimeStyle = TimeStyle(rawValue: 3)

        let rawValue : UInt
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.FormatStyle: ParseableFormatStyle {
    public var parseStrategy: Date.FormatStyle {
        return self
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == Date.FormatStyle {
    static var dateTime: Self { .init() }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension ParseableFormatStyle where Self == Date.FormatStyle {
    static var dateTime: Self { .init() }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension ParseStrategy where Self == Date.FormatStyle {
    @_disfavoredOverload
    static var dateTime: Self { .init() }
}

// Darling 5/6: DiscreteFormatStyle needs Calendar.bound(for:isLower:updateSchedule:), which
// needs Calendar.ComponentSet. That type is `package` in FoundationEssentials and Darling's
// CF-backed Calendar does not have it, so the conformance is a compile error rather than an
// approximated bound: a wrong bound makes SwiftUI views refresh late or too often.

// Darling: ICU field-to-attribute mapping, used only by the removed attributed paths. It also
// reaches UDateFormatField members that swift-foundation defines in its own ICU/ICU+Enums.swift.


@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension Date.FormatStyle : CustomConsumingRegexComponent {
    public typealias RegexOutput = Date
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Date)? {
        guard index < bounds.upperBound else {
            return nil
        }
        // Darling: as for format(_:) above. Ranged parsing is DarlingDateFormatter.parse(_:in:).
        guard let fmt = DarlingDateFormatter.cached(for: self) else {
            return nil
        }
        return fmt.parse(input, in: index..<bounds.upperBound)
    }
}

// Darling 6/6: _attributedStringFromPositions consumed ICUDateFormatter.AttributePosition.
