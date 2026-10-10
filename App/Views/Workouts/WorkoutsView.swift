import SwiftUI
import SwiftData
import Core

enum WorkoutEditorTarget: Identifiable {
    case new
    case existing(Workout)

    var id: String {
        switch self {
        case .new: return "new"
        case .existing(let workout): return workout.id.uuidString
        }
    }

    var workout: Workout? {
        if case .existing(let workout) = self { return workout }
        return nil
    }
}

/// Workouts tab: saved workouts, start or edit (SPEC 2, 5.1).
struct WorkoutsView: View {
    @Environment(AppModel.self) private var appModel
    @Query(sort: \Workout.createdAt) private var workouts: [Workout]
    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]
    @AppStorage(SettingsKey.unit) private var unitRaw = SettingsDefault.unit

    @State private var editorTarget: WorkoutEditorTarget?
    @State private var pendingStart: Workout?

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .bottom) {
                        ScreenTitle("Workouts")
                        Spacer()
                        Button {
                            editorTarget = .new
                        } label: {
                            Image(systemName: "plus")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Theme.ink, in: Circle())
                        }
                        .accessibilityLabel("New workout")
                    }
                    .padding(.top, 8)

                    if let active = appModel.active {
                        resumeBanner(active)
                    }

                    if workouts.isEmpty {
                        Text("No workouts yet. Tap + to create one.")
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    }

                    ForEach(workouts) { workout in
                        WorkoutCard(workout: workout, lastDone: lastDone(workout), unit: unit,
                                    onStart: { start(workout) },
                                    onEdit: { editorTarget = .existing(workout) })
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(Theme.ground)
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $editorTarget) { target in
            WorkoutEditorView(workout: target.workout)
        }
        .alert("A workout is already in progress", isPresented: Binding(
            get: { pendingStart != nil },
            set: { if !$0 { pendingStart = nil } }
        )) {
            Button("Resume current workout") {
                pendingStart = nil
                appModel.showingSession = true
            }
            Button("Discard it and start", role: .destructive) {
                if let workout = pendingStart {
                    appModel.discard()
                    appModel.start(workout)
                }
                pendingStart = nil
            }
            Button("Cancel", role: .cancel) { pendingStart = nil }
        } message: {
            Text("Finish or discard it before starting another.")
        }
    }

    private func start(_ workout: Workout) {
        if appModel.active != nil {
            pendingStart = workout
        } else {
            appModel.start(workout)
        }
    }

    private func lastDone(_ workout: Workout) -> Date? {
        sessions.first { $0.workoutID == workout.id }?.startedAt
    }

    private func resumeBanner(_ active: ActiveSession) -> some View {
        let done = active.exercises.filter { ex in ex.working.contains { $0 != nil } }.count
        return Button {
            appModel.showingSession = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("WORKOUT IN PROGRESS")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(light: 0xF6B48F, dark: 0xF6B48F))
                    Text("\(active.workoutName) · \(done) of \(active.exercises.count) exercises")
                        .font(.headline)
                }
                Spacer()
                Text("Resume").font(.headline)
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(Color(light: 0x16171A, dark: 0x2A2C30), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct WorkoutCard: View {
    let workout: Workout
    let lastDone: Date?
    let unit: WeightUnit
    let onStart: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(workout.name)
                    .font(.system(size: 26, weight: .bold).width(.condensed))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if let lastDone {
                    Text("Last: " + lastDone.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
            }
            VStack(alignment: .leading, spacing: 7) {
                ForEach(workout.sortedItems) { item in
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.exerciseName).foregroundStyle(Theme.ink)
                        Spacer()
                        Text(detail(item)).foregroundStyle(Theme.muted)
                    }
                    .font(.subheadline)
                }
                if workout.sortedItems.isEmpty {
                    Text("No exercises").font(.subheadline).foregroundStyle(Theme.muted)
                }
            }
            HStack(spacing: 10) {
                Button("Start workout", action: onStart)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(workout.sortedItems.isEmpty)
                Button("Edit", action: onEdit)
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .card()
    }

    private func detail(_ item: WorkoutItem) -> String {
        let sets = item.kind == .timed ? "\(item.sets) × \(item.durationSec)s" : "\(item.sets) × \(item.reps)"
        let weight = WeightFormat.text(lb: item.weightLb, bodyweight: item.equipment == .bodyweight, unit: unit)
        return "\(sets) · \(weight)"
    }
}
