import Foundation

struct ExerciseCatalogLoader {
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
}

private struct ExercemusExerciseCatalog: Decodable {
    let exercises: [ExerciseDefinition]
}
