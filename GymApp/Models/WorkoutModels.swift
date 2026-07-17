import Foundation

enum LoadUnit: String, Codable, CaseIterable, Identifiable {
    case kg
    case lb
    case bodyweight
    case machine
    case seconds
    case minutes
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .kg: "kg"
        case .lb: "lb"
        case .bodyweight: "BW"
        case .machine: "machine"
        case .seconds: "sec"
        case .minutes: "min"
        case .custom: "custom"
        }
    }

    var defaultStep: Double {
        switch self {
        case .kg: 2.5
        case .lb: 5
        case .machine: 5
        case .seconds: 5
        case .minutes: 1
        case .bodyweight, .custom: 1
        }
    }

    var usesLoadValue: Bool {
        self != .bodyweight && self != .custom
    }

    var isTime: Bool {
        self == .seconds || self == .minutes
    }

    var entryPickerLabel: String {
        isTime ? "time" : label
    }
}

struct LoggedSet: Identifiable, Codable, Equatable {
    var id = UUID()
    var order: Int
    var loadValue: Double?
    var loadUnit: LoadUnit
    var repsValue: Int?
    var previousLoadValue: Double?
    var previousLoadUnit: LoadUnit?
    var previousRepsValue: Int?
    var previousLoadText: String
    var previousRepsText: String
    var detailText: String
    var isCompleted: Bool

    static func blank(order: Int, unit: LoadUnit = .lb) -> LoggedSet {
        LoggedSet(
            order: order,
            loadValue: unit.usesLoadValue ? 0 : nil,
            loadUnit: unit,
            repsValue: nil,
            previousLoadValue: nil,
            previousLoadUnit: nil,
            previousRepsValue: nil,
            previousLoadText: "",
            previousRepsText: "",
            detailText: "",
            isCompleted: false
        )
    }

    var loadLabel: String {
        if loadUnit == .bodyweight {
            return loadUnit.label
        }

        if let loadValue {
            return "\(loadValue.cleanString) \(loadUnit.label)"
        }

        return detailText.isEmpty ? loadUnit.label : detailText
    }

    var repsLabel: String {
        if let repsValue {
            return "\(repsValue)"
        }

        return detailText.isEmpty ? "-" : detailText
    }

    var previousLabel: String {
        let load = previousLoadText.isEmpty ? "-" : previousLoadText
        let reps = previousRepsText.isEmpty ? "-" : previousRepsText
        return "\(load) x \(reps)"
    }

    mutating func usePreviousValues() {
        loadValue = previousLoadValue
        loadUnit = previousLoadUnit ?? loadUnit
        repsValue = previousRepsValue
        isCompleted = true
    }

    mutating func adjustLoad(by delta: Double) {
        guard loadUnit.usesLoadValue else { return }
        let currentValue = loadValue ?? 0
        loadValue = max(0, currentValue + delta)
        isCompleted = true
    }

    mutating func adjustReps(by delta: Int) {
        let currentValue = repsValue ?? 0
        repsValue = max(0, currentValue + delta)
        isCompleted = true
    }
}

struct LoggedExercise: Identifiable, Codable, Equatable {
    var id = UUID()
    var templateExerciseId: UUID?
    var name: String
    var order: Int
    var targetSetsText: String
    var targetRepsText: String
    var supersetGroupId: UUID?
    var supersetName: String?
    var notes: String
    var sets: [LoggedSet]

    var isSupersetMember: Bool {
        supersetGroupId != nil
    }

    mutating func addBlankSet() {
        let nextOrder = (sets.map(\.order).max() ?? 0) + 1
        let unit = sets.last?.loadUnit ?? .lb
        sets.append(.blank(order: nextOrder, unit: unit))
    }
}

struct ExerciseDefinition: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var aliases: [String]
    var equipment: [String]
    var primaryMuscles: [String]
    var secondaryMuscles: [String]

    init(
        id: String? = nil,
        name: String,
        aliases: [String] = [],
        equipment: [String] = [],
        primaryMuscles: [String] = [],
        secondaryMuscles: [String] = []
    ) {
        self.name = name
        self.id = id ?? name.normalizedExerciseName.replacingOccurrences(of: " ", with: "-")
        self.aliases = aliases
        self.equipment = equipment
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
    }

    var metadataText: String {
        let muscles = primaryMuscles.prefix(2).joined(separator: ", ")
        let tools = equipment.prefix(2).joined(separator: ", ")
        return [muscles, tools].filter { !$0.isEmpty }.joined(separator: " - ")
    }

    var searchableNames: [String] {
        ([name] + aliases).map(\.normalizedExerciseName)
    }

    var searchableText: String {
        (searchableNames + equipment.map(\.normalizedExerciseName) + primaryMuscles.map(\.normalizedExerciseName) + secondaryMuscles.map(\.normalizedExerciseName))
            .joined(separator: " ")
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case aliases
        case equipment
        case primaryMuscles
        case secondaryMuscles
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let sourceContainer = try? decoder.container(keyedBy: SourceCodingKeys.self)
        let decodedName = try container.decode(String.self, forKey: .name)
        let decodedAliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
        let variations = (try sourceContainer?.decodeIfPresent([String].self, forKey: .variationOn) ?? []) +
            (try sourceContainer?.decodeIfPresent([String].self, forKey: .variationsOn) ?? [])

        self.init(
            id: try container.decodeIfPresent(String.self, forKey: .id),
            name: decodedName,
            aliases: decodedAliases + variations,
            equipment: try container.decodeIfPresent([String].self, forKey: .equipment) ?? [],
            primaryMuscles: try container.decodeIfPresent([String].self, forKey: .primaryMuscles) ?? [],
            secondaryMuscles: try container.decodeIfPresent([String].self, forKey: .secondaryMuscles) ?? []
        )
    }

    private enum SourceCodingKeys: String, CodingKey {
        case variationOn
        case variationsOn
    }
}

enum ExerciseSearch {
    static func rankedDefinitions(_ definitions: [ExerciseDefinition], matching rawQuery: String) -> [ExerciseDefinition] {
        let query = rawQuery.normalizedExerciseName

        guard !query.isEmpty else {
            return Array(definitions.prefix(12))
        }

        let queryTokens = query.components(separatedBy: " ").filter { !$0.isEmpty }

        return definitions
            .compactMap { definition -> (ExerciseDefinition, Int)? in
                let searchableNames = definition.searchableNames

                if searchableNames.contains(query) {
                    return (definition, 0)
                }

                if searchableNames.contains(where: { $0.hasPrefix(query) }) {
                    return (definition, 1)
                }

                if definition.name.normalizedExerciseName.contains(query) {
                    return (definition, 2)
                }

                if searchableNames.contains(where: { $0.contains(query) }) {
                    return (definition, 3)
                }

                if queryTokens.allSatisfy({ definition.searchableText.contains($0) }) {
                    return (definition, 4)
                }

                return nil
            }
            .sorted { left, right in
                if left.1 != right.1 {
                    return left.1 < right.1
                }

                return left.0.name.localizedStandardCompare(right.0.name) == .orderedAscending
            }
            .map(\.0)
    }

    static func canonicalName(for rawName: String, in definitions: [ExerciseDefinition]) -> String {
        let normalizedName = rawName.normalizedExerciseName

        guard !normalizedName.isEmpty else {
            return rawName.trimmed
        }

        return definitions.first { definition in
            definition.searchableNames.contains(normalizedName)
        }?.name ?? rawName.trimmed
    }
}

struct WorkoutSession: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: Date
    var workoutName: String
    var bodyweight: String
    var duration: String
    var notes: String
    var isSeededHistory: Bool
    var plannedOccurrenceID: UUID? = nil
    var exercises: [LoggedExercise]

    var completedSetCount: Int {
        exercises.flatMap(\.sets).filter(\.isCompleted).count
    }

    var totalSetCount: Int {
        exercises.flatMap(\.sets).count
    }
}

struct TemplateExercise: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var order: Int
    var targetSetsText: String
    var targetRepsText: String
    var targetSetCount: Int
    var supersetGroupId: UUID?
    var supersetName: String?
}

struct WorkoutTemplate: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var order: Int
    var exercises: [TemplateExercise]

    var supersetCount: Int {
        Set(exercises.compactMap(\.supersetGroupId)).count
    }
}

struct PlannedWorkoutOccurrence: Identifiable, Codable, Equatable {
    var id = UUID()
    var templateID: UUID
    var order: Int
}

struct WeeklyWorkoutPlan: Identifiable, Codable, Equatable {
    var id = UUID()
    var weekStart: Date
    var occurrences: [PlannedWorkoutOccurrence]
}

struct GymAppData: Codable, Equatable {
    var templates: [WorkoutTemplate]
    var weeklyPlans: [WeeklyWorkoutPlan]
    var history: [WorkoutSession]
    var activeSession: WorkoutSession?
    var exerciseLibrary: [String]
    var exerciseDefinitions: [ExerciseDefinition]

    init(
        templates: [WorkoutTemplate],
        weeklyPlans: [WeeklyWorkoutPlan] = [],
        history: [WorkoutSession],
        activeSession: WorkoutSession?,
        exerciseLibrary: [String],
        exerciseDefinitions: [ExerciseDefinition] = []
    ) {
        self.templates = templates
        self.weeklyPlans = weeklyPlans
        self.history = history
        self.activeSession = activeSession
        self.exerciseLibrary = exerciseLibrary
        self.exerciseDefinitions = exerciseDefinitions
    }

    static let empty = GymAppData(templates: [], history: [], activeSession: nil, exerciseLibrary: [])

    private enum CodingKeys: String, CodingKey {
        case templates
        case weeklyPlans
        case history
        case activeSession
        case exerciseLibrary
        case exerciseDefinitions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        templates = try container.decode([WorkoutTemplate].self, forKey: .templates)
        weeklyPlans = try container.decodeIfPresent([WeeklyWorkoutPlan].self, forKey: .weeklyPlans) ?? []
        history = try container.decode([WorkoutSession].self, forKey: .history)
        activeSession = try container.decodeIfPresent(WorkoutSession.self, forKey: .activeSession)
        exerciseLibrary = try container.decodeIfPresent([String].self, forKey: .exerciseLibrary) ?? []
        exerciseDefinitions = try container.decodeIfPresent([ExerciseDefinition].self, forKey: .exerciseDefinitions) ?? []
    }
}

extension Double {
    var cleanString: String {
        if truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(self))
        }

        return String(format: "%.1f", self)
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedExerciseName: String {
        lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
