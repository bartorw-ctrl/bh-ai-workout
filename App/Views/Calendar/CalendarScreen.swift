import SwiftUI
import SwiftData
import Core

/// Calendar tab: month view of completed workouts (SPEC 6).
struct CalendarScreen: View {
    @Query(sort: \Session.startedAt) private var sessions: [Session]
    @AppStorage(SettingsKey.unit) private var unitRaw = SettingsDefault.unit

    @State private var month: Date = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
    @State private var selectedDay: Date? = Calendar.current.startOfDay(for: Date())

    private let calendar = Calendar.current
    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    private var sessionDays: Set<Date> {
        Set(sessions.map { calendar.startOfDay(for: $0.startedAt) })
    }

    private var selectedSessions: [Session] {
        guard let selectedDay else { return [] }
        return sessions.filter { calendar.isDate($0.startedAt, inSameDayAs: selectedDay) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenTitle("Calendar").padding(.top, 8)
                    monthCard
                    if let selectedDay {
                        if selectedSessions.isEmpty {
                            Text("No workout logged on \(selectedDay.formatted(.dateTime.month(.abbreviated).day())).")
                                .foregroundStyle(Theme.muted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .card()
                        }
                        ForEach(selectedSessions) { session in
                            SessionSummaryCard(session: session, unit: unit)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.ground)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var monthCard: some View {
        VStack(spacing: 6) {
            HStack {
                Button { shiftMonth(-1) } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Previous month")
                Spacer()
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.headline)
                Spacer()
                Button { shiftMonth(1) } label: {
                    Image(systemName: "chevron.right").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Next month")
            }
            .foregroundStyle(Theme.ink)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }
                ForEach(Array(dayCells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayButton(day)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }

            HStack(spacing: 16) {
                legend(fill: Theme.accent, stroke: nil, text: "Workout logged")
                legend(fill: .clear, stroke: Theme.ink, text: "Today")
                Spacer()
            }
            .padding(.top, 6)
        }
        .card()
    }

    private func dayButton(_ day: Date) -> some View {
        let hasSession = sessionDays.contains(day)
        let isToday = calendar.isDateInToday(day)
        let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let number = calendar.component(.day, from: day)
        return Button {
            selectedDay = day
        } label: {
            Text("\(number)")
                .font(.body.monospacedDigit().weight(hasSession || isToday ? .semibold : .regular))
                .foregroundStyle(hasSession ? Color.white : Theme.ink)
                .frame(width: 40, height: 40)
                .background(Circle().fill(hasSession ? Theme.accent : Color.clear))
                .overlay(Circle().stroke(isToday && !hasSession ? Theme.ink : Color.clear, lineWidth: 2))
                .padding(2)
                .overlay(Circle().stroke(isSelected ? Theme.ink : Color.clear, lineWidth: 2))
                .frame(height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(date: .long, time: .omitted)
                            + (hasSession ? ", workout logged" : "") + (isToday ? ", today" : ""))
    }

    private func legend(fill: Color, stroke: Color?, text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(fill)
                .overlay(Circle().stroke(stroke ?? .clear, lineWidth: 2))
                .frame(width: 12, height: 12)
            Text(text).font(.caption).foregroundStyle(Theme.muted)
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// Leading blanks then each day of the month.
    private var dayCells: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let weekday = calendar.component(.weekday, from: month)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            cells.append(calendar.date(byAdding: .day, value: day - 1, to: month))
        }
        return cells
    }

    private func shiftMonth(_ delta: Int) {
        if let next = calendar.date(byAdding: .month, value: delta, to: month) {
            month = next
            selectedDay = nil
        }
    }
}

/// One session's details on the calendar (SPEC 6.2).
struct SessionSummaryCard: View {
    let session: Session
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.startedAt.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                    Text(session.workoutName)
                        .font(.system(size: 26, weight: .bold).width(.condensed))
                        .foregroundStyle(Theme.ink)
                    Text(timeLabel)
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                NavigationLink {
                    SessionDetailView(session: session)
                } label: {
                    Text("Edit")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 40)
                        .overlay(Capsule().stroke(Theme.line))
                }
                .foregroundStyle(Theme.ink)
            }
            ForEach(session.sortedEntries) { entry in
                Divider()
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.exerciseName).font(.subheadline.weight(.medium))
                        Text(setsLabel(entry)).font(.footnote).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Text(WeightFormat.text(lb: entry.weightLb, bodyweight: entry.equipment == .bodyweight, unit: unit))
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .card()
    }

    private var timeLabel: String {
        let minutes = max(1, Int(session.endedAt.timeIntervalSince(session.startedAt) / 60))
        return session.startedAt.formatted(date: .omitted, time: .shortened) + " · \(minutes) min"
    }

    private func setsLabel(_ entry: SessionEntry) -> String {
        let suffix = entry.kind == .timed ? "s" : ""
        let working = entry.sortedSets.filter { !$0.isWarmup }.map { "\($0.value)\(suffix)" }
        var text = working.joined(separator: " · ")
        if entry.kind == .reps && !working.isEmpty { text += " reps" }
        let warmups = entry.sortedSets.filter(\.isWarmup).count
        if warmups > 0 { text += " (+\(warmups) warm-up)" }
        return text
    }
}

/// Edit or delete a past session (SPEC 6.3, 6.4). Edits change history only.
struct SessionDetailView: View {
    let session: Session

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.unit) private var unitRaw = SettingsDefault.unit
    @State private var confirmDelete = false

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    var body: some View {
        List {
            Section {
                LabeledContent("Date", value: session.startedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Duration",
                               value: "\(max(1, Int(session.endedAt.timeIntervalSince(session.startedAt) / 60))) min")
            } footer: {
                Text("Changes here only update this session's history. Saved workout weights stay the same.")
            }
            ForEach(session.sortedEntries) { entry in
                Section(entry.exerciseName) {
                    EntryWeightRow(entry: entry, unit: unit)
                    ForEach(entry.sortedSets) { log in
                        SetLogRow(log: log, label: label(for: log, in: entry), timed: entry.kind == .timed)
                    }
                }
            }
            Section {
                Button("Delete session", role: .destructive) { confirmDelete = true }
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(session.workoutName)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            if !session.isDeleted { try? context.save() }
        }
        .confirmationDialog("Delete this session?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete session", role: .destructive, action: delete)
        } message: {
            Text("It will be removed from your history and from Apple Health.")
        }
    }

    private func label(for log: SetLog, in entry: SessionEntry) -> String {
        let sameKind = entry.sortedSets.filter { $0.isWarmup == log.isWarmup }
        let number = (sameKind.firstIndex { $0.id == log.id } ?? 0) + 1
        return log.isWarmup ? "Warm-up \(number)" : "Set \(number)"
    }

    private func delete() {
        if let healthID = session.healthKitID {
            Task { await HealthKitManager.shared.deleteWorkout(id: healthID) }
        }
        // Leave the screen first so nothing reads the session after it is deleted.
        let target = session
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            context.delete(target)
            try? context.save()
        }
    }
}

struct EntryWeightRow: View {
    @Bindable var entry: SessionEntry
    let unit: WeightUnit

    var body: some View {
        Stepper {
            LabeledContent(entry.equipment == .bodyweight ? "Added weight" : "Weight",
                           value: WeightFormat.text(lb: entry.weightLb, bodyweight: entry.equipment == .bodyweight, unit: unit))
        } onIncrement: {
            entry.weightLb = WeightFormat.step(entry.weightLb, by: 1, unit: unit)
        } onDecrement: {
            entry.weightLb = WeightFormat.step(entry.weightLb, by: -1, unit: unit)
        }
    }
}

struct SetLogRow: View {
    @Bindable var log: SetLog
    let label: String
    let timed: Bool

    var body: some View {
        Stepper(value: $log.value, in: 0...(timed ? 3600 : 999), step: timed ? 5 : 1) {
            LabeledContent(label, value: timed ? "\(log.value)s" : "\(log.value) reps")
        }
    }
}
