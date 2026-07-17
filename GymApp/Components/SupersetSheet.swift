import SwiftUI

struct SupersetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var session: WorkoutSession
    let exerciseDefinitions: [ExerciseDefinition]

    @State private var firstName = ""
    @State private var secondName = ""
    @State private var setCount = 3
    @State private var targetReps = "8-12 reps"
    @State private var unit: LoadUnit = .lb

    var body: some View {
        NavigationStack {
            Form {
                ExerciseSearchField(
                    title: "First Exercise",
                    placeholder: "Exercise name",
                    text: $firstName,
                    exerciseDefinitions: exerciseDefinitions
                )

                ExerciseSearchField(
                    title: "Second Exercise",
                    placeholder: "Exercise name",
                    text: $secondName,
                    exerciseDefinitions: exerciseDefinitions
                )

                Section("Planned Sets") {
                    Stepper("\(setCount) sets", value: $setCount, in: 1...10)
                    TextField("Target reps", text: $targetReps)

                    Picker("Default unit", selection: $unit) {
                        ForEach([LoadUnit.lb, .kg, .bodyweight, .seconds]) { unit in
                            Text(unit.entryPickerLabel).tag(unit)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenBackground)
            .navigationTitle("Add Superset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addSuperset()
                    }
                    .disabled(!canAddSuperset)
                }
            }
        }
    }

    private var canAddSuperset: Bool {
        !firstName.trimmed.isEmpty &&
            !secondName.trimmed.isEmpty &&
            firstName.normalizedExerciseName != secondName.normalizedExerciseName
    }

    private func addSuperset() {
        let firstExerciseName = ExerciseSearch.canonicalName(for: firstName, in: exerciseDefinitions)
        let secondExerciseName = ExerciseSearch.canonicalName(for: secondName, in: exerciseDefinitions)
        let groupId = UUID()
        let groupName = "\(firstExerciseName) + \(secondExerciseName)"
        let nextOrder = (session.exercises.map(\.order).max() ?? -1) + 1

        session.exercises.append(
            makeExercise(
                name: firstExerciseName,
                order: nextOrder,
                groupId: groupId,
                groupName: groupName
            )
        )
        session.exercises.append(
            makeExercise(
                name: secondExerciseName,
                order: nextOrder + 1,
                groupId: groupId,
                groupName: groupName
            )
        )

        dismiss()
    }

    private func makeExercise(name: String, order: Int, groupId: UUID, groupName: String) -> LoggedExercise {
        let sets = (1...setCount).map { order in
            LoggedSet.blank(order: order, unit: unit)
        }

        return LoggedExercise(
            name: name,
            order: order,
            targetSetsText: "\(setCount) sets",
            targetRepsText: targetReps.trimmed,
            supersetGroupId: groupId,
            supersetName: groupName,
            notes: "",
            sets: sets
        )
    }
}
