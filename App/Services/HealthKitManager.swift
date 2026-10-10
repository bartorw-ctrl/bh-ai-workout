import Foundation
import HealthKit

/// Writes finished workouts to Apple Health and removes them on delete (SPEC 8).
final class HealthKitManager {
    static let shared = HealthKitManager()

    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Asks for write access. iOS only shows the prompt the first time (SPEC 8.1).
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [])
        } catch {
            return false
        }
        return store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized
    }

    /// Saves a Traditional Strength Training workout and returns its HealthKit ID (SPEC 8.2).
    func saveWorkout(start: Date, end: Date) async -> UUID? {
        guard await requestAuthorization() else { return nil }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        do {
            try await builder.beginCollection(at: start)
            try await builder.endCollection(at: end)
            let workout = try await builder.finishWorkout()
            return workout?.uuid
        } catch {
            return nil
        }
    }

    /// Deletes the HealthKit workout with this ID, if it still exists (SPEC 8.3).
    func deleteWorkout(id: UUID) async {
        guard isAvailable else { return }
        let predicate = HKQuery.predicateForObject(with: id)
        let descriptor = HKSampleQueryDescriptor(predicates: [.workout(predicate)], sortDescriptors: [])
        do {
            let workouts = try await descriptor.result(for: store)
            if !workouts.isEmpty {
                try await store.delete(workouts)
            }
        } catch {
            // Nothing to do: the workout may already be gone or access was revoked.
        }
    }
}
