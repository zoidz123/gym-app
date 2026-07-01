import Foundation

struct MarkdownWorkoutImporter {
    private let headingSeparator = " " + String(UnicodeScalar(0x2014)!) + " "
    private let lineSeparator = " " + String(UnicodeScalar(0x2014)!) + " "

    func loadSeedData(bundle: Bundle = .main) -> GymAppData {
        let templates = loadPlan(bundle: bundle)
        let history = loadHistory(bundle: bundle)
        let exerciseDefinitions = buildExerciseDefinitions(
            bundle: bundle,
            templates: templates,
            history: history,
            existingNames: []
        )

        return GymAppData(
            templates: templates,
            history: history.sorted { $0.date > $1.date },
            activeSession: nil,
            exerciseLibrary: exerciseDefinitions.map(\.name),
            exerciseDefinitions: exerciseDefinitions
        )
    }

    func enrichedExerciseData(for data: GymAppData, bundle: Bundle = .main) -> GymAppData {
        var enrichedData = data
        let exerciseDefinitions = buildExerciseDefinitions(
            bundle: bundle,
            templates: data.templates,
            history: data.history,
            existingNames: data.exerciseLibrary
        )

        enrichedData.exerciseDefinitions = exerciseDefinitions
        enrichedData.exerciseLibrary = exerciseDefinitions.map(\.name)
        return enrichedData
    }

    private func loadPlan(bundle: Bundle) -> [WorkoutTemplate] {
        guard let url = bundle.url(forResource: "plan", withExtension: "md"),
              let markdown = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }

        return parsePlan(markdown)
    }

    private func loadHistory(bundle: Bundle) -> [WorkoutSession] {
        let resourceNames = ["2026-04", "2026-05", "2026-06"]

        return resourceNames.flatMap { name -> [WorkoutSession] in
            guard let url = bundle.url(forResource: name, withExtension: "md"),
                  let markdown = try? String(contentsOf: url, encoding: .utf8) else {
                return []
            }

            return parseLog(markdown)
        }
    }

    private func loadBundledExerciseDefinitions(bundle: Bundle) -> [ExerciseDefinition] {
        guard let url = bundle.url(forResource: "exercemus-exercises", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        guard let catalog = try? decoder.decode(ExercemusExerciseCatalog.self, from: data) else {
            return []
        }

        return catalog.exercises
    }

    private func buildExerciseDefinitions(
        bundle: Bundle,
        templates: [WorkoutTemplate],
        history: [WorkoutSession],
        existingNames: [String]
    ) -> [ExerciseDefinition] {
        var definitionsByName: [String: ExerciseDefinition] = [:]

        for definition in loadBundledExerciseDefinitions(bundle: bundle) {
            definitionsByName[definition.name.normalizedExerciseName] = definition
        }

        for name in buildExerciseLibrary(templates: templates, history: history) + existingNames {
            let normalizedName = name.normalizedExerciseName

            guard !normalizedName.isEmpty,
                  definitionsByName[normalizedName] == nil else {
                continue
            }

            definitionsByName[normalizedName] = ExerciseDefinition(name: name)
        }

        return definitionsByName.values.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    func parsePlan(_ markdown: String) -> [WorkoutTemplate] {
        var templates: [WorkoutTemplate] = []
        var currentName: String?
        var currentExercises: [TemplateExercise] = []

        func flushCurrentTemplate() {
            guard let currentName, !currentExercises.isEmpty else { return }
            templates.append(
                WorkoutTemplate(
                    name: currentName,
                    order: templates.count,
                    exercises: currentExercises
                )
            )
        }

        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = rawLine.trimmed

            if line.hasPrefix("# ") {
                let heading = String(line.dropFirst(2)).trimmed
                if heading != "Workout Plan" {
                    flushCurrentTemplate()
                    currentName = heading
                    currentExercises = []
                }
                continue
            }

            guard let planItem = parsePlanItem(line, order: currentExercises.count) else {
                continue
            }

            currentExercises.append(contentsOf: planItem)
        }

        flushCurrentTemplate()
        return templates
    }

    private func parsePlanItem(_ line: String, order: Int) -> [TemplateExercise]? {
        guard let dotIndex = line.firstIndex(of: "."),
              Int(String(line[..<dotIndex]).trimmed) != nil else {
            return nil
        }

        let body = String(line[line.index(after: dotIndex)...]).trimmed
        let parts = body.components(separatedBy: lineSeparator)

        guard parts.count >= 2 else { return nil }

        let exercisePart = parts[0].trimmed
        let targetSetsText = parts.count >= 3 ? parts[1].trimmed : "1 entry"
        let repsPart = parts.count >= 3 ? parts.dropFirst(2).joined(separator: lineSeparator).trimmed : parts[1].trimmed
        let names = exercisePart.components(separatedBy: " + ").map(\.trimmed).filter { !$0.isEmpty }
        let repParts = repsPart.components(separatedBy: " / ").map(\.trimmed)
        let targetSetCount = max(numbers(in: targetSetsText).max() ?? 1, 1)
        let groupId = names.count > 1 ? UUID() : nil
        let groupName = names.count > 1 ? names.joined(separator: " + ") : nil

        return names.enumerated().map { index, name in
            let targetRepsText = repParts.indices.contains(index) ? repParts[index] : repsPart
            return TemplateExercise(
                name: name,
                order: order + index,
                targetSetsText: targetSetsText,
                targetRepsText: targetRepsText,
                targetSetCount: targetSetCount,
                supersetGroupId: groupId,
                supersetName: groupName
            )
        }
    }

    func parseLog(_ markdown: String) -> [WorkoutSession] {
        let lines = markdown.components(separatedBy: .newlines)
        var sessions: [WorkoutSession] = []
        var currentHeading: String?
        var currentBody: [String] = []

        func flushCurrentSession() {
            guard let currentHeading,
                  let session = parseSession(heading: currentHeading, body: currentBody) else {
                return
            }

            sessions.append(session)
        }

        for line in lines {
            if line.hasPrefix("## ") {
                flushCurrentSession()
                currentHeading = String(line.dropFirst(3)).trimmed
                currentBody = []
            } else if currentHeading != nil {
                currentBody.append(line)
            }
        }

        flushCurrentSession()
        return sessions
    }

    private func parseSession(heading: String, body: [String]) -> WorkoutSession? {
        let headingParts = heading.components(separatedBy: headingSeparator)
        guard headingParts.count >= 2,
              let date = Self.dateFormatter.date(from: headingParts[0].trimmed) else {
            return nil
        }

        let workoutName = headingParts.dropFirst().joined(separator: " - ").trimmed
        var bodyweight = ""
        var duration = ""
        var notes: [String] = []
        var exercises: [LoggedExercise] = []
        var index = 0

        while index < body.count {
            let line = body[index]
            let trimmed = line.trimmed

            if trimmed.hasPrefix("Bodyweight:") {
                bodyweight = String(trimmed.dropFirst("Bodyweight:".count)).trimmed
                index += 1
                continue
            }

            if trimmed.hasPrefix("Duration:") || trimmed.hasPrefix("Cardio:") {
                let value = trimmed.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmed
                duration = duration.isEmpty ? value : [duration, value].joined(separator: ", ")
                index += 1
                continue
            }

            if trimmed.hasPrefix("Notes:") || trimmed.hasPrefix("Note:") {
                notes.append(trimmed.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmed)
                index += 1
                continue
            }

            if line.hasPrefix("- ") {
                let bullet = String(line.dropFirst(2)).trimmed
                let parsed = parseTopLevelBullet(bullet: bullet, body: body, startIndex: index, exerciseOrder: exercises.count)
                exercises.append(contentsOf: parsed.exercises)
                index = parsed.nextIndex
                continue
            }

            index += 1
        }

        return WorkoutSession(
            date: date,
            workoutName: workoutName,
            bodyweight: bodyweight,
            duration: duration,
            notes: notes.filter { !$0.isEmpty }.joined(separator: "\n"),
            isSeededHistory: true,
            exercises: exercises
        )
    }

    private func parseTopLevelBullet(
        bullet: String,
        body: [String],
        startIndex: Int,
        exerciseOrder: Int
    ) -> (exercises: [LoggedExercise], nextIndex: Int) {
        let pair = splitNameAndValue(bullet)
        let name = pair.name
        let value = pair.value

        if value.isEmpty {
            let groupId = UUID()
            var groupExercises: [LoggedExercise] = []
            var index = startIndex + 1

            while index < body.count {
                let line = body[index]

                guard line.hasPrefix("  - ") else {
                    break
                }

                let nestedBullet = String(line.dropFirst(4)).trimmed
                let nestedPair = splitNameAndValue(nestedBullet)

                if shouldSkipNestedBullet(named: nestedPair.name) {
                    index += 1
                    continue
                }

                groupExercises.append(
                    LoggedExercise(
                        templateExerciseId: nil,
                        name: nestedPair.name,
                        order: exerciseOrder + groupExercises.count,
                        targetSetsText: "",
                        targetRepsText: "",
                        supersetGroupId: groupId,
                        supersetName: name,
                        notes: "",
                        sets: parseSetEntries(from: nestedPair.value)
                    )
                )

                index += 1
            }

            return (groupExercises, index)
        }

        let exercise = LoggedExercise(
            templateExerciseId: nil,
            name: name,
            order: exerciseOrder,
            targetSetsText: "",
            targetRepsText: "",
            supersetGroupId: nil,
            supersetName: nil,
            notes: "",
            sets: parseSetEntries(from: value)
        )

        return ([exercise], startIndex + 1)
    }

    private func shouldSkipNestedBullet(named name: String) -> Bool {
        let normalized = name.normalizedExerciseName
        return normalized == "note" || normalized == "subbed for"
    }

    private func splitNameAndValue(_ bullet: String) -> (name: String, value: String) {
        guard let colonIndex = bullet.firstIndex(of: ":") else {
            return (bullet.trimmed, "")
        }

        let name = String(bullet[..<colonIndex]).trimmed
        let value = String(bullet[bullet.index(after: colonIndex)...]).trimmed
        return (name, value)
    }

    func parseSetEntries(from rawValue: String) -> [LoggedSet] {
        let value = rawValue.trimmed
        guard !value.isEmpty else { return [] }

        if value.lowercased().contains("skipped") {
            return [
                LoggedSet(
                    order: 1,
                    loadValue: nil,
                    loadUnit: .custom,
                    repsValue: nil,
                    previousLoadValue: nil,
                    previousLoadUnit: nil,
                    previousRepsValue: nil,
                    previousLoadText: "",
                    previousRepsText: "",
                    detailText: value,
                    isCompleted: false
                )
            ]
        }

        let tokens = value
            .replacingOccurrences(of: ";", with: ",")
            .components(separatedBy: ",")
            .map(\.trimmed)
            .filter { !$0.isEmpty }

        var sets: [LoggedSet] = []
        var currentLoad = ParsedLoad(value: nil, unit: LoadUnit.custom, detail: "")

        for token in tokens {
            let tokenParts = splitLoadAndReps(token)
            var repsText = token

            if let loadPart = tokenParts.load, !loadPart.isEmpty {
                currentLoad = parseLoad(loadPart)
                repsText = tokenParts.reps
            }

            let repValue = firstNumber(in: repsText).map(Int.init)
            sets.append(
                LoggedSet(
                    order: sets.count + 1,
                    loadValue: currentLoad.value,
                    loadUnit: currentLoad.unit,
                    repsValue: repValue,
                    previousLoadValue: nil,
                    previousLoadUnit: nil,
                    previousRepsValue: nil,
                    previousLoadText: "",
                    previousRepsText: "",
                    detailText: repValue == nil ? repsText : "",
                    isCompleted: repValue != nil || !repsText.isEmpty
                )
            )
        }

        return sets.isEmpty ? [
            LoggedSet(
                order: 1,
                loadValue: nil,
                loadUnit: .custom,
                repsValue: nil,
                previousLoadValue: nil,
                previousLoadUnit: nil,
                previousRepsValue: nil,
                previousLoadText: "",
                previousRepsText: "",
                detailText: value,
                isCompleted: true
            )
        ] : sets
    }

    private func splitLoadAndReps(_ token: String) -> (load: String?, reps: String) {
        let lowercased = token.lowercased()
        guard let range = lowercased.range(of: " x ") ?? lowercased.range(of: "x ") else {
            return (nil, token)
        }

        let load = String(token[..<range.lowerBound]).trimmed
        let reps = String(token[range.upperBound...]).trimmed
        return (load, reps)
    }

    private struct ParsedLoad {
        var value: Double?
        var unit: LoadUnit
        var detail: String
    }

    private func parseLoad(_ rawValue: String) -> ParsedLoad {
        let value = rawValue.trimmed
        let lowercased = value.lowercased()

        if lowercased == "bw" || lowercased.hasPrefix("bw ") {
            return ParsedLoad(value: nil, unit: .bodyweight, detail: value)
        }

        if lowercased.contains("machine") {
            return ParsedLoad(value: firstNumber(in: value), unit: .machine, detail: value)
        }

        if lowercased.contains("sec") {
            return ParsedLoad(value: firstNumber(in: value), unit: .seconds, detail: value)
        }

        if lowercased.contains("min") {
            return ParsedLoad(value: firstNumber(in: value), unit: .minutes, detail: value)
        }

        let unit: LoadUnit
        if lowercased.contains("kg") {
            unit = .kg
        } else if lowercased.contains("lb") {
            unit = .lb
        } else {
            unit = .custom
        }

        return ParsedLoad(value: firstNumber(in: value), unit: unit, detail: value)
    }

    private func buildExerciseLibrary(templates: [WorkoutTemplate], history: [WorkoutSession]) -> [String] {
        let names = templates.flatMap(\.exercises).map(\.name) + history.flatMap(\.exercises).map(\.name)
        var seen = Set<String>()

        return names
            .map(\.trimmed)
            .filter { !$0.isEmpty }
            .filter { name in
                let normalized = name.normalizedExerciseName
                guard !seen.contains(normalized) else { return false }
                seen.insert(normalized)
                return true
            }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func numbers(in value: String) -> [Int] {
        matches(pattern: #"\d+"#, in: value).compactMap(Int.init)
    }

    private func firstNumber(in value: String) -> Double? {
        matches(pattern: #"\d+(?:\.\d+)?"#, in: value).first.flatMap(Double.init)
    }

    private func matches(pattern: String, in value: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let range = NSRange(value.startIndex..., in: value)
        return regex.matches(in: value, range: range).compactMap { result in
            guard let matchRange = Range(result.range, in: value) else { return nil }
            return String(value[matchRange])
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct ExercemusExerciseCatalog: Decodable {
    let exercises: [ExerciseDefinition]
}
