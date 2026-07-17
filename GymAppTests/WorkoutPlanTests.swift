import XCTest
@testable import Stacked

@MainActor
final class WorkoutPlanTests: XCTestCase {
    private var temporaryURLs: [URL] = []

    override func tearDown() {
        for url in temporaryURLs {
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        }
        temporaryURLs = []
        super.tearDown()
    }

    func testCreateEditDeleteAndReorderOccurrences() throws {
        let monday = try date("2026-07-13")
        let push = template(name: "Push", order: 0)
        let store = try makeStore(data: appData(templates: [push]), now: { monday })

        let legs = template(name: "Leg Day", order: 1)
        store.createWorkout(legs)
        XCTAssertEqual(store.currentWeekOccurrences.map(\.templateID), [push.id, legs.id])

        var editedLegs = try XCTUnwrap(store.data.templates.first { $0.id == legs.id })
        editedLegs.name = "Lower Body"
        store.updateWorkout(editedLegs)
        XCTAssertEqual(store.data.templates.first { $0.id == legs.id }?.name, "Lower Body")

        store.moveOccurrences(from: IndexSet(integer: 1), to: 0)
        XCTAssertEqual(store.currentWeekOccurrences.map(\.templateID), [legs.id, push.id])

        let removedID = try XCTUnwrap(store.currentWeekOccurrences.first?.id)
        store.deleteOccurrence(id: removedID)
        XCTAssertEqual(store.currentWeekOccurrences.map(\.templateID), [push.id])
        XCTAssertNotNil(store.data.templates.first { $0.id == legs.id })
    }

    func testFreshInstallStartsEmptyAndPersistsUserCreatedWorkout() throws {
        let monday = try date("2026-07-13")
        let url = try temporarySaveURL()

        var store: WorkoutStore? = WorkoutStore(saveURL: url, now: { monday }, calendar: testCalendar)
        XCTAssertTrue(store?.data.templates.isEmpty == true)
        XCTAssertTrue(store?.data.history.isEmpty == true)
        XCTAssertTrue(store?.currentWeekOccurrences.isEmpty == true)
        XCTAssertTrue(store?.weeklyWorkoutStatuses.isEmpty == true)
        XCTAssertTrue(store?.weeklyTemplateGroups.isEmpty == true)
        XCTAssertNil(store?.suggestedTemplate)
        XCTAssertFalse(store?.data.exerciseDefinitions.isEmpty == true)

        let workout = template(name: "My Workout", order: 0)
        store?.createWorkout(workout)
        XCTAssertEqual(store?.currentWeekOccurrences.map(\.templateID), [workout.id])
        store = nil

        let reloadedStore = WorkoutStore(saveURL: url, now: { monday }, calendar: testCalendar)
        XCTAssertEqual(reloadedStore.data.templates, [workout])
        XCTAssertEqual(reloadedStore.currentWeekOccurrences.map(\.templateID), [workout.id])
        XCTAssertTrue(reloadedStore.data.history.isEmpty)
    }

    func testCreateWorkoutUsesChosenWeeklyFrequencyWithIndependentOccurrences() throws {
        let monday = try date("2026-07-13")
        let store = try makeStore(data: appData(templates: []), now: { monday })
        let workout = template(name: "Leg Day", order: 0)

        store.createWorkout(workout, weeklyFrequency: 3)

        XCTAssertEqual(store.data.templates, [workout])
        XCTAssertEqual(store.weeklyTemplateGroups.first?.frequency, 3)
        XCTAssertEqual(Set(store.currentWeekOccurrences.map(\.id)).count, 3)
        XCTAssertTrue(store.weeklyWorkoutStatuses.allSatisfy { !$0.isLogged })
    }

    func testEditingExercisePreservesFrequencyCompletionAndHistory() throws {
        let monday = try date("2026-07-13")
        let workout = template(name: "Fresh Start", order: 0)
        let store = try makeStore(data: appData(templates: [workout]), now: { monday })
        store.addOccurrence(templateID: workout.id)
        let completedStatus = try XCTUnwrap(store.weeklyWorkoutStatuses.first)
        store.saveWorkoutSession(store.makeDraftSession(for: completedStatus, date: monday))
        let occurrenceIDs = store.currentWeekOccurrences.map(\.id)
        let history = store.data.history

        var editedWorkout = workout
        editedWorkout.exercises[0].name = "Ab Roller"
        editedWorkout.exercises[0].targetSetCount = 4
        editedWorkout.exercises[0].targetSetsText = "4 sets"
        store.updateWorkout(editedWorkout)

        XCTAssertEqual(store.data.templates.first?.exercises.first?.name, "Ab Roller")
        XCTAssertEqual(store.data.templates.first?.exercises.first?.targetSetCount, 4)
        XCTAssertEqual(store.currentWeekOccurrences.map(\.id), occurrenceIDs)
        XCTAssertEqual(store.weeklyTemplateGroups.first?.frequency, 2)
        XCTAssertEqual(store.weeklyTemplateGroups.first?.completedCount, 1)
        XCTAssertEqual(store.data.history, history)
    }

    func testExistingPersistedDataSurvivesCatalogEnrichmentAndReload() throws {
        let monday = try date("2026-07-13")
        let workout = template(name: "My Routine", order: 0)
        let occurrence = PlannedWorkoutOccurrence(templateID: workout.id, order: 0)
        let completedSession = WorkoutSession(
            date: try date("2026-07-14"),
            workoutName: workout.name,
            bodyweight: "180",
            duration: "45 min",
            notes: "Keep this",
            isSeededHistory: false,
            plannedOccurrenceID: occurrence.id,
            exercises: []
        )
        let activeSession = session(name: "In Progress", date: monday)
        let persistedData = GymAppData(
            templates: [workout],
            weeklyPlans: [WeeklyWorkoutPlan(weekStart: monday, occurrences: [occurrence])],
            history: [completedSession],
            activeSession: activeSession,
            exerciseLibrary: ["Custom Movement"]
        )
        let url = try writeData(persistedData)

        let store = WorkoutStore(saveURL: url, now: { monday }, calendar: testCalendar)

        XCTAssertEqual(store.data.templates, persistedData.templates)
        XCTAssertEqual(store.data.weeklyPlans, persistedData.weeklyPlans)
        XCTAssertEqual(store.data.history, persistedData.history)
        XCTAssertEqual(store.data.activeSession, persistedData.activeSession)
        XCTAssertTrue(store.data.exerciseLibrary.contains("Custom Movement"))
        XCTAssertEqual(store.weeklyWorkoutStatuses.first?.loggedSession?.id, completedSession.id)
    }

    func testAppBundleHasExerciseCatalogWithoutLegacyPlanResource() {
        XCTAssertNotNil(Bundle.main.url(forResource: "exercemus-exercises", withExtension: "json"))
        XCTAssertNil(Bundle.main.url(forResource: "plan", withExtension: "md"))
    }

    func testPersistenceAndLegacyMigrationPreserveStoredWorkouts() throws {
        let monday = try date("2026-07-13")
        let zone2 = template(name: "Zone 2 Cardio", order: 0)
        let legacyHistory = session(name: "Zone 2 Cardio", date: try date("2026-07-14"))
        let url = try writeLegacyData(appData(templates: [zone2], history: [legacyHistory]))

        var store: WorkoutStore? = WorkoutStore(saveURL: url, now: { monday }, calendar: testCalendar)
        XCTAssertEqual(store?.data.templates, [zone2])
        XCTAssertEqual(store?.data.history.count, 1)
        XCTAssertEqual(store?.currentWeekOccurrences.count, 1)
        XCTAssertNotNil(store?.data.history.first?.plannedOccurrenceID)

        store?.addOccurrence(templateID: zone2.id)
        let occurrenceIDs = store?.currentWeekOccurrences.map(\.id)
        store = nil

        let reloadedStore = WorkoutStore(saveURL: url, now: { monday }, calendar: testCalendar)
        XCTAssertEqual(reloadedStore.currentWeekOccurrences.map(\.id), occurrenceIDs)
        XCTAssertEqual(reloadedStore.data.history.first?.id, legacyHistory.id)
    }

    func testDuplicateActivitiesHaveIndependentCompletion() throws {
        let thursday = try date("2026-07-16")
        let zone2 = template(name: "Zone 2 Cardio", order: 0)
        let store = try makeStore(data: appData(templates: [zone2]), now: { thursday })
        store.addOccurrence(templateID: zone2.id)

        let initialStatuses = store.weeklyWorkoutStatuses
        XCTAssertEqual(initialStatuses.count, 2)
        XCTAssertNotEqual(initialStatuses[0].id, initialStatuses[1].id)

        store.startWorkout(for: initialStatuses[0])
        store.completeActiveWorkout()

        let completedStatuses = store.weeklyWorkoutStatuses
        XCTAssertEqual(completedStatuses.filter(\.isLogged).count, 1)
        XCTAssertTrue(completedStatuses[0].isLogged)
        XCTAssertFalse(completedStatuses[1].isLogged)
        XCTAssertEqual(
            store.data.history.first?.plannedOccurrenceID,
            completedStatuses[0].occurrence.id
        )
    }

    func testDuplicateTemplateOccurrencesReconcileTwoDistinctCompletions() throws {
        let thursday = try date("2026-07-16")
        let zone2 = template(name: "Zone 2 Cardio", order: 0)
        let store = try makeStore(data: appData(templates: [zone2]), now: { thursday })
        store.addOccurrence(templateID: zone2.id)

        let firstStatus = try XCTUnwrap(store.weeklyWorkoutStatuses.first)
        store.saveWorkoutSession(store.makeDraftSession(for: firstStatus, date: thursday))
        let manualSession = store.makeDraftSession(from: zone2, date: try date("2026-07-17"))
        store.saveWorkoutSession(manualSession)

        let statuses = store.weeklyWorkoutStatuses
        XCTAssertEqual(statuses.count, 2)
        XCTAssertEqual(statuses.filter(\.isLogged).count, 2)
        XCTAssertEqual(Set(statuses.compactMap { $0.loggedSession?.id }).count, 2)
        XCTAssertEqual(store.weeklyTemplateGroups.first?.completedCount, 2)
        XCTAssertNil(store.data.history.first { $0.id == manualSession.id }?.plannedOccurrenceID)
    }

    func testOneSessionCannotCompleteTwoDuplicateOccurrences() throws {
        let thursday = try date("2026-07-16")
        let zone2 = template(name: "Zone 2 Cardio", order: 0)
        let store = try makeStore(data: appData(templates: [zone2]), now: { thursday })
        store.addOccurrence(templateID: zone2.id)

        store.saveWorkoutSession(store.makeDraftSession(from: zone2, date: thursday))

        XCTAssertEqual(store.weeklyWorkoutStatuses.filter(\.isLogged).count, 1)
        XCTAssertEqual(store.weeklyTemplateGroups.first?.completedCount, 1)
    }

    func testMixedPlannedAndLegacySessionsCompleteSeparateOccurrencesWithoutMutation() throws {
        let thursday = try date("2026-07-16")
        let zone2 = template(name: "Zone 2 Cardio", order: 0)
        let store = try makeStore(data: appData(templates: [zone2]), now: { thursday })
        store.addOccurrence(templateID: zone2.id)

        let plannedStatus = try XCTUnwrap(store.weeklyWorkoutStatuses.first)
        store.saveWorkoutSession(store.makeDraftSession(for: plannedStatus, date: thursday))
        let legacySession = session(name: "Zone 2 Cardio", date: try date("2026-07-17"))
        store.saveWorkoutSession(legacySession)
        let persistedHistory = store.data.history

        XCTAssertEqual(store.weeklyWorkoutStatuses.filter(\.isLogged).count, 2)
        XCTAssertEqual(store.data.history, persistedHistory)
        XCTAssertNil(store.data.history.first { $0.id == legacySession.id }?.plannedOccurrenceID)
    }

    func testSameNameDistinctTemplatesUseExerciseIdentityAndRejectAmbiguousLegacyName() throws {
        let thursday = try date("2026-07-16")
        let treadmill = template(name: "Zone 2 Cardio", order: 0)
        let bike = template(name: "Zone 2 Cardio", order: 1)
        let store = try makeStore(data: appData(templates: [treadmill, bike]), now: { thursday })

        let bikeSession = store.makeDraftSession(from: bike, date: thursday)
        store.saveWorkoutSession(bikeSession)
        store.saveWorkoutSession(session(name: "Zone 2 Cardio", date: try date("2026-07-17")))

        let statuses = store.weeklyWorkoutStatuses
        XCTAssertFalse(try XCTUnwrap(statuses.first { $0.template.id == treadmill.id }).isLogged)
        XCTAssertEqual(
            try XCTUnwrap(statuses.first { $0.template.id == bike.id }).loggedSession?.id,
            bikeSession.id
        )
        XCTAssertEqual(statuses.filter(\.isLogged).count, 1)
    }

    func testMondayRolloverCopiesPlanWithFreshIDsWithoutOverwritingEdits() throws {
        var currentDate = try date("2026-07-13")
        let push = template(name: "Push", order: 0)
        let zone2 = template(name: "Zone 2 Cardio", order: 1)
        let store = try makeStore(
            data: appData(templates: [push, zone2]),
            now: { currentDate }
        )
        store.addOccurrence(templateID: zone2.id)
        let firstWeekIDs = store.currentWeekOccurrences.map(\.id)

        currentDate = try date("2026-07-20")
        let rolledOccurrences = store.currentWeekOccurrences
        XCTAssertEqual(rolledOccurrences.map(\.templateID), [push.id, zone2.id, zone2.id])
        XCTAssertTrue(Set(firstWeekIDs).isDisjoint(with: Set(rolledOccurrences.map(\.id))))
        XCTAssertEqual(store.data.weeklyPlans.count, 2)

        store.deleteOccurrence(id: try XCTUnwrap(rolledOccurrences.first?.id))
        XCTAssertEqual(store.currentWeekOccurrences.count, 2)
        XCTAssertEqual(store.data.weeklyPlans.first?.occurrences.count, 3)
    }

    func testMondayRolloverDoesNotReusePriorWeekManualCompletion() throws {
        var currentDate = try date("2026-07-19")
        let zone2 = template(name: "Zone 2 Cardio", order: 0)
        let store = try makeStore(data: appData(templates: [zone2]), now: { currentDate })
        store.saveWorkoutSession(store.makeDraftSession(from: zone2, date: currentDate))
        XCTAssertEqual(store.weeklyWorkoutStatuses.filter(\.isLogged).count, 1)

        currentDate = try date("2026-07-20")

        XCTAssertEqual(store.weeklyWorkoutStatuses.count, 1)
        XCTAssertEqual(store.weeklyWorkoutStatuses.filter(\.isLogged).count, 0)
    }

    func testReconciledManualCompletionsPersistAcrossRelaunchWithoutRewritingHistory() throws {
        let thursday = try date("2026-07-16")
        let zone2 = template(name: "Zone 2 Cardio", order: 0)
        let url = try writeData(appData(templates: [zone2]))
        var store: WorkoutStore? = WorkoutStore(saveURL: url, now: { thursday }, calendar: testCalendar)
        store?.addOccurrence(templateID: zone2.id)
        let manualSession = try XCTUnwrap(store?.makeDraftSession(from: zone2, date: thursday))
        store?.saveWorkoutSession(manualSession)
        let historyBeforeRelaunch = try XCTUnwrap(store?.data.history)
        let occurrenceIDs = try XCTUnwrap(store?.currentWeekOccurrences.map(\.id))
        store = nil

        let reloadedStore = WorkoutStore(saveURL: url, now: { thursday }, calendar: testCalendar)

        XCTAssertEqual(reloadedStore.currentWeekOccurrences.map(\.id), occurrenceIDs)
        XCTAssertEqual(reloadedStore.weeklyWorkoutStatuses.filter(\.isLogged).count, 1)
        XCTAssertEqual(reloadedStore.data.history, historyBeforeRelaunch)
        XCTAssertNil(reloadedStore.data.history.first?.plannedOccurrenceID)
    }

    func testHomeGroupsTemplatesWithFrequencyMarkersAndIndependentCompletion() throws {
        let wednesday = try date("2026-07-15")
        let legs = template(name: "Leg Day", order: 0)
        let zone2 = template(name: "Zone 2 Cardio", order: 1)
        let store = try makeStore(data: appData(templates: [legs, zone2]), now: { wednesday })
        store.addOccurrence(templateID: zone2.id)

        let secondZone2 = try XCTUnwrap(store.weeklyWorkoutStatuses.last)
        let logged = store.makeDraftSession(for: secondZone2, date: wednesday)
        store.saveWorkoutSession(logged)

        let statuses = store.weeklyWorkoutStatuses
        XCTAssertEqual(statuses.count, 3)
        XCTAssertEqual(statuses.filter(\.isLogged).count, 1)
        XCTAssertEqual(statuses.filter { $0.displayName == "Zone 2" }.count, 2)
        XCTAssertEqual(statuses.last?.loggedSession?.id, logged.id)

        let groups = store.weeklyTemplateGroups
        XCTAssertEqual(groups.map(\.template.id), [legs.id, zone2.id])
        XCTAssertEqual(groups.last?.frequency, 2)
        XCTAssertEqual(groups.last?.completedCount, 1)
        XCTAssertEqual(groups.last?.statuses.map(\.id), statuses.suffix(2).map(\.id))
    }

    func testFrequencyIncrementAndDecrementRemoveUncompletedOccurrencesFirst() throws {
        let wednesday = try date("2026-07-15")
        let zone2 = template(name: "Zone 2 Cardio", order: 0)
        let store = try makeStore(data: appData(templates: [zone2]), now: { wednesday })
        store.addOccurrence(templateID: zone2.id)
        store.addOccurrence(templateID: zone2.id)
        let originalIDs = store.currentWeekOccurrences.map(\.id)

        let completedStatus = store.weeklyWorkoutStatuses[1]
        store.saveWorkoutSession(store.makeDraftSession(for: completedStatus, date: wednesday))

        XCTAssertEqual(store.decreaseFrequency(templateID: zone2.id), .removedUncompleted)
        XCTAssertEqual(store.currentWeekOccurrences.map(\.id), Array(originalIDs.prefix(2)))
        XCTAssertEqual(store.data.history.first?.plannedOccurrenceID, originalIDs[1])

        XCTAssertEqual(store.decreaseFrequency(templateID: zone2.id), .removedUncompleted)
        XCTAssertEqual(store.currentWeekOccurrences.map(\.id), [originalIDs[1]])
        XCTAssertTrue(store.weeklyWorkoutStatuses[0].isLogged)
    }

    func testCompletedFrequencyDecreaseRequiresConfirmationAndPreservesHistory() throws {
        let thursday = try date("2026-07-16")
        let zone2 = template(name: "Zone 2 Cardio", order: 0)
        let store = try makeStore(data: appData(templates: [zone2]), now: { thursday })
        store.addOccurrence(templateID: zone2.id)

        for status in store.weeklyWorkoutStatuses {
            store.saveWorkoutSession(store.makeDraftSession(for: status, date: thursday))
        }
        let removedOccurrenceID = try XCTUnwrap(store.currentWeekOccurrences.last?.id)

        XCTAssertEqual(store.decreaseFrequency(templateID: zone2.id), .requiresCompletedConfirmation)
        XCTAssertEqual(store.currentWeekOccurrences.count, 2)

        XCTAssertEqual(
            store.decreaseFrequency(templateID: zone2.id, allowCompletedRemoval: true),
            .removedCompleted
        )
        XCTAssertEqual(store.currentWeekOccurrences.count, 1)
        XCTAssertEqual(store.data.history.count, 2)
        XCTAssertTrue(store.data.history.contains { $0.plannedOccurrenceID == nil })
        XCTAssertFalse(store.data.history.contains { $0.plannedOccurrenceID == removedOccurrenceID })
    }

    func testGroupedReorderKeepsOccurrenceOrderDeterministic() throws {
        let monday = try date("2026-07-13")
        let push = template(name: "Push", order: 0)
        let zone2 = template(name: "Zone 2 Cardio", order: 1)
        let legs = template(name: "Legs", order: 2)
        let store = try makeStore(data: appData(templates: [push, zone2, legs]), now: { monday })
        store.addOccurrence(templateID: zone2.id)
        let zoneOccurrenceIDs = store.currentWeekOccurrences
            .filter { $0.templateID == zone2.id }
            .map(\.id)

        store.moveTemplateGroups(from: IndexSet(integer: 1), to: 0)

        XCTAssertEqual(store.weeklyTemplateGroups.map(\.template.id), [zone2.id, push.id, legs.id])
        XCTAssertEqual(
            store.currentWeekOccurrences.map(\.templateID),
            [zone2.id, zone2.id, push.id, legs.id]
        )
        XCTAssertEqual(Array(store.currentWeekOccurrences.prefix(2)).map(\.id), zoneOccurrenceIDs)
        XCTAssertEqual(store.currentWeekOccurrences.map(\.order), Array(0..<4))
    }

    func testContextMenuReorderMovesWholeTemplateGroupAndStopsAtBoundaries() throws {
        let monday = try date("2026-07-13")
        let push = template(name: "Push", order: 0)
        let zone2 = template(name: "Zone 2", order: 1)
        let legs = template(name: "Legs", order: 2)
        let store = try makeStore(data: appData(templates: [push, zone2, legs]), now: { monday })
        store.addOccurrence(templateID: zone2.id)

        store.moveTemplateGroup(templateID: zone2.id, by: -1)
        XCTAssertEqual(store.weeklyTemplateGroups.map(\.id), [zone2.id, push.id, legs.id])
        XCTAssertEqual(store.currentWeekOccurrences.map(\.templateID), [zone2.id, zone2.id, push.id, legs.id])

        store.moveTemplateGroup(templateID: zone2.id, by: -1)
        XCTAssertEqual(store.weeklyTemplateGroups.map(\.id), [zone2.id, push.id, legs.id])

        store.moveTemplateGroup(templateID: push.id, by: 1)
        XCTAssertEqual(store.weeklyTemplateGroups.map(\.id), [zone2.id, legs.id, push.id])
        XCTAssertEqual(store.currentWeekOccurrences.map(\.order), Array(0..<4))
    }

    func testMatchingManualWorkoutCountsOnceWhilePriorWeekHistoryStaysIndependent() throws {
        let friday = try date("2026-07-17")
        let push = template(name: "Push", order: 0)
        let url = try writeData(appData(templates: [push]))
        var store: WorkoutStore? = WorkoutStore(
            saveURL: url,
            now: { friday },
            calendar: testCalendar
        )

        store?.startWorkout(from: push)
        store?.completeActiveWorkout()

        XCTAssertNil(store?.data.history.first?.plannedOccurrenceID)
        XCTAssertEqual(store?.data.history.first?.workoutName, "Push")
        XCTAssertEqual(store?.weeklyWorkoutStatuses.filter(\.isLogged).count, 1)

        let previousDate = try date("2026-07-10")
        let previous = try XCTUnwrap(store?.makeDraftSession(from: push, date: previousDate))
        store?.saveWorkoutSession(previous)
        XCTAssertEqual(store?.data.history.first?.date, friday)
        XCTAssertEqual(store?.data.history.last?.date, previousDate)

        store = nil
        let reloadedStore = WorkoutStore(saveURL: url, now: { friday }, calendar: testCalendar)
        XCTAssertTrue(reloadedStore.data.history.allSatisfy { $0.plannedOccurrenceID == nil })
        XCTAssertEqual(reloadedStore.weeklyWorkoutStatuses.filter(\.isLogged).count, 1)
    }

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ value: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.calendar = testCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = testCalendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return try XCTUnwrap(formatter.date(from: value))
    }

    private func template(name: String, order: Int) -> WorkoutTemplate {
        WorkoutTemplate(
            name: name,
            order: order,
            exercises: [
                TemplateExercise(
                    name: "Test Exercise \(order)",
                    order: 0,
                    targetSetsText: "3 sets",
                    targetRepsText: "8-12 reps",
                    targetSetCount: 3,
                    supersetGroupId: nil,
                    supersetName: nil
                )
            ]
        )
    }

    private func session(name: String, date: Date) -> WorkoutSession {
        WorkoutSession(
            date: date,
            workoutName: name,
            bodyweight: "",
            duration: "",
            notes: "",
            isSeededHistory: false,
            exercises: []
        )
    }

    private func appData(
        templates: [WorkoutTemplate],
        history: [WorkoutSession] = []
    ) -> GymAppData {
        GymAppData(
            templates: templates,
            history: history,
            activeSession: nil,
            exerciseLibrary: []
        )
    }

    private func makeStore(
        data: GymAppData,
        now: @escaping () -> Date
    ) throws -> WorkoutStore {
        let url = try writeData(data)
        return WorkoutStore(
            saveURL: url,
            now: now,
            calendar: testCalendar
        )
    }

    private func writeData(_ data: GymAppData) throws -> URL {
        let url = try temporarySaveURL()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(data).write(to: url)
        return url
    }

    private func temporarySaveURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("gym-data.json")
        temporaryURLs.append(url)
        return url
    }

    private func writeLegacyData(_ data: GymAppData) throws -> URL {
        let url = try writeData(data)
        let encoded = try Data(contentsOf: url)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "weeklyPlans")
        try JSONSerialization.data(withJSONObject: object).write(to: url)
        return url
    }
}
