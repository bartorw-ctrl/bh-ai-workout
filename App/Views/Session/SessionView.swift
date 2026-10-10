import SwiftUI
import SwiftData
import Core

/// The screen used during a workout (SPEC 5).
struct SessionView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.unit) private var unitRaw = SettingsDefault.unit
    @AppStorage(SettingsKey.restSeconds) private var restSeconds = SettingsDefault.restSeconds

    @State private var confirmDiscard = false
    @State private var confirmFinish = false

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    var body: some View {
        NavigationStack {
            if let session = appModel.active {
                content(session)
            } else {
                Color.clear
            }
        }
    }

    private func content(_ session: ActiveSession) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(Array(session.exercises.enumerated()), id: \.element.id) { index, exercise in
                    ExerciseCard(exercise: exercise, index: index, session: session, now: appModel.now, unit: unit,
                                 onTapWorking: { set in
                                     appModel.update { $0.tapWorking(exercise: index, set: set, now: Date(), restSeconds: restSeconds) }
                                 },
                                 onTapWarmup: { set in
                                     appModel.update { $0.tapWarmup(exercise: index, set: set) }
                                 },
                                 onWeight: { steps in
                                     appModel.update { $0.changeWeight(exercise: index, steps: steps, unit: unit) }
                                 })
                }
                Text("Tap a circle to log the set. Tap again to take off a rep. Timed sets count down — tap while running to stop early.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(Theme.ground)
        .safeAreaInset(edge: .bottom) {
            bottomBar(session)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                HStack(spacing: 4) {
                    Button {
                        appModel.showingSession = false
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .accessibilityLabel("Minimize workout")
                    Button("Discard", role: .destructive) { confirmDiscard = true }
                        .foregroundStyle(Theme.destructive)
                }
            }
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(session.workoutName.uppercased())
                        .font(.system(size: 20, weight: .bold).width(.condensed))
                    Text(DurationFormat.clock(Int(appModel.now.timeIntervalSince(session.startedAt))))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(Theme.muted)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Finish") { confirmFinish = true }
                    .fontWeight(.semibold)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
            }
        }
        .confirmationDialog("Discard this workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard workout", role: .destructive) { appModel.discard() }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("Nothing from this session will be saved.")
        }
        .alert("Finish workout?", isPresented: $confirmFinish) {
            Button("Finish and save") { appModel.finish(context: context) }
            Button("Back to workout", role: .cancel) {}
        } message: {
            Text("\(session.loggedSetCount) sets logged. It will be added to your calendar\(AppSettings.healthEnabled ? " and Apple Health" : ""), and today’s weights saved for next time.")
        }
    }

    @ViewBuilder
    private func bottomBar(_ session: ActiveSession) -> some View {
        if let remaining = session.restRemaining(at: appModel.now) {
            RestBar(remaining: remaining, total: session.restTotalSec,
                    onAdd: { appModel.update { $0.addRest(seconds: 30, now: Date()) } },
                    onSkip: { appModel.update { $0.skipRest() } })
        } else if appModel.isRestOverShowing {
            HStack(spacing: 12) {
                Image(systemName: "speaker.wave.2.fill").font(.title3)
                Text("Rest over — next set").font(.headline)
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .accessibilityAddTraits(.updatesFrequently)
        }
    }
}

struct RestBar: View {
    let remaining: Int
    let total: Int
    let onAdd: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text("REST")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(light: 0xF6B48F, dark: 0xF6B48F))
                    Text(DurationFormat.clock(remaining))
                        .font(.system(size: 40, weight: .bold).width(.condensed).monospacedDigit())
                }
                Spacer()
                Button("+30s", action: onAdd)
                    .font(.headline)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .overlay(Capsule().stroke(Color.white.opacity(0.4)))
                Button("Skip", action: onSkip)
                    .font(.headline)
                    .foregroundStyle(Color(light: 0x16171A, dark: 0x16171A))
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(Color.white, in: Capsule())
            }
            ProgressView(value: Double(remaining), total: Double(max(total, 1)))
                .tint(Color(light: 0xE8590C, dark: 0xE8590C))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(Color(light: 0x16171A, dark: 0x2A2C30))
    }
}

struct ExerciseCard: View {
    let exercise: ActiveExercise
    let index: Int
    let session: ActiveSession
    let now: Date
    let unit: WeightUnit
    let onTapWorking: (Int) -> Void
    let onTapWarmup: (Int) -> Void
    let onWeight: (Int) -> Void

    private let columns = [GridItem(.adaptive(minimum: 60), spacing: 10, alignment: .top)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name).font(.headline).foregroundStyle(Theme.ink)
                    Text(caption).font(.footnote).foregroundStyle(Theme.muted)
                }
                Spacer()
                HStack(spacing: 0) {
                    Button { onWeight(-1) } label: {
                        Image(systemName: "minus").frame(width: 40, height: 44)
                    }
                    .accessibilityLabel("Decrease weight")
                    Text(WeightFormat.text(lb: exercise.weightLb, bodyweight: exercise.isBodyweight, unit: unit))
                        .font(.system(size: 20, weight: .bold).width(.condensed).monospacedDigit())
                        .frame(minWidth: 70)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Button { onWeight(1) } label: {
                        Image(systemName: "plus").frame(width: 40, height: 44)
                    }
                    .accessibilityLabel("Increase weight")
                }
                .foregroundStyle(Theme.ink)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(exercise.warmups.indices, id: \.self) { set in
                    SetCircle(model: warmupModel(set)) { onTapWarmup(set) }
                }
                ForEach(exercise.working.indices, id: \.self) { set in
                    SetCircle(model: workingModel(set)) { onTapWorking(set) }
                }
            }
        }
        .card()
    }

    private var caption: String {
        Summary.sets(kind: exercise.kind, sets: exercise.working.count, reps: exercise.targetReps,
                     durationSec: exercise.durationSec, warmupSets: exercise.warmups.count,
                     warmupReps: exercise.warmupReps)
    }

    private func warmupModel(_ set: Int) -> SetCircle.Model {
        let value = exercise.warmups[set]
        return SetCircle.Model(label: String(value ?? exercise.warmupReps),
                               caption: "Warm-up",
                               style: value == nil ? .emptyWarmup : .warmupDone,
                               size: 46,
                               accessibility: "Warm-up \(set + 1), " + (value.map { "\($0) reps" } ?? "not done"))
    }

    private func workingModel(_ set: Int) -> SetCircle.Model {
        let value = exercise.working[set]
        let timed = exercise.kind == .timed
        let suffix = timed ? "s" : ""
        if let running = session.running, running.exerciseIndex == index, running.setIndex == set {
            let left = running.remaining(at: now)
            return SetCircle.Model(label: "\(left)s", caption: "Set \(set + 1)", style: .running, size: 58,
                                   accessibility: "Set \(set + 1), running, \(left) seconds left")
        }
        guard let value else {
            return SetCircle.Model(label: "\(exercise.workingTarget)\(suffix)", caption: "Set \(set + 1)",
                                   style: .empty, size: 58, accessibility: "Set \(set + 1), not done")
        }
        return SetCircle.Model(label: "\(value)\(suffix)", caption: "Set \(set + 1)",
                               style: value >= exercise.workingTarget ? .done : .partial, size: 58,
                               accessibility: "Set \(set + 1), done, \(value)\(timed ? " seconds" : " reps")")
    }
}

/// One tappable set circle (SPEC 5.3–5.5).
struct SetCircle: View {
    enum Style {
        case empty, emptyWarmup, done, partial, warmupDone, running
    }

    struct Model {
        var label: String
        var caption: String
        var style: Style
        var size: CGFloat
        var accessibility: String
    }

    let model: Model
    let action: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Button(action: action) {
                Text(model.label)
                    .font(.system(size: model.label.count > 3 ? 15 : 19, weight: .semibold).monospacedDigit())
                    .foregroundStyle(foreground)
                    .frame(width: model.size, height: model.size)
                    .background(Circle().fill(fill))
                    .overlay(border)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.accessibility)
            Text(model.caption)
                .font(.caption2)
                .foregroundStyle(Theme.muted)
        }
        .frame(minWidth: 60)
    }

    private var fill: Color {
        switch model.style {
        case .empty, .emptyWarmup, .running: return Theme.card
        case .done: return Theme.accent
        case .partial: return Theme.ink
        case .warmupDone: return Theme.accentSoft
        }
    }

    private var foreground: Color {
        switch model.style {
        case .empty, .emptyWarmup: return Theme.muted
        case .done: return .white
        case .partial: return Theme.card
        case .warmupDone: return Theme.accentSoftText
        case .running: return Theme.accent
        }
    }

    @ViewBuilder
    private var border: some View {
        switch model.style {
        case .empty:
            Circle().stroke(Theme.emptyRing, lineWidth: 2)
        case .emptyWarmup:
            Circle().stroke(Theme.emptyRing, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
        case .running:
            Circle().stroke(Theme.accent, lineWidth: 3)
        case .done, .partial, .warmupDone:
            EmptyView()
        }
    }
}
