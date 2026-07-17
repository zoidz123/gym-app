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

    init(
        importer: MarkdownWorkoutImporter = MarkdownWorkoutImporter(),
        fileManager: FileManager = .default
    ) {
        self.importer = importer
        let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = supportURL.appendingPathComponent("GymApp", isDirectory: true)
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        saveURL = appDirectory.appendingPathComponent("gym-data.json")

        if let storedData = Self.load(from: saveURL) {
            let migratedData = Self.applyingCurrentPlanUpdates(to: storedData)
            data = importer.enrichedExerciseData(for: migratedData)
            if data != storedData {
                save()
            }
        } else {
            data = importer.enrichedExerciseData(for: Self.applyingCurrentPlanUpdates(to: importer.loadSeedData()))
            save()
        }

        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        let requestedTemplate = environment["UI_TEST_START_TEMPLATE"].flatMap { templateName in
            data.templates.first { $0.name.normalizedExerciseName == templateName.normalizedExerciseName }
        }
        let shouldStartSuggested = environment["UI_TEST_START_SUGGESTED"] == "1"

        if data.activeSession == nil,
           let template = requestedTemplate ?? (shouldStartSuggested ? suggestedTemplate : nil) {
            data.activeSession = makeSession(from: template)
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
        let weekday = Calendar.current.component(.weekday, from: Date())
        let scheduledName: String?

        switch weekday {
        case 2:
            scheduledName = "Push"
        case 3:
            scheduledName = "Pull"
        case 4:
            scheduledName = "Zone 2 Cardio"
        case 5:
            scheduledName = "Legs"
        case 6:
            scheduledName = "Zone 2 Cardio"
        default:
            scheduledName = nil
        }

        guard let scheduledName else { return nil }
        return data.templates.first { $0.name.normalizedExerciseName == scheduledName.normalizedExerciseName }
    }

    var weeklyWorkoutStatuses: [WeeklyWorkoutStatus] {
        let calendar = Calendar.current
        let weekInterval = Self.currentMondayWeekInterval(calendar: calendar)
        let plannedNames = ["Push", "Pull", "Zone 2 Cardio", "Legs", "Push 2", "HIIT"]

        return plannedNames.compactMap { plannedName in
            guard let template = data.templates.first(where: { $0.name.normalizedExerciseName == plannedName.normalizedExerciseName }) else {
                return nil
            }

            let matchingSession = data.history
                .filter { session in
                    return weekInterval.contains(session.date)
                }
                .sorted { $0.date > $1.date }
                .first { session in
                    session.workoutName.normalizedExerciseName == template.name.normalizedExerciseName
                }

            return WeeklyWorkoutStatus(
                template: template,
                displayName: Self.weeklyDisplayName(for: template.name),
                loggedSession: matchingSession
            )
        }
    }

    var todayLoggedSessions: [WorkoutSession] {
        data.history
            .filter { Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
    }

    var nextUnloggedWeeklyTemplate: WorkoutTemplate? {
        weeklyWorkoutStatuses.first { !$0.isLogged }?.template
    }

    func startWorkout(from template: WorkoutTemplate) {
        data.activeSession = makeSession(from: template)
    }

    func makeDraftSession(from template: WorkoutTemplate, date: Date = Date()) -> WorkoutSession {
        var session = makeSession(from: template)
        session.date = date
        return session
    }

    func saveWorkoutSession(_ session: WorkoutSession) {
        var savedSession = session
        savedSession.isSeededHistory = false
        data.history.removeAll { $0.id == savedSession.id }
        data.history.append(savedSession)
        data.history.sort { $0.date > $1.date }
    }

    func discardActiveWorkout() {
        data.activeSession = nil
    }

    func completeActiveWorkout() {
        guard var session = data.activeSession else { return }
        session.date = Date()
        session.isSeededHistory = false
        data.history.insert(session, at: 0)
        data.activeSession = nil
    }

    func resetFromBundledTracker() {
        data = importer.loadSeedData()
    }

    private func makeSession(from template: WorkoutTemplate) -> WorkoutSession {
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
            date: Date(),
            workoutName: template.name,
            bodyweight: "",
            duration: "",
            notes: "",
            isSeededHistory: false,
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

    private static func weeklyDisplayName(for name: String) -> String {
        if name.normalizedExerciseName == "zone 2 cardio" {
            return "Zone 2"
        }

        return name
    }

    private static func currentMondayWeekInterval(calendar: Calendar) -> DateInterval {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (weekday + 5) % 7
        let start = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? today
        return DateInterval(start: start, end: end)
    }
}

struct WeeklyWorkoutStatus: Identifiable, Equatable {
    var id: UUID { template.id }
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
