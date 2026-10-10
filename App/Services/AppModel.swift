import Foundation
import Observation
import SwiftData
import Core

/// Owns the in-progress workout and its clock.
@Observable
final class AppModel {
    private(set) var active: ActiveSession?
    var showingSession = false
    /// Updated several times a second while a workout is in progress, so timers redraw.
    private(set) var now = Date()
    /// Shows the "rest over" message for a few seconds.
    private(set) var restOverUntil: Date?

    @ObservationIgnored private var timer: Timer?

    init() {
        active = ActiveSessionStore.load()
        if active != nil {
            showingSession = true
            tick()
            startClock()
        }
    }

    var isRestOverShowing: Bool {
        guard let restOverUntil else { return false }
        return restOverUntil > now
    }

    // MARK: Lifecycle

    func start(_ workout: Workout) {
        let session = ActiveSession(workoutID: workout.id, workoutName: workout.name, startedAt: Date(),
                                    exercises: workout.sortedItems.map(\.activeExercise))
        active = session
        persist()
        RestAlerts.requestPermission()
        startClock()
        showingSession = true
    }

    /// Applies a change to the in-progress workout, saves it, and reschedules the rest alert.
    func update(_ change: (inout ActiveSession) -> Void) {
        guard var session = active else { return }
        now = Date()
        change(&session)
        active = session
        persist()
    }

    func discard() {
        stop()
    }

    /// Saves the session to history, writes weights back to the workout, and sends it to Apple Health (SPEC 5.7, 5.10).
    func finish(context: ModelContext) {
        guard let session = active else { return }
        let end = Date()
        let saved = Session.insert(Session.historyDTO(from: session, endedAt: end), into: context)

        if let workoutID = session.workoutID {
            let descriptor = FetchDescriptor<Workout>(predicate: #Predicate { $0.id == workoutID })
            if let workout = try? context.fetch(descriptor).first {
                for item in workout.items ?? [] {
                    if let exercise = session.exercises.first(where: { $0.id == item.id }) {
                        item.weightLb = exercise.weightLb
                    }
                }
            }
        }
        try? context.save()
        stop()

        if AppSettings.healthEnabled {
            Task { @MainActor in
                if let healthID = await HealthKitManager.shared.saveWorkout(start: session.startedAt, end: end) {
                    saved.healthKitID = healthID
                    try? context.save()
                }
            }
        }
    }

    // MARK: Clock

    private func startClock() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        now = Date()
        guard var session = active else { return }
        let restEnded = session.tick(now: now, restSeconds: AppSettings.restSeconds)
        if session != active {
            active = session
            persist()
        }
        if restEnded {
            restOverUntil = now.addingTimeInterval(3)
            RestAlerts.playInApp()
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        active = nil
        showingSession = false
        restOverUntil = nil
        ActiveSessionStore.clear()
        RestAlerts.schedule(at: nil)
    }

    private func persist() {
        guard let session = active else { return }
        ActiveSessionStore.save(session)
        RestAlerts.schedule(at: session.nextRestAlert(restSeconds: AppSettings.restSeconds, now: Date()))
    }
}
