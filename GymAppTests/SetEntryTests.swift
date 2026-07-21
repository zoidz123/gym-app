import XCTest
@testable import Stacked

final class SetEntryTests: XCTestCase {
    func testHistoryDefaultsUseStableExerciseIdentityAndMostRecentRelevantSession() {
        let templateExercise = makeTemplateExercise(name: "Incline DB Press")
        let identityMatch = makeLoggedExercise(
            templateExerciseId: templateExercise.id,
            name: "Incline Dumbbell Press",
            reps: 8,
            load: 30
        )
        let newerNameOnlyMatch = makeLoggedExercise(
            templateExerciseId: UUID(),
            name: templateExercise.name,
            reps: 20,
            load: 99
        )
        let history = [
            makeSession(date: Date(timeIntervalSince1970: 200), exercise: newerNameOnlyMatch),
            makeSession(date: Date(timeIntervalSince1970: 100), exercise: identityMatch)
        ]

        let result = WorkoutHistoryDefaults.latestLoggedExercise(
            matching: templateExercise,
            in: history
        )

        XCTAssertEqual(result?.templateExerciseId, templateExercise.id)
        XCTAssertEqual(result?.sets.first?.repsValue, 8)
        XCTAssertEqual(result?.sets.first?.loadValue, 30)
    }

    func testHistoryDefaultsSeedRepsAndWeightWithoutCompletingTheSet() {
        let previous = makeLoggedExercise(
            templateExerciseId: UUID(),
            name: "Cable Crossover",
            reps: 0,
            load: 0
        )

        let sets = WorkoutHistoryDefaults.makeSets(
            targetSetCount: 1,
            targetRepsText: "8-12 reps",
            lastLogged: previous
        )

        XCTAssertEqual(sets.first?.repsValue, 0)
        XCTAssertEqual(sets.first?.loadValue, 0)
        XCTAssertEqual(sets.first?.previousRepsValue, 0)
        XCTAssertEqual(sets.first?.previousLoadValue, 0)
        XCTAssertEqual(sets.first?.isCompleted, false)
    }

    func testUserEditedZeroAndEmptyValuesSurvivePersistenceRoundTrip() throws {
        let previous = makeLoggedExercise(
            templateExerciseId: UUID(),
            name: "Flat Chest Press",
            reps: 10,
            load: 135
        )
        var set = try XCTUnwrap(
            WorkoutHistoryDefaults.makeSets(
                targetSetCount: 1,
                targetRepsText: "8-12 reps",
                lastLogged: previous
            ).first
        )
        set.repsValue = 0
        set.loadValue = nil

        let decoded = try JSONDecoder().decode(
            LoggedSet.self,
            from: JSONEncoder().encode(set)
        )

        XCTAssertEqual(decoded.repsValue, 0)
        XCTAssertNil(decoded.loadValue)
        XCTAssertEqual(decoded.previousRepsValue, 10)
        XCTAssertEqual(decoded.previousLoadValue, 135)
    }

    func testSetEntryValidationAcceptsValidValuesAndRejectsInvalidValues() {
        XCTAssertEqual(SetEntryValueParser.reps(from: ""), .empty)
        XCTAssertEqual(SetEntryValueParser.reps(from: "0"), .value(0))
        XCTAssertEqual(SetEntryValueParser.reps(from: "12"), .value(12))
        XCTAssertEqual(SetEntryValueParser.reps(from: "-1"), .invalid)
        XCTAssertEqual(SetEntryValueParser.reps(from: "1.5"), .invalid)

        XCTAssertEqual(SetEntryValueParser.load(from: ""), .empty)
        XCTAssertEqual(SetEntryValueParser.load(from: "0"), .value(0))
        XCTAssertEqual(SetEntryValueParser.load(from: "42.5"), .value(42.5))
        XCTAssertEqual(SetEntryValueParser.load(from: "42,5"), .value(42.5))
        XCTAssertEqual(SetEntryValueParser.load(from: "-5"), .invalid)
        XCTAssertEqual(SetEntryValueParser.load(from: "abc"), .invalid)
    }

    func testBlankLoadBasedExerciseKeepsWeightUnitAndRepsEntryLayout() {
        let blankLoadedSet = LoggedSet(
            order: 1,
            loadValue: nil,
            loadUnit: .lb,
            repsValue: nil,
            previousLoadValue: nil,
            previousLoadUnit: nil,
            previousRepsValue: nil,
            previousLoadText: "",
            previousRepsText: "",
            detailText: "",
            isCompleted: false
        )

        XCTAssertTrue(SetEntryLayout.supportsLoad(units: [blankLoadedSet.loadUnit]))
        XCTAssertTrue(SetEntryLayout.supportsLoad(units: [.bodyweight]))
        XCTAssertTrue(SetEntryLayout.supportsLoad(units: [.seconds]))
        XCTAssertFalse(SetEntryLayout.supportsLoad(units: [.custom]))
    }

    func testRestTimerUsesDeadlineAndPreservesPausedTime() {
        let start = Date(timeIntervalSince1970: 1_000)
        var timer = WorkoutRestTimer(durationSeconds: 90, startedAt: start)

        XCTAssertEqual(timer.remainingSeconds(at: start), 90)
        XCTAssertEqual(timer.remainingSeconds(at: start.addingTimeInterval(30.2)), 60)

        timer.pause(at: start.addingTimeInterval(40))
        XCTAssertTrue(timer.isPaused)
        XCTAssertEqual(timer.remainingSeconds(at: start.addingTimeInterval(80)), 50)

        timer.resume(at: start.addingTimeInterval(100))
        XCTAssertFalse(timer.isPaused)
        XCTAssertEqual(timer.remainingSeconds(at: start.addingTimeInterval(125)), 25)
        XCTAssertTrue(timer.isComplete(at: start.addingTimeInterval(150)))
    }

    func testRestTimerPersistsWithActiveWorkoutSession() throws {
        let start = Date(timeIntervalSince1970: 1_000)
        var session = makeSession(
            date: start,
            exercise: makeLoggedExercise(
                templateExerciseId: UUID(),
                name: "Flat Chest Press",
                reps: 10,
                load: 135
            )
        )
        session.restTimer = WorkoutRestTimer(durationSeconds: 90, startedAt: start)

        let decoded = try JSONDecoder().decode(
            WorkoutSession.self,
            from: JSONEncoder().encode(session)
        )

        XCTAssertEqual(decoded.restTimer?.remainingSeconds(at: start.addingTimeInterval(45)), 45)
    }

    func testWorkoutSessionWithoutRestTimerStillDecodes() throws {
        let session = makeSession(
            date: Date(timeIntervalSince1970: 1_000),
            exercise: makeLoggedExercise(
                templateExerciseId: UUID(),
                name: "Flat Chest Press",
                reps: 10,
                load: 135
            )
        )
        var encodedObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(session)) as? [String: Any]
        )
        encodedObject.removeValue(forKey: "restTimer")

        let decoded = try JSONDecoder().decode(
            WorkoutSession.self,
            from: JSONSerialization.data(withJSONObject: encodedObject)
        )

        XCTAssertNil(decoded.restTimer)
    }

    private func makeTemplateExercise(name: String) -> TemplateExercise {
        TemplateExercise(
            name: name,
            order: 0,
            targetSetsText: "1",
            targetRepsText: "8-12 reps",
            targetSetCount: 1,
            supersetGroupId: nil,
            supersetName: nil
        )
    }

    private func makeLoggedExercise(
        templateExerciseId: UUID?,
        name: String,
        reps: Int,
        load: Double
    ) -> LoggedExercise {
        LoggedExercise(
            templateExerciseId: templateExerciseId,
            name: name,
            order: 0,
            targetSetsText: "1",
            targetRepsText: "8-12 reps",
            supersetGroupId: nil,
            supersetName: nil,
            notes: "",
            sets: [
                LoggedSet(
                    order: 1,
                    loadValue: load,
                    loadUnit: .kg,
                    repsValue: reps,
                    previousLoadValue: nil,
                    previousLoadUnit: nil,
                    previousRepsValue: nil,
                    previousLoadText: "",
                    previousRepsText: "",
                    detailText: "",
                    isCompleted: true
                )
            ]
        )
    }

    private func makeSession(date: Date, exercise: LoggedExercise) -> WorkoutSession {
        WorkoutSession(
            date: date,
            workoutName: "Push",
            bodyweight: "",
            duration: "",
            notes: "",
            isSeededHistory: false,
            exercises: [exercise]
        )
    }
}
