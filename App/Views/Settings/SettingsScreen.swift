import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit
import Core

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct PendingImport: Identifiable {
    let id = UUID()
    let file: ExportFile
    let fileName: String
}

/// Settings tab (SPEC 9).
struct SettingsScreen: View {
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.unit) private var unitRaw = SettingsDefault.unit
    @AppStorage(SettingsKey.restSeconds) private var restSeconds = SettingsDefault.restSeconds
    @AppStorage(SettingsKey.healthEnabled) private var healthEnabled = SettingsDefault.healthEnabled

    @State private var showExportChoice = false
    @State private var shareItem: ShareItem?
    @State private var showImporter = false
    @State private var pendingImport: PendingImport?
    @State private var message: String?

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Units", selection: $unitRaw) {
                        ForEach(WeightUnit.allCases) { Text($0.rawValue).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    Stepper(value: $restSeconds, in: 15...600, step: 15) {
                        LabeledContent("Default rest timer", value: DurationFormat.clock(restSeconds))
                    }
                } header: {
                    Text("Workout")
                } footer: {
                    Text("Rest timer runs after working sets only. Weight buttons step by \(unit == .lb ? "5 lb" : "2.5 kg").")
                }

                Section {
                    Toggle("Save workouts to Health", isOn: $healthEnabled)
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("Finished workouts are saved as Traditional Strength Training. Imported sessions are never added.")
                }

                Section("Data") {
                    Button {
                        showExportChoice = true
                    } label: {
                        Label("Export workout history", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        showImporter = true
                    } label: {
                        Label("Import from JSON file", systemImage: "square.and.arrow.down")
                    }
                    LabeledContent("iCloud sync", value: "Coming in v2")
                        .foregroundStyle(Theme.muted)
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Export format", isPresented: $showExportChoice, titleVisibility: .visible) {
                Button("CSV — one row per set") { export(.csv) }
                Button("JSON — complete data") { export(.json) }
            } message: {
                Text("CSV opens in Numbers or Excel. JSON can be imported back into the app.")
            }
            .sheet(item: $shareItem) { item in
                ActivityView(url: item.url)
                    .presentationDetents([.medium, .large])
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                handlePicked(result)
            }
            .sheet(item: $pendingImport) { pending in
                ImportPreviewView(pending: pending) { result in
                    message = "Imported \(result.workouts) workouts, \(result.sessions) sessions and \(result.exercises) custom exercises."
                }
            }
            .alert("BH AI Workout", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) { message = nil }
            } message: {
                Text(message ?? "")
            }
        }
    }

    private func export(_ format: ExportFormat) {
        do {
            shareItem = ShareItem(url: try DataTransferService.writeExport(format: format, context: context))
        } catch {
            message = "Export failed: \(error.localizedDescription)"
        }
    }

    private func handlePicked(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                let file = try DataTransferService.read(url: url)
                pendingImport = PendingImport(file: file, fileName: url.lastPathComponent)
            } catch {
                // SPEC 9.7: unrecognised file → error, nothing changes.
                message = (error as? LocalizedError)?.errorDescription ?? "This file couldn't be read."
            }
        case .failure(let error):
            message = "Couldn't open the file: \(error.localizedDescription)"
        }
    }
}

/// Shows what's in an import file and lets the user merge or replace (SPEC 9.5, 9.6).
struct ImportPreviewView: View {
    let pending: PendingImport
    let onDone: (ImportResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var mode: ImportMode = .merge
    @State private var confirmReplace = false
    @State private var errorText: String?

    private var preview: ImportPreview { ImportPreview(file: pending.file) }

    var body: some View {
        NavigationStack {
            Form {
                Section(pending.fileName) {
                    LabeledContent("Workouts", value: "\(preview.workoutCount)")
                    LabeledContent("Sessions", value: "\(preview.sessionCount)")
                    LabeledContent("Custom exercises", value: "\(preview.customExerciseCount)")
                    if let first = preview.firstSession, let last = preview.lastSession {
                        LabeledContent("Dates", value: first.formatted(date: .abbreviated, time: .omitted)
                                       + " – " + last.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                Section {
                    Picker("Import mode", selection: $mode) {
                        VStack(alignment: .leading) {
                            Text("Merge")
                            Text("Add what's new. Skip sessions you already have.")
                                .font(.footnote).foregroundStyle(Theme.muted)
                        }
                        .tag(ImportMode.merge)
                        VStack(alignment: .leading) {
                            Text("Replace all data")
                            Text("Delete everything on this iPhone first. Can't be undone.")
                                .font(.footnote).foregroundStyle(Theme.muted)
                        }
                        .tag(ImportMode.replace)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } footer: {
                    Text("Imported sessions are not added to Apple Health.")
                }
                if let errorText {
                    Text(errorText).foregroundStyle(Theme.destructive)
                }
                Section {
                    Button(mode == .replace ? "Replace and import" : "Import") {
                        if mode == .replace {
                            confirmReplace = true
                        } else {
                            runImport()
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(color: mode == .replace ? Theme.destructive : Theme.accent))
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Ready to import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .confirmationDialog("Replace all data?", isPresented: $confirmReplace, titleVisibility: .visible) {
                Button("Replace all data", role: .destructive, action: runImport)
            } message: {
                Text("All workouts, history and custom exercises on this iPhone will be deleted and replaced with the file's contents.")
            }
        }
    }

    private func runImport() {
        do {
            let result = try DataTransferService.apply(file: pending.file, mode: mode, context: context)
            dismiss()
            onDone(result)
        } catch {
            errorText = "Import failed: \(error.localizedDescription). Nothing was changed."
        }
    }
}

/// The iOS share sheet.
struct ActivityView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
