import SwiftUI
import SwiftData
import Charts
import Core

/// Progress tab: per-exercise chart and workouts per week (SPEC 7).
struct ProgressScreen: View {
    @Query(sort: \Session.startedAt) private var sessions: [Session]
    @AppStorage(SettingsKey.unit) private var unitRaw = SettingsDefault.unit

    @State private var range: ProgressRange = .threeMonths
    @State private var exerciseName = ""

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    private var exerciseNames: [String] {
        Set(sessions.flatMap { $0.sortedEntries.map(\.exerciseName) }).sorted()
    }

    private var selectedName: String {
        exerciseNames.contains(exerciseName) ? exerciseName : (exerciseNames.first ?? "")
    }

    private var selectedKind: ExerciseKind {
        for session in sessions.reversed() {
            if let entry = session.sortedEntries.first(where: { $0.exerciseName == selectedName }) {
                return entry.kind
            }
        }
        return .reps
    }

    private var points: [ProgressPoint] {
        var result: [ProgressPoint] = []
        for session in sessions {
            for entry in session.sortedEntries where entry.exerciseName == selectedName {
                if let value = ProgressMath.value(for: entry.dto) {
                    let shown = entry.kind == .timed ? value : unit.display(fromLb: value)
                    result.append(ProgressPoint(date: session.startedAt, value: shown))
                }
            }
        }
        return ProgressMath.filter(result, range: range, now: Date())
    }

    private var weeks: [WeekCount] {
        ProgressMath.weeklyCounts(dates: sessions.map(\.startedAt), range: range, now: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenTitle("Progress").padding(.top, 8)
                    Picker("Range", selection: $range) {
                        ForEach(ProgressRange.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if sessions.isEmpty {
                        Text("Finish a workout to see your progress here.")
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                            .card()
                    } else {
                        exerciseCard
                        weeklyCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.ground)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var exerciseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Exercise", selection: Binding(get: { selectedName }, set: { exerciseName = $0 })) {
                ForEach(exerciseNames, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(Theme.ink)

            let values = points.map(\.value)
            if let last = values.last, let first = values.first {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(selectedKind == .timed ? "Best set duration" : "Working weight")
                            .font(.footnote).foregroundStyle(Theme.muted)
                        Text(format(last))
                            .font(.system(size: 34, weight: .bold).width(.condensed))
                    }
                    Spacer()
                    Text(change(first: first, last: last))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accentSoftText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 8))
                }
                Chart(points) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Value", point.value))
                        .foregroundStyle(Theme.accent)
                        .interpolationMethod(.linear)
                    if points.count <= 40 {
                        PointMark(x: .value("Date", point.date), y: .value("Value", point.value))
                            .foregroundStyle(Theme.accent)
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 200)
                .accessibilityLabel("\(selectedName) from \(format(first)) to \(format(last))")
            } else {
                Text("No sessions for this exercise in this range.")
                    .foregroundStyle(Theme.muted)
                    .padding(.vertical, 20)
            }
        }
        .card()
    }

    private var weeklyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Workouts per week").font(.headline)
                Spacer()
                Text(String(format: "%.1f per week", average)).font(.footnote).foregroundStyle(Theme.muted)
            }
            Chart(weeks) { week in
                BarMark(x: .value("Week", week.weekStart, unit: .weekOfYear),
                        y: .value("Workouts", week.count))
                    .foregroundStyle(Theme.accent)
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4))
            }
            .frame(height: 160)
        }
        .card()
    }

    private var average: Double {
        guard !weeks.isEmpty else { return 0 }
        return Double(weeks.reduce(0) { $0 + $1.count }) / Double(weeks.count)
    }

    private func format(_ value: Double) -> String {
        if selectedKind == .timed { return "\(Int(value))s" }
        return WeightFormat.number(value) + " " + unit.rawValue
    }

    private func change(first: Double, last: Double) -> String {
        let diff = last - first
        if diff == 0 { return "No change" }
        let sign = diff > 0 ? "+" : "−"
        let amount = selectedKind == .timed ? "\(Int(abs(diff)))s" : WeightFormat.number(abs(diff)) + " " + unit.rawValue
        return sign + amount
    }
}
