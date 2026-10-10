import Foundation

/// Chart time filter (SPEC 7.3).
public enum ProgressRange: String, CaseIterable, Identifiable, Sendable {
    case oneMonth = "1M"
    case threeMonths = "3M"
    case oneYear = "1Y"
    case all = "All"

    public var id: String { rawValue }

    /// Earliest date included, or nil for All.
    public func startDate(now: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .oneMonth: return calendar.date(byAdding: .month, value: -1, to: now)
        case .threeMonths: return calendar.date(byAdding: .month, value: -3, to: now)
        case .oneYear: return calendar.date(byAdding: .year, value: -1, to: now)
        case .all: return nil
        }
    }
}

public struct ProgressPoint: Equatable, Identifiable, Sendable {
    public var date: Date
    public var value: Double
    public var id: Date { date }

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

public struct WeekCount: Equatable, Identifiable, Sendable {
    public var weekStart: Date
    public var count: Int
    public var id: Date { weekStart }

    public init(weekStart: Date, count: Int) {
        self.weekStart = weekStart
        self.count = count
    }
}

public enum ProgressMath {
    public static func filter(_ points: [ProgressPoint], range: ProgressRange, now: Date,
                              calendar: Calendar = .current) -> [ProgressPoint] {
        let sorted = points.sorted { $0.date < $1.date }
        guard let start = range.startDate(now: now, calendar: calendar) else { return sorted }
        return sorted.filter { $0.date >= start }
    }

    /// Value charted for one session entry (SPEC 7.1): weight for rep exercises, best set duration for timed.
    public static func value(for entry: SessionEntryDTO) -> Double? {
        let working = entry.sets.filter { !$0.isWarmup }
        switch entry.kind {
        case .reps:
            return working.isEmpty ? nil : entry.weightLb
        case .timed:
            return working.map(\.value).max().map(Double.init)
        }
    }

    /// Completed workouts per calendar week, oldest first, including empty weeks (SPEC 7.2).
    public static func weeklyCounts(dates: [Date], range: ProgressRange, now: Date,
                                    calendar: Calendar = .current) -> [WeekCount] {
        guard let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
        let firstDate: Date
        if let start = range.startDate(now: now, calendar: calendar) {
            firstDate = start
        } else if let earliest = dates.min() {
            firstDate = earliest
        } else {
            firstDate = now
        }
        guard var week = calendar.dateInterval(of: .weekOfYear, for: firstDate)?.start else { return [] }

        var counts: [Date: Int] = [:]
        for date in dates {
            if let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start {
                counts[start, default: 0] += 1
            }
        }
        var result: [WeekCount] = []
        while week <= currentWeek {
            result.append(WeekCount(weekStart: week, count: counts[week] ?? 0))
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: week) else { break }
            week = next
        }
        return result
    }
}
