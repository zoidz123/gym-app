import Foundation

struct MarkdownWorkoutImporter {
    private let lineSeparator = " " + String(UnicodeScalar(0x2014)!) + " "

    func loadSeedData(bundle: Bundle = .main) -> GymAppData {
        let templates = loadPlan(bundle: bundle)
        let exerciseDefinitions = buildExerciseDefinitions(
            bundle: bundle,
            templates: templates,
            history: [],
            existingNames: []
        )

        return GymAppData(
            templates: templates,
            history: [],
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
        let parts = body
            .replacingOccurrences(of: " - ", with: lineSeparator)
            .components(separatedBy: lineSeparator)

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
}

private struct ExercemusExerciseCatalog: Decodable {
    let exercises: [ExerciseDefinition]
}
