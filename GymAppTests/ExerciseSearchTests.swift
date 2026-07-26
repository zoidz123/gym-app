import XCTest
@testable import Stacked

final class ExerciseSearchTests: XCTestCase {
    func testMuscleGroupFilterUsesPrimaryMuscles() {
        let definitions = [
            ExerciseDefinition(name: "Bench Press", primaryMuscles: ["chest"]),
            ExerciseDefinition(name: "Barbell Row", primaryMuscles: ["lats"]),
            ExerciseDefinition(name: "Back Squat", primaryMuscles: ["quads"]),
            ExerciseDefinition(name: "Tricep Extension", primaryMuscles: ["triceps"])
        ]

        let chest = ExerciseSearch.rankedDefinitions(definitions, matching: "", muscleGroup: .chest)
        let back = ExerciseSearch.rankedDefinitions(definitions, matching: "", muscleGroup: .back)
        let legs = ExerciseSearch.rankedDefinitions(definitions, matching: "", muscleGroup: .legs)
        let arms = ExerciseSearch.rankedDefinitions(definitions, matching: "", muscleGroup: .arms)
        let all = ExerciseSearch.rankedDefinitions(definitions, matching: "", muscleGroup: .all)

        XCTAssertEqual(chest.map(\.name), ["Bench Press"])
        XCTAssertEqual(back.map(\.name), ["Barbell Row"])
        XCTAssertEqual(legs.map(\.name), ["Back Squat"])
        XCTAssertEqual(arms.map(\.name), ["Tricep Extension"])
        XCTAssertEqual(all.map(\.name), ExerciseSearch.rankedDefinitions(definitions, matching: "").map(\.name))
    }

    func testSearchAndMuscleGroupFilterCombineWithoutChangingSearchRanking() {
        let definitions = [
            ExerciseDefinition(name: "Bench Press", primaryMuscles: ["chest"]),
            ExerciseDefinition(name: "Incline Dumbbell Press", primaryMuscles: ["chest"]),
            ExerciseDefinition(name: "Overhead Press", primaryMuscles: ["shoulders"]),
            ExerciseDefinition(name: "Leg Press", primaryMuscles: ["quads"])
        ]

        let allPresses = ExerciseSearch.rankedDefinitions(definitions, matching: "press")
        let chestPresses = ExerciseSearch.rankedDefinitions(definitions, matching: "press", muscleGroup: .chest)
        let shoulderPresses = ExerciseSearch.rankedDefinitions(definitions, matching: "press", muscleGroup: .shoulders)

        XCTAssertEqual(allPresses.map(\.name), [
            "Bench Press",
            "Incline Dumbbell Press",
            "Leg Press",
            "Overhead Press"
        ])
        XCTAssertEqual(chestPresses.map(\.name), ["Bench Press", "Incline Dumbbell Press"])
        XCTAssertEqual(shoulderPresses.map(\.name), ["Overhead Press"])
    }
}
