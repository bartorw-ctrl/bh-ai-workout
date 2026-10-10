import SwiftUI
import SwiftData
import Core

/// An exercise being configured in the editor, before it is saved.
struct ItemDraft: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var equipment: Equipment
    var kind: ExerciseKind
    var sets = ExerciseDefaults.sets
    var reps = ExerciseDefaults.reps
    var durationSec = ExerciseDefaults.durationSec
    var weightLb: Double
    var warmupSets = 0
    var warmupReps = ExerciseDefaults.warmupReps

    /// Defaults for a newly picked exercise (SPEC 3.4–3.6).
    init(exercise: Exercise) {
        name = exercise.name
        equipment = exercise.equipment
        kind = exercise.kind
        weightLb = ExerciseDefaults.weightLb(for: exercise.equipment)
    }

    init(item: WorkoutItem) {
        id = item.id
        name = item.exerciseName
        equipment = item.equipment
        kind = item.kind
        sets = item.sets
        reps = item.reps
        durationSec = item.durationSec
        weightLb = item.weightLb
        warmupSets = item.warmupSets
        warmupReps = item.warmupReps
    }
}

/// Add/Edit Workout (SPEC 2).
struct WorkoutEditorView: View {
    let workout: Workout?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.unit) private var unitRaw = SettingsDefault.unit

    @State private var name: String
    @State private var items: [ItemDraft]
    @State private var showPicker = false
    @State private var editingItem: ItemDraft?
    @State private var confirmDelete = false

    init(workout: Workout?) {
        self.workout = workout
        _name = State(initialValue: workout?.name ?? "")
        _items = State(initialValue: workout?.sortedItems.map(ItemDraft.init(item:)) ?? [])
    }

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            List {
                Section("Workout name") {
                    TextField("e.g. Full Body A", text: $name)
                        .font(.headline)
                }

                Section {
                    ForEach(items) { item in
                        Button {
                            editingItem = item
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name).font(.headline).foregroundStyle(Theme.ink)
                                Text(detail(item)).font(.footnote).foregroundStyle(Theme.muted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { items.remove(atOffsets: $0) }
                    .onMove { items.move(fromOffsets: $0, toOffset: $1) }

                    Button {
                        showPicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                            .font(.headline)
                            .foregroundStyle(Theme.accent)
                    }
                } header: {
                    HStack {
                        Text("Exercises")
                        Spacer()
                        if items.count > 1 {
                            EditButton().font(.footnote.weight(.semibold)).textCase(nil)
                        }
                    }
                } footer: {
                    if !items.isEmpty {
                        Text("Tap an exercise to change it. Swipe left to remove.")
                    }
                }

                if workout != nil {
                    Section {
                        Button("Delete workout", role: .destructive) {
                            confirmDelete = true
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(workout == nil ? "New Workout" : "Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(trimmedName.isEmpty)
                }
            }
            .sheet(isPresented: $showPicker) {
                ExercisePickerView { draft in
                    items.append(draft)
                }
            }
            .sheet(item: $editingItem) { item in
                NavigationStack {
                    ItemEditorView(draft: item, saveTitle: "Save") { updated in
                        if let index = items.firstIndex(where: { $0.id == updated.id }) {
                            items[index] = updated
                        }
                    }
                }
            }
            .confirmationDialog("Delete \(workout?.name ?? "workout")?", isPresented: $confirmDelete,
                                titleVisibility: .visible) {
                Button("Delete workout", role: .destructive, action: deleteWorkout)
            } message: {
                Text("The workout is removed. Past sessions stay in your calendar.")
            }
        }
    }

    private func detail(_ item: ItemDraft) -> String {
        let sets = Summary.sets(kind: item.kind, sets: item.sets, reps: item.reps, durationSec: item.durationSec,
                                warmupSets: item.warmupSets, warmupReps: item.warmupReps)
        let weight = WeightFormat.text(lb: item.weightLb, bodyweight: item.equipment == .bodyweight, unit: unit)
        return "\(sets) · \(weight)"
    }

    private func save() {
        let target: Workout
        if let workout {
            target = workout
        } else {
            target = Workout(name: trimmedName)
            context.insert(target)
        }
        target.name = trimmedName
        for old in target.items ?? [] {
            context.delete(old)
        }
        for (index, draft) in items.enumerated() {
            let item = WorkoutItem(id: draft.id, order: index, exerciseName: draft.name, equipment: draft.equipment,
                                   kind: draft.kind, sets: draft.sets, reps: draft.reps, durationSec: draft.durationSec,
                                   weightLb: draft.weightLb, warmupSets: draft.kind == .reps ? draft.warmupSets : 0,
                                   warmupReps: draft.warmupReps)
            context.insert(item)
            item.workout = target
        }
        try? context.save()
        dismiss()
    }

    private func deleteWorkout() {
        if let workout {
            context.delete(workout)
            try? context.save()
        }
        dismiss()
    }
}

/// Sets, reps or duration, weight and warm-ups for one exercise (SPEC 3.4–3.7).
struct ItemEditorView: View {
    @State var draft: ItemDraft
    let saveTitle: String
    let onSave: (ItemDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.unit) private var unitRaw = SettingsDefault.unit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    var body: some View {
        Form {
            Section {
                Stepper("Working sets: \(draft.sets)", value: $draft.sets, in: 1...20)
                if draft.kind == .timed {
                    Stepper("Duration: \(draft.durationSec)s", value: $draft.durationSec, in: 5...900, step: 5)
                } else {
                    Stepper("Reps: \(draft.reps)", value: $draft.reps, in: 1...100)
                }
                Stepper {
                    Text("\(draft.equipment == .bodyweight ? "Added weight" : "Weight"): \(weightText)")
                } onIncrement: {
                    draft.weightLb = WeightFormat.step(draft.weightLb, by: 1, unit: unit)
                } onDecrement: {
                    draft.weightLb = WeightFormat.step(draft.weightLb, by: -1, unit: unit)
                }
            } header: {
                Text("\(draft.equipment.label) · \(draft.kind.label)")
            }

            if draft.kind == .reps {
                Section {
                    Stepper("Warm-up sets: \(draft.warmupSets)", value: $draft.warmupSets, in: 0...10)
                    if draft.warmupSets > 0 {
                        Stepper("Warm-up reps: \(draft.warmupReps)", value: $draft.warmupReps, in: 1...50)
                    }
                } header: {
                    Text("Warm-up (optional)")
                } footer: {
                    Text("Warm-up sets use the same weight.")
                }
            }
        }
        .navigationTitle(draft.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(saveTitle) {
                    onSave(draft)
                    dismiss()
                }
                .fontWeight(.semibold)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    private var weightText: String {
        WeightFormat.text(lb: draft.weightLb, bodyweight: draft.equipment == .bodyweight, unit: unit)
    }
}
