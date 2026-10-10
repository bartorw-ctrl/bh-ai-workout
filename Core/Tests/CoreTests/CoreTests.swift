import XCTest
@testable import Core

final class SetTapTests: XCTestCase {
    func testCycle() {
        XCTAssertEqual(SetTap.next(current: nil, target: 10), 10)
        XCTAssertEqual(SetTap.next(current: 10, target: 10), 9)
        XCTAssertEqual(SetTap.next(current: 1, target: 10), 0)
        XCTAssertNil(SetTap.next(current: 0, target: 10))
    }
}

final class ExerciseTests: XCTestCase {
    func testBuiltInList() {
        XCTAssertEqual(BuiltInExercises.all.count, 25)
        XCTAssertEqual(Set(BuiltInExercises.all.map(\.name)).count, 25)
        XCTAssertEqual(BuiltInExercises.all.filter { $0.kind == .timed }.map(\.name), ["Bodyweight Plank"])
        XCTAssertTrue(BuiltInExercises.all.allSatisfy { $0.name.hasPrefix($0.equipment.label + " ") })
    }

    func testFullName() {
        XCTAssertEqual(ExerciseDefinition.fullName(base: " Zercher Squat ", equipment: .barbell), "Barbell Zercher Squat")
        XCTAssertEqual(ExerciseDefinition.fullName(base: "Barbell Shrug", equipment: .barbell), "Barbell Shrug")
        XCTAssertEqual(ExerciseDefinition.fullName(base: "Sled Push", equipment: .other), "Sled Push")
    }
}

final class UnitTests: XCTestCase {
    func testFormat() {
        XCTAssertEqual(WeightFormat.text(lb: 135, bodyweight: false, unit: .lb), "135 lb")
        XCTAssertEqual(WeightFormat.text(lb: 0, bodyweight: true, unit: .lb), "BW")
        XCTAssertEqual(WeightFormat.text(lb: 25, bodyweight: true, unit: .lb), "BW + 25 lb")
        XCTAssertEqual(WeightFormat.text(lb: 45, bodyweight: false, unit: .kg), "20.5 kg")
    }

    func testStep() {
        XCTAssertEqual(WeightFormat.step(45, by: 1, unit: .lb), 50)
        XCTAssertEqual(WeightFormat.step(0, by: -1, unit: .lb), 0)
        let kg = WeightFormat.step(WeightUnit.kg.toLb(20), by: 1, unit: .kg)
        XCTAssertEqual(WeightUnit.kg.display(fromLb: kg), 22.5)
    }

    func testClock() {
        XCTAssertEqual(DurationFormat.clock(90), "1:30")
        XCTAssertEqual(DurationFormat.clock(5), "0:05")
    }
}

final class ActiveSessionTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    func makeSession() -> ActiveSession {
        ActiveSession(workoutID: UUID(), workoutName: "Full Body A", startedAt: t0, exercises: [
            ActiveExercise(id: UUID(), name: "Barbell Back Squat", equipment: .barbell, kind: .reps, weightLb: 45,
                           sets: 3, targetReps: 10, durationSec: 60, warmupSets: 1, warmupReps: 5),
            ActiveExercise(id: UUID(), name: "Bodyweight Plank", equipment: .bodyweight, kind: .timed, weightLb: 0,
                           sets: 3, targetReps: 10, durationSec: 60, warmupSets: 2, warmupReps: 5)
        ])
    }

    func testTimedHasNoWarmups() {
        XCTAssertEqual(makeSession().exercises[1].warmups.count, 0)
    }

    func testWorkingSetStartsRest() {
        var s = makeSession()
        s.tapWorking(exercise: 0, set: 0, now: t0, restSeconds: 90)
        XCTAssertEqual(s.exercises[0].working[0], 10)
        XCTAssertEqual(s.restRemaining(at: t0), 90)
        // Decrementing does not restart rest.
        s.skipRest()
        s.tapWorking(exercise: 0, set: 0, now: t0, restSeconds: 90)
        XCTAssertEqual(s.exercises[0].working[0], 9)
        XCTAssertNil(s.restEndsAt)
    }

    func testWarmupDoesNotStartRest() {
        var s = makeSession()
        s.tapWarmup(exercise: 0, set: 0)
        XCTAssertEqual(s.exercises[0].warmups[0], 5)
        XCTAssertNil(s.restEndsAt)
    }

    func testRestEndsAndAddTime() {
        var s = makeSession()
        s.tapWorking(exercise: 0, set: 0, now: t0, restSeconds: 90)
        s.addRest(seconds: 30, now: t0)
        XCTAssertEqual(s.restRemaining(at: t0), 120)
        XCTAssertFalse(s.tick(now: t0.addingTimeInterval(100), restSeconds: 90))
        XCTAssertTrue(s.tick(now: t0.addingTimeInterval(121), restSeconds: 90))
        XCTAssertNil(s.restEndsAt)
    }

    func testTimedSetRunsToCompletion() {
        var s = makeSession()
        s.tapWorking(exercise: 1, set: 0, now: t0, restSeconds: 90)
        XCTAssertNotNil(s.running)
        XCTAssertEqual(s.nextRestAlert(restSeconds: 90, now: t0), t0.addingTimeInterval(150))
        s.tick(now: t0.addingTimeInterval(70), restSeconds: 90)
        XCTAssertNil(s.running)
        XCTAssertEqual(s.exercises[1].working[0], 60)
        // Rest measured from when the set ended (t0+60), not when we noticed.
        XCTAssertEqual(s.restEndsAt, t0.addingTimeInterval(150))
    }

    func testTimedSetStopEarlyAndReset() {
        var s = makeSession()
        s.tapWorking(exercise: 1, set: 0, now: t0, restSeconds: 90)
        s.tapWorking(exercise: 1, set: 0, now: t0.addingTimeInterval(45), restSeconds: 90)
        XCTAssertEqual(s.exercises[1].working[0], 45)
        XCTAssertNil(s.running)
        s.tapWorking(exercise: 1, set: 0, now: t0.addingTimeInterval(50), restSeconds: 90)
        XCTAssertNil(s.exercises[1].working[0])
    }

    func testWeightChange() {
        var s = makeSession()
        s.changeWeight(exercise: 0, steps: 1, unit: .lb)
        XCTAssertEqual(s.exercises[0].weightLb, 50)
        s.changeWeight(exercise: 1, steps: -1, unit: .lb)
        XCTAssertEqual(s.exercises[1].weightLb, 0)
    }

    func testCodableRoundTrip() throws {
        var s = makeSession()
        s.tapWorking(exercise: 1, set: 0, now: t0, restSeconds: 90)
        let data = try JSONEncoder().encode(s)
        XCTAssertEqual(try JSONDecoder().decode(ActiveSession.self, from: data), s)
    }
}

final class TransferTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func sampleFile() -> ExportFile {
        let session = SessionDTO(id: UUID(), workoutID: nil, workoutName: "Full Body A", startedAt: t0,
                                 endedAt: t0.addingTimeInterval(2400), entries: [
            SessionEntryDTO(order: 0, exerciseName: "Barbell Back Squat", equipment: .barbell, kind: .reps,
                            weightLb: 135, targetReps: 10, targetDurationSec: 60, sets: [
                SetDTO(order: 0, isWarmup: true, value: 5),
                SetDTO(order: 1, isWarmup: false, value: 10),
                SetDTO(order: 2, isWarmup: false, value: 8)
            ]),
            SessionEntryDTO(order: 1, exerciseName: "Bodyweight Plank", equipment: .bodyweight, kind: .timed,
                            weightLb: 0, targetReps: 10, targetDurationSec: 60, sets: [
                SetDTO(order: 0, isWarmup: false, value: 60)
            ])
        ])
        return ExportFile(exportedAt: t0, settings: SettingsDTO(unit: .lb, restSeconds: 90),
                          customExercises: [ExerciseDTO(name: "Barbell Shrug", equipment: .barbell, kind: .reps)],
                          workouts: [], sessions: [session])
    }

    func testJSONRoundTrip() throws {
        let file = sampleFile()
        let decoded = try JSONTransfer.decode(try JSONTransfer.encode(file))
        XCTAssertEqual(decoded, file)
    }

    func testRejectsOtherJSON() {
        XCTAssertThrowsError(try JSONTransfer.decode(Data("{\"hello\":1}".utf8))) { error in
            XCTAssertEqual(error as? TransferError, .notAnExport)
        }
        XCTAssertThrowsError(try JSONTransfer.decode(Data("not json".utf8)))
    }

    func testPreview() {
        let p = ImportPreview(file: sampleFile())
        XCTAssertEqual(p.sessionCount, 1)
        XCTAssertEqual(p.customExerciseCount, 1)
        XCTAssertEqual(p.firstSession, t0)
    }

    func testMergeSkipsExisting() {
        let file = sampleFile()
        let plan = ImportPlan.make(file: file, mode: .merge, existingExerciseNames: ["barbell shrug"],
                                   existingWorkoutIDs: [], existingSessionIDs: [file.sessions[0].id])
        XCTAssertTrue(plan.exercises.isEmpty)
        XCTAssertTrue(plan.sessions.isEmpty)
        let replace = ImportPlan.make(file: file, mode: .replace, existingExerciseNames: ["barbell shrug"],
                                      existingWorkoutIDs: [], existingSessionIDs: [file.sessions[0].id])
        XCTAssertEqual(replace.sessions.count, 1)
    }

    func testCSV() {
        let csv = CSVExport.make(sessions: sampleFile().sessions, unit: .lb, timeZone: TimeZone(identifier: "UTC")!)
        let lines = csv.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.count, 5)
        XCTAssertEqual(lines[0], CSVExport.header.joined(separator: ","))
        XCTAssertEqual(lines[1], "2023-11-14,22:13,Full Body A,Barbell Back Squat,warmup,1,5,,135,lb")
        XCTAssertEqual(lines[3], "2023-11-14,22:13,Full Body A,Barbell Back Squat,working,2,8,,135,lb")
        XCTAssertEqual(lines[4], "2023-11-14,22:13,Full Body A,Bodyweight Plank,working,1,,60,0,lb")
        XCTAssertEqual(CSVExport.escape("a,b"), "\"a,b\"")
        XCTAssertEqual(CSVExport.escape("say \"hi\""), "\"say \"\"hi\"\"\"")
    }

    func testFileName() {
        XCTAssertEqual(ExportFileName.make(date: t0, ext: "json", timeZone: TimeZone(identifier: "UTC")!),
                       "bh-ai-workout-2023-11-14.json")
    }
}

final class ProgressTests: XCTestCase {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 1
        return c
    }()

    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    func testWeeklyCountsIncludesEmptyWeeks() {
        let now = date(2026, 10, 10) // Saturday
        let dates = [date(2026, 10, 6), date(2026, 10, 8), date(2026, 9, 22)]
        let weeks = ProgressMath.weeklyCounts(dates: dates, range: .oneMonth, now: now, calendar: calendar)
        XCTAssertEqual(weeks.last?.count, 2)
        XCTAssertEqual(weeks.reduce(0) { $0 + $1.count }, 3)
        XCTAssertTrue(weeks.contains { $0.count == 0 })
    }

    func testFilterRange() {
        let now = date(2026, 10, 10)
        let points = [ProgressPoint(date: date(2026, 1, 1), value: 100), ProgressPoint(date: date(2026, 10, 1), value: 120)]
        XCTAssertEqual(ProgressMath.filter(points, range: .threeMonths, now: now, calendar: calendar).count, 1)
        XCTAssertEqual(ProgressMath.filter(points, range: .all, now: now, calendar: calendar).count, 2)
    }

    func testValueForEntry() {
        let timed = SessionEntryDTO(order: 0, exerciseName: "Bodyweight Plank", equipment: .bodyweight, kind: .timed,
                                    weightLb: 0, targetReps: 0, targetDurationSec: 60,
                                    sets: [SetDTO(order: 0, isWarmup: false, value: 45), SetDTO(order: 1, isWarmup: false, value: 60)])
        XCTAssertEqual(ProgressMath.value(for: timed), 60)
    }
}
