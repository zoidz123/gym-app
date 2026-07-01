import SwiftUI

struct ActiveWorkoutView: View {
    @EnvironmentObject private var store: WorkoutStore
    @Binding var session: WorkoutSession
    var finishAccessibilityLabel = "Finish workout"
    var discardConfirmationTitle = "Discard this workout?"
    var discardButtonTitle = "Discard Workout"
    var onFinish: (() -> Void)?
    var onDiscard: (() -> Void)?

    @State private var isAddingExercise = false
    @State private var isAddingSuperset = false
    @State private var isConfirmingDiscard = false
    @State private var scrollPosition: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                headerCard
                    .id("header")

                ForEach(workoutBlocks) { block in
                    switch block.kind {
                    case .single(let exerciseId):
                        ExerciseCard(
                            exercise: binding(for: exerciseId),
                            onRemove: { removeExercise(id: exerciseId) }
                        )
                        .id(block.id)
                    case .superset(let exerciseIds):
                        supersetBlock(exerciseIds: exerciseIds)
                            .id(block.id)
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        isAddingExercise = true
                    } label: {
                        Text("Add Exercise")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(AppTheme.ink)

                    Button {
                        isAddingSuperset = true
                    } label: {
                        Text("Add Superset")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(AppTheme.accent)
                }
                .id("actions")
            }
            .padding()
            .scrollTargetLayout()
        }
        .scrollPosition(id: $scrollPosition, anchor: .top)
        .background(AppTheme.screenBackground)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .destructive) {
                    isConfirmingDiscard = true
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Discard workout")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    finishWorkout()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppTheme.success)
                }
                .disabled(session.exercises.isEmpty)
                .accessibilityLabel(finishAccessibilityLabel)
            }
        }
        .sheet(isPresented: $isAddingExercise) {
            AddExerciseSheet(
                session: $session,
                exerciseDefinitions: store.data.exerciseDefinitions
            )
        }
        .sheet(isPresented: $isAddingSuperset) {
            SupersetSheet(
                session: $session,
                exerciseDefinitions: store.data.exerciseDefinitions
            )
        }
        .confirmationDialog(discardConfirmationTitle, isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
            Button(discardButtonTitle, role: .destructive) {
                isConfirmingDiscard = false
                DispatchQueue.main.async {
                    discardWorkout()
                }
            }

            Button("Cancel", role: .cancel) {}
        }
    }

    private var headerCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.workoutName)
                            .font(.system(.title, design: .rounded).weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        Text(session.date.workoutLongDate)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer()

                    Pill("\(session.completedSetCount)/\(session.totalSetCount)", systemImage: "checkmark.circle")
                }

                TextField("Optional bodyweight", text: $session.bodyweight)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private func supersetBlock(exerciseIds: [UUID]) -> some View {
        AppCard {
            HStack {
                Pill("Superset")
                Spacer()
            }

            VStack(spacing: 14) {
                ForEach(exerciseIds, id: \.self) { exerciseId in
                    ExerciseLoggingContent(
                        exercise: binding(for: exerciseId),
                        isInsideSuperset: true,
                        onRemove: { removeExercise(id: exerciseId) }
                    )

                    if exerciseId != exerciseIds.last {
                        Divider()
                    }
                }
            }
        }
    }

    private var workoutBlocks: [WorkoutBlock] {
        var blocks: [WorkoutBlock] = []
        var emittedGroups = Set<UUID>()

        for exercise in session.exercises.sorted(by: { $0.order < $1.order }) {
            if let groupId = exercise.supersetGroupId {
                guard !emittedGroups.contains(groupId) else { continue }
                emittedGroups.insert(groupId)
                let groupExercises = session.exercises
                    .filter { $0.supersetGroupId == groupId }
                    .sorted { $0.order < $1.order }
                blocks.append(
                    WorkoutBlock(
                        id: "superset-\(groupId.uuidString)",
                        kind: .superset(exerciseIds: groupExercises.map(\.id))
                    )
                )
            } else {
                blocks.append(
                    WorkoutBlock(
                        id: "single-\(exercise.id.uuidString)",
                        kind: .single(exerciseId: exercise.id)
                    )
                )
            }
        }

        return blocks
    }

    private func binding(for exerciseId: UUID) -> Binding<LoggedExercise> {
        Binding(
            get: {
                session.exercises.first { $0.id == exerciseId } ?? LoggedExercise(
                    name: "Missing Exercise",
                    order: 0,
                    targetSetsText: "",
                    targetRepsText: "",
                    supersetGroupId: nil,
                    supersetName: nil,
                    notes: "",
                    sets: []
                )
            },
            set: { updatedExercise in
                guard let index = session.exercises.firstIndex(where: { $0.id == exerciseId }) else {
                    return
                }

                session.exercises[index] = updatedExercise
            }
        )
    }

    private func removeExercise(id exerciseId: UUID) {
        session.exercises.removeAll { $0.id == exerciseId }

        for index in session.exercises.indices {
            session.exercises[index].order = index
        }
    }

    private func finishWorkout() {
        if let onFinish {
            onFinish()
        } else {
            store.completeActiveWorkout()
        }
    }

    private func discardWorkout() {
        if let onDiscard {
            onDiscard()
        } else {
            store.discardActiveWorkout()
        }
    }
}

private struct WorkoutBlock: Identifiable {
    enum Kind {
        case single(exerciseId: UUID)
        case superset(exerciseIds: [UUID])
    }

    let id: String
    let kind: Kind
}
