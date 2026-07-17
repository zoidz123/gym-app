import Combine
import Foundation

@MainActor
final class WorkoutStore: ObservableObject {
    @Published var data: GymAppData {
        didSet {
            save()
        }
    }

    private let saveURL: URL
    private let importer: MarkdownWorkoutImporter
    private let now: () -> Date
    private let calendar: Calendar

    init(
        importer: MarkdownWorkoutImporter = MarkdownWorkoutImporter(),
        fileManager: FileManager = .default,
        saveURL customSaveURL: URL? = nil,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.importer = importer
        self.now = now
        self.calendar = calendar
        let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = customSaveURL?.deletingLastPathComponent() ?? supportURL.appendingPathComponent("GymApp", isDirectory: true)
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        saveURL = customSaveURL ?? appDirectory.appendingPathComponent("gym-data.json")

        let storedData = Self.load(from: saveURL)
        let sourceData: GymAppData
        if let storedData {
            sourceData = storedData
        } else {
            sourceData = importer.loadSeedData()
        }

        let updatedData = Self.applyingCurrentPlanUpdates(to: sourceData)
        let enrichedData = importer.enrichedExerciseData(for: updatedData)
        data = Self.migratingWeeklyPlans(
            in: enrichedData,
            for: now(),
            calendar: calendar,
            associateLegacySessions: storedData?.weeklyPlans.isEmpty ?? true
        )
        save()

        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        let requestedTemplate = environment["UI_TEST_START_TEMPLATE"].flatMap { templateName in
            data.templates.first { $0.name.normalizedExerciseName == templateName.normalizedExerciseName }
        }
        let shouldStartSuggested = environment["UI_TEST_START_SUGGESTED"] == "1"

        if data.activeSession == nil,
           let template = requestedTemplate ?? (shouldStartSuggested ? suggestedTemplate : nil) {
            data.activeSession = makeSession(from: template, plannedOccurrenceID: nil)
        }
        #endif
    }

    var suggestedTemplate: WorkoutTemplate? {
        if let weekdayTemplate = scheduledTemplateForToday {
            return weekdayTemplate
        }

        guard let lastWorkoutName = data.history.first?.workoutName,
              let lastIndex = data.templates.firstIndex(where: { template in
                  lastWorkoutName.normalizedExerciseName.contains(template.name.normalizedExerciseName)
              }) else {
            return data.templates.first
        }

        let nextIndex = data.templates.index(after: lastIndex)
        return data.templates.indices.contains(nextIndex) ? data.templates[nextIndex] : data.templates.first
    }

    var scheduledTemplateForToday: WorkoutTemplate? {
        nextUnloggedWeeklyStatus?.template
    }

    var weeklyWorkoutStatuses: [WeeklyWorkoutStatus] {
        weeklyWorkoutStatuses(for: now())
    }

    var todayLoggedSessions: [WorkoutSession] {
        data.history
            .filter { Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
    }

    var nextUnloggedWeeklyTemplate: WorkoutTemplate? {
        nextUnloggedWeeklyStatus?.template
    }

    var nextUnloggedWeeklyStatus: WeeklyWorkoutStatus? {
        weeklyWorkoutStatuses.first { !$0.isLogged }
    }

    var currentWeekPlan: WeeklyWorkoutPlan {
        ensurePlanExists(for: now())
        let weekStart = Self.mondayWeekStart(for: now(), calendar: calendar)
        return data.weeklyPlans.first(where: { calendar.isDate($0.weekStart, inSameDayAs: weekStart) }) ??
            WeeklyWorkoutPlan(weekStart: weekStart, occurrences: [])
    }

    var currentWeekOccurrences: [PlannedWorkoutOccurrence] {
        currentWeekPlan.occurrences.sorted { $0.order < $1.order }
    }

    func template(for occurrence: PlannedWorkoutOccurrence) -> WorkoutTemplate? {
        data.templates.first { $0.id == occurrence.templateID }
    }

    func weeklyWorkoutStatuses(for date: Date) -> [WeeklyWorkoutStatus] {
        ensurePlanExists(for: date)
        let weekStart = Self.mondayWeekStart(for: date, calendar: calendar)
        guard let plan = data.weeklyPlans.first(where: { calendar.isDate($0.weekStart, inSameDayAs: weekStart) }) else {
            return []
        }

        return plan.occurrences
            .sorted { $0.order < $1.order }
            .compactMap { occurrence in
                guard let template = template(for: occurrence) else { return nil }
                let loggedSession = data.history
                    .filter { $0.plannedOccurrenceID == occurrence.id }
                    .sorted { $0.date > $1.date }
                    .first

                return WeeklyWorkoutStatus(
                    occurrence: occurrence,
                    template: template,
                    displayName: Self.weeklyDisplayName(for: template.name),
                    loggedSession: loggedSession
                )
            }
    }

    func startWorkout(from template: WorkoutTemplate) {
        data.activeSession = makeSession(from: template, plannedOccurrenceID: nil)
    }

    func startWorkout(for status: WeeklyWorkoutStatus) {
        data.activeSession = makeSession(
            from: status.template,
            plannedOccurrenceID: status.occurrence.id
        )
    }

    func makeDraftSession(from template: WorkoutTemplate, date: Date = Date()) -> WorkoutSession {
        var session = makeSession(from: template, plannedOccurrenceID: nil)
        session.date = date
        return session
    }

    func makeDraftSession(for status: WeeklyWorkoutStatus, date: Date) -> WorkoutSession {
        var session = makeSession(
            from: status.template,
            plannedOccurrenceID: isOccurrence(status.occurrence.id, validFor: date) ? status.occurrence.id : nil
        )
        session.date = date
        return session
    }

    func addOccurrence(templateID: UUID) {
        ensurePlanExists(for: now())
        guard data.templates.contains(where: { $0.id == templateID }),
              let planIndex = currentPlanIndex(for: now()) else {
            return
        }

        data.weeklyPlans[planIndex].occurrences.append(
            PlannedWorkoutOccurrence(
                templateID: templateID,
                order: data.weeklyPlans[planIndex].occurrences.count
            )
        )
    }

    func createWorkout(_ template: WorkoutTemplate) {
        var template = template
        template.order = data.templates.count
        normalizeExerciseOrders(in: &template)
        data.templates.append(template)
        addOccurrence(templateID: template.id)
    }

    func updateWorkout(_ template: WorkoutTemplate) {
        guard let index = data.templates.firstIndex(where: { $0.id == template.id }) else {
            return
        }

        var template = template
        normalizeExerciseOrders(in: &template)
        data.templates[index] = template
    }

    func deleteOccurrence(id: UUID) {
        ensurePlanExists(for: now())
        guard let planIndex = currentPlanIndex(for: now()) else { return }
        data.weeklyPlans[planIndex].occurrences.removeAll { $0.id == id }
        normalizeOccurrenceOrders(in: &data.weeklyPlans[planIndex])
    }

    func moveOccurrences(from source: IndexSet, to destination: Int) {
        ensurePlanExists(for: now())
        guard let planIndex = currentPlanIndex(for: now()) else { return }
        var occurrences = data.weeklyPlans[planIndex].occurrences
        let moving = source.sorted().map { occurrences[$0] }
        for index in source.sorted(by: >) {
            occurrences.remove(at: index)
        }
        let removedBeforeDestination = source.filter { $0 < destination }.count
        let insertionIndex = max(0, min(destination - removedBeforeDestination, occurrences.count))
        occurrences.insert(contentsOf: moving, at: insertionIndex)
        data.weeklyPlans[planIndex].occurrences = occurrences
        normalizeOccurrenceOrders(in: &data.weeklyPlans[planIndex])
    }

    func saveWorkoutSession(_ session: WorkoutSession) {
        var savedSession = session
        savedSession.isSeededHistory = false
        if let occurrenceID = savedSession.plannedOccurrenceID,
           !isOccurrence(occurrenceID, validFor: savedSession.date) {
            savedSession.plannedOccurrenceID = nil
        }
        data.history.removeAll { $0.id == savedSession.id }
        data.history.append(savedSession)
        data.history.sort { $0.date > $1.date }
    }

    func discardActiveWorkout() {
        data.activeSession = nil
    }

    func completeActiveWorkout() {
        guard var session = data.activeSession else { return }
        session.date = now()
        session.isSeededHistory = false
        data.history.insert(session, at: 0)
        data.activeSession = nil
    }

    func resetFromBundledTracker() {
        let seedData = importer.enrichedExerciseData(for: importer.loadSeedData())
        data = Self.migratingWeeklyPlans(in: seedData, for: now(), calendar: calendar)
    }

    private func makeSession(
        from template: WorkoutTemplate,
        plannedOccurrenceID: UUID?
    ) -> WorkoutSession {
        let exercises = template.exercises.map { templateExercise -> LoggedExercise in
            let lastLogged = WorkoutHistoryDefaults.latestLoggedExercise(
                matching: templateExercise,
                in: data.history
            )
            let seededSets = WorkoutHistoryDefaults.makeSets(
                targetSetCount: templateExercise.targetSetCount,
                targetRepsText: templateExercise.targetRepsText,
                lastLogged: lastLogged
            )

            return LoggedExercise(
                templateExerciseId: templateExercise.id,
                name: templateExercise.name,
                order: templateExercise.order,
                targetSetsText: templateExercise.targetSetsText,
                targetRepsText: templateExercise.targetRepsText,
                supersetGroupId: templateExercise.supersetGroupId,
                supersetName: templateExercise.supersetName,
                notes: "",
                sets: seededSets
            )
        }

        return WorkoutSession(
            date: now(),
            workoutName: template.name,
            bodyweight: "",
            duration: "",
            notes: "",
            isSeededHistory: false,
            plannedOccurrenceID: plannedOccurrenceID,
            exercises: exercises
        )
    }

}

enum WorkoutHistoryDefaults {
    static func makeSets(
        targetSetCount: Int,
        targetRepsText: String,
        lastLogged: LoggedExercise?
    ) -> [LoggedSet] {
        let previousSets = Array(lastLogged?.sets.prefix(targetSetCount) ?? [])
        let inferredUnit = previousSets.first?.loadUnit ?? .lb

        return (0..<targetSetCount).map { index in
            let previous = previousSets.indices.contains(index) ? previousSets[index] : nil

            return LoggedSet(
                order: index + 1,
                loadValue: previous?.loadValue,
                loadUnit: previous?.loadUnit ?? inferredUnit,
                repsValue: previous?.repsValue,
                previousLoadValue: previous?.loadValue,
                previousLoadUnit: previous?.loadUnit,
                previousRepsValue: previous?.repsValue,
                previousLoadText: previous?.loadLabel ?? "",
                previousRepsText: previous?.repsLabel ?? "",
                detailText: "",
                isCompleted: false
            )
        }
    }

    static func latestLoggedExercise(
        matching templateExercise: TemplateExercise,
        in history: [WorkoutSession]
    ) -> LoggedExercise? {
        let sessions = history
            .sorted { $0.date > $1.date }
        let exactIdentityMatch = sessions
            .flatMap(\.exercises)
            .first { $0.templateExerciseId == templateExercise.id }

        if let exactIdentityMatch {
            return exactIdentityMatch
        }

        let normalizedName = templateExercise.name.normalizedExerciseName
        return sessions
            .flatMap(\.exercises)
            .first { exercise in
                exercise.templateExerciseId == nil &&
                    exercise.name.normalizedExerciseName == normalizedName
            }
    }
}

@MainActor
private extension WorkoutStore {

    func ensurePlanExists(for date: Date) {
        let migratedData = Self.migratingWeeklyPlans(
            in: data,
            for: date,
            calendar: calendar,
            associateLegacySessions: false
        )
        if migratedData != data {
            data = migratedData
        }
    }

    func currentPlanIndex(for date: Date) -> Int? {
        let weekStart = Self.mondayWeekStart(for: date, calendar: calendar)
        return data.weeklyPlans.firstIndex {
            calendar.isDate($0.weekStart, inSameDayAs: weekStart)
        }
    }

    func isOccurrence(_ occurrenceID: UUID, validFor date: Date) -> Bool {
        data.weeklyPlans.contains { plan in
            let interval = Self.mondayWeekInterval(for: plan.weekStart, calendar: calendar)
            return interval.contains(date) && plan.occurrences.contains { $0.id == occurrenceID }
        }
    }

    func normalizeExerciseOrders(in template: inout WorkoutTemplate) {
        template.exercises.sort { $0.order < $1.order }
        for index in template.exercises.indices {
            template.exercises[index].order = index
        }
    }

    func normalizeOccurrenceOrders(in plan: inout WeeklyWorkoutPlan) {
        for index in plan.occurrences.indices {
            plan.occurrences[index].order = index
        }
    }

    private func save() {
        guard let encoded = try? JSONEncoder.gymAppEncoder.encode(data) else {
            return
        }

        try? encoded.write(to: saveURL, options: [.atomic])
    }

    private static func load(from url: URL) -> GymAppData? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? JSONDecoder.gymAppDecoder.decode(GymAppData.self, from: data)
    }

    static func migratingWeeklyPlans(
        in sourceData: GymAppData,
        for date: Date,
        calendar: Calendar,
        associateLegacySessions: Bool = true
    ) -> GymAppData {
        var data = sourceData
        for index in data.weeklyPlans.indices {
            data.weeklyPlans[index].weekStart = mondayWeekStart(
                for: data.weeklyPlans[index].weekStart,
                calendar: calendar
            )
            for occurrenceIndex in data.weeklyPlans[index].occurrences.indices {
                data.weeklyPlans[index].occurrences[occurrenceIndex].order = occurrenceIndex
            }
        }

        let requestedWeekStart = mondayWeekStart(for: date, calendar: calendar)
        let hasRequestedWeek = data.weeklyPlans.contains {
            calendar.isDate($0.weekStart, inSameDayAs: requestedWeekStart)
        }

        if !hasRequestedWeek {
            let sourceOccurrences = data.weeklyPlans
                .filter { $0.weekStart < requestedWeekStart }
                .sorted { $0.weekStart > $1.weekStart }
                .first?
                .occurrences
                .sorted { $0.order < $1.order }

            let occurrences: [PlannedWorkoutOccurrence]
            if let sourceOccurrences {
                occurrences = sourceOccurrences.enumerated().map { index, occurrence in
                    PlannedWorkoutOccurrence(templateID: occurrence.templateID, order: index)
                }
            } else {
                occurrences = data.templates
                    .sorted { $0.order < $1.order }
                    .enumerated()
                    .map { index, template in
                        PlannedWorkoutOccurrence(templateID: template.id, order: index)
                    }
            }

            data.weeklyPlans.append(
                WeeklyWorkoutPlan(
                    weekStart: requestedWeekStart,
                    occurrences: occurrences
                )
            )
        }

        guard associateLegacySessions else {
            data.weeklyPlans.sort { $0.weekStart < $1.weekStart }
            return data
        }

        for plan in data.weeklyPlans {
            let interval = mondayWeekInterval(for: plan.weekStart, calendar: calendar)
            var candidateSessionIndices = data.history.indices
                .filter { data.history[$0].plannedOccurrenceID == nil && interval.contains(data.history[$0].date) }
                .sorted { data.history[$0].date < data.history[$1].date }

            for occurrence in plan.occurrences.sorted(by: { $0.order < $1.order }) {
                guard let template = data.templates.first(where: { $0.id == occurrence.templateID }),
                      let candidateOffset = candidateSessionIndices.firstIndex(where: { sessionIndex in
                          data.history[sessionIndex].workoutName.normalizedExerciseName == template.name.normalizedExerciseName
                      }) else {
                    continue
                }

                let sessionIndex = candidateSessionIndices.remove(at: candidateOffset)
                data.history[sessionIndex].plannedOccurrenceID = occurrence.id
            }
        }

        data.weeklyPlans.sort { $0.weekStart < $1.weekStart }
        return data
    }

    private static func applyingCurrentPlanUpdates(to data: GymAppData) -> GymAppData {
        var data = data

        for templateIndex in data.templates.indices {
            let normalizedTemplateName = data.templates[templateIndex].name.normalizedExerciseName

            switch normalizedTemplateName {
            case "push":
                for exerciseIndex in data.templates[templateIndex].exercises.indices {
                    let exercise = data.templates[templateIndex].exercises[exerciseIndex]
                    let normalizedName = exercise.name.normalizedExerciseName

                    if normalizedName == "machine chest press" ||
                        (exercise.order == 1 && normalizedName.contains("chest press")) {
                        data.templates[templateIndex].exercises[exerciseIndex].name = "Flat Chest Press"
                    }
                }

            case "pull":
                data.templates[templateIndex].exercises.removeAll { exercise in
                    let normalizedName = exercise.name.normalizedExerciseName
                    return normalizedName == "cable row" || normalizedName == "rear delt"
                }

                if let latIndex = data.templates[templateIndex].exercises.firstIndex(where: { $0.name.normalizedExerciseName == "lat pulldown wide" }),
                   let facePullIndex = data.templates[templateIndex].exercises.firstIndex(where: { $0.name.normalizedExerciseName == "face pull" }) {
                    let groupId = data.templates[templateIndex].exercises[latIndex].supersetGroupId ??
                        data.templates[templateIndex].exercises[facePullIndex].supersetGroupId ??
                        UUID()
                    let groupName = "Lat Pulldown Wide + Face Pull"

                    data.templates[templateIndex].exercises[latIndex].supersetGroupId = groupId
                    data.templates[templateIndex].exercises[latIndex].supersetName = groupName
                    data.templates[templateIndex].exercises[facePullIndex].supersetGroupId = groupId
                    data.templates[templateIndex].exercises[facePullIndex].supersetName = groupName
                }

                compactExerciseOrders(in: &data.templates[templateIndex])

            case "legs":
                data.templates[templateIndex].exercises.removeAll { exercise in
                    exercise.name.normalizedExerciseName == "side step up"
                }

                for exerciseIndex in data.templates[templateIndex].exercises.indices {
                    if data.templates[templateIndex].exercises[exerciseIndex].name.normalizedExerciseName == "copenhagen plank" {
                        data.templates[templateIndex].exercises[exerciseIndex].name = "Side Plank"
                    }
                }

                compactExerciseOrders(in: &data.templates[templateIndex])

            default:
                break
            }
        }

        return data
    }

    private static func compactExerciseOrders(in template: inout WorkoutTemplate) {
        template.exercises.sort { left, right in
            if left.order != right.order {
                return left.order < right.order
            }

            return left.name.localizedStandardCompare(right.name) == .orderedAscending
        }

        for exerciseIndex in template.exercises.indices {
            template.exercises[exerciseIndex].order = exerciseIndex
        }
    }

    private static let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func weeklyDisplayName(for name: String) -> String {
        if name.normalizedExerciseName == "zone 2 cardio" {
            return "Zone 2"
        }

        return name
    }

    static func mondayWeekStart(for date: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let daysSinceMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: day) ?? day
    }

    static func mondayWeekInterval(for date: Date, calendar: Calendar) -> DateInterval {
        let start = mondayWeekStart(for: date, calendar: calendar)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return DateInterval(start: start, end: end)
    }
}

struct WeeklyWorkoutStatus: Identifiable, Equatable {
    var id: UUID { occurrence.id }
    let occurrence: PlannedWorkoutOccurrence
    let template: WorkoutTemplate
    let displayName: String
    let loggedSession: WorkoutSession?

    var isLogged: Bool {
        loggedSession != nil
    }
}

private extension JSONEncoder {
    static var gymAppEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var gymAppDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
