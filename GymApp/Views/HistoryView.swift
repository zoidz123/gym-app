import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: WorkoutStore
    @State private var isLoggingPreviousWorkout = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppScreenHeader("History") {
                    Button {
                        isLoggingPreviousWorkout = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline.weight(.semibold))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Log previous workout")
                }

                if store.data.history.isEmpty {
                    EmptyStateView(
                        title: "No History Yet",
                        message: "Imported workouts and completed app sessions will show here.",
                        systemImage: "clock"
                    )
                    .padding()
                    .frame(maxHeight: .infinity, alignment: .top)
                } else {
                    List {
                        ForEach(store.data.history.sorted(by: { $0.date > $1.date })) { session in
                            NavigationLink {
                                if let binding = binding(for: session.id) {
                                    HistoryDetailView(session: binding)
                                } else {
                                    EmptyStateView(
                                        title: "Workout Missing",
                                        message: "This workout could not be loaded.",
                                        systemImage: "exclamationmark.triangle"
                                    )
                                }
                            } label: {
                                HistorySessionRow(session: session)
                            }
                            .listRowSeparatorTint(AppTheme.divider)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .background(AppTheme.screenBackground)
            .sheet(isPresented: $isLoggingPreviousWorkout) {
                LogPreviousWorkoutSheet()
            }
        }
    }

    private func binding(for sessionId: UUID) -> Binding<WorkoutSession>? {
        guard let index = store.data.history.firstIndex(where: { $0.id == sessionId }) else {
            return nil
        }

        return $store.data.history[index]
    }
}

struct HistoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: WorkoutStore
    @Binding var session: WorkoutSession
    @State private var isConfirmingDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AppCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.date.workoutWeekdayDate)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)

                        HStack(spacing: 8) {
                            Pill("\(session.exercises.count) exercises", systemImage: "dumbbell")
                            Pill("\(session.totalSetCount) sets", systemImage: "checkmark.circle")
                        }

                        if !session.bodyweight.isEmpty {
                            Divider()
                            LabeledContent("Bodyweight", value: session.bodyweight)
                                .font(.subheadline)
                        }

                        if !session.notes.isEmpty {
                            Divider()
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Notes")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text(session.notes)
                                    .font(.subheadline)
                            }
                        }
                    }
                }

                ForEach(Array(historyBlocks.enumerated()), id: \.element.id) { index, block in
                    switch block.kind {
                    case .single(let exercise):
                        HistoryExerciseRow(exercise: binding(for: exercise.id))
                    case .superset(_, let exercises):
                        AppCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Pill("Superset")
                                    Spacer()
                                }

                                ForEach(exercises) { exercise in
                                    HistoryExerciseTable(exercise: binding(for: exercise.id))
                                }
                            }
                        }
                    }

                    if index < historyBlocks.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.horizontal)
        }
        .background(AppTheme.screenBackground)
        .navigationTitle(session.workoutName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete workout")
            }
        }
        .confirmationDialog("Delete this workout?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Workout", role: .destructive) {
                deleteWorkout()
            }

            Button("Cancel", role: .cancel) {}
        }
    }

    private var historyBlocks: [HistoryBlock] {
        var blocks: [HistoryBlock] = []
        var emittedGroups = Set<UUID>()

        for exercise in session.exercises.sorted(by: { $0.order < $1.order }) {
            if let groupId = exercise.supersetGroupId {
                guard !emittedGroups.contains(groupId) else { continue }
                emittedGroups.insert(groupId)
                let groupExercises = session.exercises
                    .filter { $0.supersetGroupId == groupId }
                    .sorted { $0.order < $1.order }
                blocks.append(
                    HistoryBlock(
                        id: "superset-\(groupId.uuidString)",
                        kind: .superset(name: exercise.supersetName ?? groupExercises.map(\.name).joined(separator: " + "), exercises: groupExercises)
                    )
                )
            } else {
                blocks.append(
                    HistoryBlock(
                        id: "single-\(exercise.id.uuidString)",
                        kind: .single(exercise)
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

    private func deleteWorkout() {
        let sessionId = session.id
        dismiss()

        DispatchQueue.main.async {
            store.data.history.removeAll { $0.id == sessionId }
        }
    }
}

private struct HistoryExerciseRow: View {
    @Binding var exercise: LoggedExercise

    var body: some View {
        AppCard {
            HistoryExerciseTable(exercise: $exercise)
        }
    }
}

private struct HistoryExerciseTable: View {
    @Binding var exercise: LoggedExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(exercise.name)
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            VStack(spacing: 0) {
                HStack {
                    Text("SET")
                        .frame(width: 42, alignment: .leading)
                    Text("LOAD")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("REPS")
                        .frame(width: 64, alignment: .trailing)
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

                ForEach(Array($exercise.sets.enumerated()), id: \.element.id) { index, $set in
                    HistorySetRow(
                        set: $set,
                        index: index,
                        metric: .from(targetRepsText: exercise.targetRepsText)
                    )

                    if index < exercise.sets.count - 1 {
                        Divider()
                            .padding(.leading, 54)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}

private struct HistorySetRow: View {
    @Binding var set: LoggedSet
    let index: Int
    let metric: SetMetricDescriptor
    @State private var isEditingWeight = false
    @State private var isEditingReps = false

    var body: some View {
        HStack {
            Text("\(index + 1)")
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 42, alignment: .leading)

            Button {
                isEditingWeight = true
            } label: {
                Text(historyLoadLabel(for: set))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.ink)

            Button {
                isEditingReps = true
            } label: {
                Text(set.repsLabel)
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .frame(width: 64, alignment: .trailing)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
        .sheet(isPresented: $isEditingWeight) {
            SetWeightSheet(set: $set)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $isEditingReps) {
            SetRepsSheet(set: $set, metric: metric)
                .presentationDetents([.height(320), .medium])
                .presentationDragIndicator(.visible)
        }
    }

    private func historyLoadLabel(for set: LoggedSet) -> String {
        if set.loadUnit == .custom && set.loadValue == nil {
            return "-"
        }

        if set.loadUnit.usesLoadValue || set.loadUnit == .bodyweight {
            return set.loadLabel
        }

        return "-"
    }
}

private struct HistorySessionRow: View {
    let session: WorkoutSession

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                titleAndDate
                Spacer(minLength: 8)
                totals
            }

            VStack(alignment: .leading, spacing: 8) {
                titleAndDate
                totals
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var titleAndDate: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(session.workoutName)
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
                .lineLimit(2)

            Text(session.date.workoutWeekdayDate)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var totals: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text("\(session.exercises.count) EXERCISES")
            Text("\(session.totalSetCount) SETS")
        }
        .font(.caption.weight(.semibold))
        .monospacedDigit()
        .foregroundStyle(AppTheme.textSecondary)
        .frame(minWidth: 88, alignment: .trailing)
    }
}

private struct HistoryBlock: Identifiable {
    enum Kind {
        case single(LoggedExercise)
        case superset(name: String, exercises: [LoggedExercise])
    }

    let id: String
    let kind: Kind
}
