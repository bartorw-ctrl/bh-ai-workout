import SwiftUI
import SwiftData
import Core

/// Exercise picker with search and custom exercises (SPEC 3, 4).
struct ExercisePickerView: View {
    let onAdd: (ItemDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var search = ""
    @State private var customTarget: CustomExerciseTarget?
    @State private var deleting: Exercise?

    private var filtered: [Exercise] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return exercises }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { exercise in
                    NavigationLink {
                        ItemEditorView(draft: ItemDraft(exercise: exercise), saveTitle: "Add") { draft in
                            onAdd(draft)
                            dismiss()
                        }
                    } label: {
                        row(exercise)
                    }
                    .swipeActions(edge: .trailing) {
                        if !exercise.isBuiltIn {
                            Button("Delete", role: .destructive) { deleting = exercise }
                            Button("Edit") { customTarget = .existing(exercise) }
                                .tint(Theme.ink)
                        }
                    }
                }
                if filtered.isEmpty {
                    Text("No exercises match “\(search)”.")
                        .foregroundStyle(Theme.muted)
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search, e.g. Barbell or squat")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        customTarget = .new
                    } label: {
                        Label("New exercise", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $customTarget) { target in
                CustomExerciseEditor(exercise: target.exercise)
            }
            .confirmationDialog("Delete \(deleting?.name ?? "exercise")?",
                                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                                titleVisibility: .visible) {
                Button("Delete exercise", role: .destructive) {
                    if let deleting {
                        context.delete(deleting)
                        try? context.save()
                    }
                    deleting = nil
                }
            } message: {
                Text("Workouts that already use it keep it.")
            }
        }
    }

    private func row(_ exercise: Exercise) -> some View {
        HStack {
            Text(exercise.name).foregroundStyle(Theme.ink)
            Spacer()
            if !exercise.isBuiltIn {
                Text("Custom")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.accentSoftText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 6))
            }
            Text(exercise.kind.label)
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
    }
}

enum CustomExerciseTarget: Identifiable {
    case new
    case existing(Exercise)

    var id: String {
        switch self {
        case .new: return "new"
        case .existing(let exercise): return exercise.id.uuidString
        }
    }

    var exercise: Exercise? {
        if case .existing(let exercise) = self { return exercise }
        return nil
    }
}

/// Create or edit a custom exercise (SPEC 4).
struct CustomExerciseEditor: View {
    let exercise: Exercise?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var allExercises: [Exercise]

    @State private var baseName: String
    @State private var equipment: Equipment
    @State private var kind: ExerciseKind

    init(exercise: Exercise?) {
        self.exercise = exercise
        let equipment = exercise?.equipment ?? .barbell
        var base = exercise?.name ?? ""
        let prefix = equipment.namePrefix
        if !prefix.isEmpty && base.hasPrefix(prefix) {
            base = String(base.dropFirst(prefix.count))
        }
        _baseName = State(initialValue: base)
        _equipment = State(initialValue: equipment)
        _kind = State(initialValue: exercise?.kind ?? .reps)
    }

    private var fullName: String {
        ExerciseDefinition.fullName(base: baseName, equipment: equipment)
    }

    private var isDuplicate: Bool {
        allExercises.contains { $0.id != exercise?.id && $0.name.caseInsensitiveCompare(fullName) == .orderedSame }
    }

    private var canSave: Bool {
        !baseName.trimmingCharacters(in: .whitespaces).isEmpty && !isDuplicate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Zercher Squat", text: $baseName)
                }
                Section("Equipment") {
                    Picker("Equipment", selection: $equipment) {
                        ForEach(Equipment.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                Section("Type") {
                    Picker("Type", selection: $kind) {
                        ForEach(ExerciseKind.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                Section {
                    LabeledContent("Shows as", value: baseName.isEmpty ? "—" : fullName)
                    if isDuplicate {
                        Text("An exercise with this name already exists.")
                            .foregroundStyle(Theme.destructive)
                    }
                }
            }
            .navigationTitle(exercise == nil ? "New Exercise" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        if let exercise {
            exercise.name = fullName
            exercise.equipment = equipment
            exercise.kind = kind
        } else {
            context.insert(Exercise(name: fullName, equipment: equipment, kind: kind, isBuiltIn: false))
        }
        try? context.save()
        dismiss()
    }
}
