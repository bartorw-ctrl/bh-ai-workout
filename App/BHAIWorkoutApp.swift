import SwiftUI
import SwiftData
import UserNotifications

@main
struct BHAIWorkoutApp: App {
    @State private var appModel = AppModel()
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Schema(AppSchema.models))
        } catch {
            fatalError("Could not open the workout database: \(error)")
        }
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context

    var body: some View {
        @Bindable var appModel = appModel
        TabView {
            WorkoutsView()
                .tabItem { Label("Workouts", systemImage: "dumbbell") }
            CalendarScreen()
                .tabItem { Label("Calendar", systemImage: "calendar") }
            ProgressScreen()
                .tabItem { Label("Progress", systemImage: "chart.xyaxis.line") }
            SettingsScreen()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Theme.accent)
        .onAppear {
            Seed.runIfNeeded(context: context)
        }
        .fullScreenCover(isPresented: $appModel.showingSession) {
            SessionView()
                .environment(appModel)
                .environment(\.modelContext, context)
        }
    }
}
