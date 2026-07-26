import SwiftUI

struct AddExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var session: WorkoutSession
    let exerciseDefinitions: [ExerciseDefinition]

    @State private var name = ""
    @State private var setCount = 3
    @State private var targetReps = "8-12 reps"
    @State private var unit: LoadUnit = .lb
    @State private var selectedMuscleGroup: ExerciseMuscleGroup = .all

    var body: some View {
        NavigationStack {
            Form {
                ExerciseSearchField(
                    title: "Exercise",
                    placeholder: "Exercise name",
                    text: $name,
                    exerciseDefinitions: exerciseDefinitions,
                    selectedMuscleGroup: $selectedMuscleGroup
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
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addExercise()
                    }
                    .disabled(name.trimmed.isEmpty)
                }
            }
        }
    }

    private func addExercise() {
        let sets = (1...setCount).map { order in
            LoggedSet.blank(order: order, unit: unit)
        }

        session.exercises.append(
            LoggedExercise(
                name: ExerciseSearch.canonicalName(for: name, in: exerciseDefinitions),
                order: (session.exercises.map(\.order).max() ?? -1) + 1,
                targetSetsText: "\(setCount) sets",
                targetRepsText: targetReps.trimmed,
                supersetGroupId: nil,
                supersetName: nil,
                notes: "",
                sets: sets
            )
        )

        dismiss()
    }
}

struct ExerciseSearchField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let exerciseDefinitions: [ExerciseDefinition]
    private let selectedMuscleGroup: Binding<ExerciseMuscleGroup>?

    init(
        title: String,
        placeholder: String,
        text: Binding<String>,
        exerciseDefinitions: [ExerciseDefinition],
        selectedMuscleGroup: Binding<ExerciseMuscleGroup>? = nil
    ) {
        self.title = title
        self.placeholder = placeholder
        _text = text
        self.exerciseDefinitions = exerciseDefinitions
        self.selectedMuscleGroup = selectedMuscleGroup
    }

    var body: some View {
        Section(title) {
            TextField(placeholder, text: $text)

            if let selectedMuscleGroup {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ExerciseMuscleGroup.allCases) { muscleGroup in
                            Button(muscleGroup.title) {
                                selectedMuscleGroup.wrappedValue = muscleGroup
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(
                                selectedMuscleGroup.wrappedValue == muscleGroup
                                    ? AppTheme.accent
                                    : AppTheme.textSecondary
                            )
                            .accessibilityValue(
                                selectedMuscleGroup.wrappedValue == muscleGroup
                                    ? "Selected"
                                    : "Not selected"
                            )
                            .accessibilityAddTraits(
                                selectedMuscleGroup.wrappedValue == muscleGroup ? .isSelected : []
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
                .accessibilityLabel("Filter exercises by muscle group")
            }

            if !suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(suggestions.prefix(6)) { suggestion in
                        Button {
                            text = suggestion.name
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(suggestion.name)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(AppTheme.ink)

                                    if !suggestion.metadataText.isEmpty {
                                        Text(suggestion.metadataText)
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.textSecondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                Image(systemName: "plus.circle")
                                    .foregroundStyle(AppTheme.accent)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)

                        if suggestion.id != suggestions.prefix(6).last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var suggestions: [ExerciseDefinition] {
        ExerciseSearch.rankedDefinitions(
            exerciseDefinitions,
            matching: text,
            muscleGroup: selectedMuscleGroup?.wrappedValue ?? .all
        )
    }
}
