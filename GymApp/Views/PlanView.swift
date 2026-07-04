import SwiftUI

struct PlanView: View {
    @EnvironmentObject private var store: WorkoutStore
    @State private var expandedTemplateIds = Set<UUID>()
    @State private var editingTemplateId: UUID?

    var body: some View {
        ScrollView {
            AppScreenHeader("Plan")

            VStack(alignment: .leading, spacing: 14) {
                ForEach(store.data.templates) { template in
                    PlanTemplateCard(
                        template: template,
                        blocks: planBlocks(for: template),
                        isExpanded: expandedTemplateIds.contains(template.id),
                        toggle: { toggle(template.id) },
                        edit: { editingTemplateId = template.id }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(AppTheme.screenBackground)
        .sheet(isPresented: isEditingTemplate) {
            if let templateBinding = bindingForEditingTemplate {
                PlanTemplateEditorSheet(
                    template: templateBinding,
                    exerciseDefinitions: store.data.exerciseDefinitions
                )
            }
        }
    }

    private var isEditingTemplate: Binding<Bool> {
        Binding(
            get: { editingTemplateId != nil },
            set: { isPresented in
                if !isPresented {
                    editingTemplateId = nil
                }
            }
        )
    }

    private var bindingForEditingTemplate: Binding<WorkoutTemplate>? {
        guard let editingTemplateId,
              let index = store.data.templates.firstIndex(where: { $0.id == editingTemplateId }) else {
            return nil
        }

        return $store.data.templates[index]
    }

    private func toggle(_ id: UUID) {
        if expandedTemplateIds.contains(id) {
            expandedTemplateIds.remove(id)
        } else {
            expandedTemplateIds.insert(id)
        }
    }

    private func planBlocks(for template: WorkoutTemplate) -> [PlanBlock] {
        var blocks: [PlanBlock] = []
        var emittedGroups = Set<UUID>()

        for exercise in template.exercises.sorted(by: { $0.order < $1.order }) {
            if let groupId = exercise.supersetGroupId {
                guard !emittedGroups.contains(groupId) else { continue }
                emittedGroups.insert(groupId)
                let groupExercises = template.exercises
                    .filter { $0.supersetGroupId == groupId }
                    .sorted { $0.order < $1.order }
                blocks.append(
                    PlanBlock(
                        id: "superset-\(groupId.uuidString)",
                        kind: .superset(exercises: groupExercises)
                    )
                )
            } else {
                blocks.append(
                    PlanBlock(
                        id: "single-\(exercise.id.uuidString)",
                        kind: .single(exercise)
                    )
                )
            }
        }

        return blocks
    }
}

private struct PlanTemplateCard: View {
    let template: WorkoutTemplate
    let blocks: [PlanBlock]
    let isExpanded: Bool
    let toggle: () -> Void
    let edit: () -> Void

    var body: some View {
        AppCard {
            Button(action: toggle) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(template.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.ink)

                        Text("\(template.exercises.count) exercises")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer()

                    Button(action: edit) {
                        Image(systemName: "pencil")
                            .font(.headline.weight(.bold))
                            .frame(width: 38, height: 38)
                            .background(AppTheme.surface)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.accent)
                    .accessibilityLabel("Edit \(template.name) plan")

                    Image(systemName: "chevron.down")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .padding(.vertical, 2)

                VStack(spacing: 10) {
                    ForEach(blocks) { block in
                        switch block.kind {
                        case .single(let exercise):
                            PlanExerciseRow(exercise: exercise)
                        case .superset(let exercises):
                            VStack(alignment: .leading, spacing: 10) {
                                Pill("Superset")

                                VStack(spacing: 8) {
                                    ForEach(exercises) { exercise in
                                        PlanExerciseRow(exercise: exercise)
                                    }
                                }
                            }
                            .padding(12)
                            .background(AppTheme.accentSoft.opacity(0.65))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.snappy, value: isExpanded)
    }
}

private struct PlanExerciseRow: View {
    let exercise: TemplateExercise

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(exercise.order)")
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 24, height: 24)
                .background(AppTheme.surface)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)

                Text([exercise.targetSetsText, exercise.targetRepsText].filter { !$0.isEmpty }.joined(separator: " - "))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding(12)
        .background(AppTheme.rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct PlanTemplateEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var template: WorkoutTemplate
    let exerciseDefinitions: [ExerciseDefinition]

    @State private var newExerciseName = ""
    @State private var newExerciseSetCount = 3
    @State private var newExerciseReps = "8-12 reps"

    var body: some View {
        NavigationStack {
            List {
                Section("Workout") {
                    TextField("Workout name", text: $template.name)
                }

                Section("Exercises") {
                    ForEach($template.exercises) { $exercise in
                        PlanTemplateExerciseEditorRow(
                            exercise: $exercise,
                            setCount: setCountBinding(for: $exercise)
                        )
                    }
                    .onMove(perform: moveExercises)
                    .onDelete(perform: deleteExercises)
                }

                Section("Add Exercise") {
                    ExerciseSearchField(
                        title: "Exercise",
                        placeholder: "Exercise name",
                        text: $newExerciseName,
                        exerciseDefinitions: exerciseDefinitions
                    )

                    Stepper("\(newExerciseSetCount) sets", value: $newExerciseSetCount, in: 1...10)
                    TextField("Target reps", text: $newExerciseReps)

                    Button {
                        addExercise()
                    } label: {
                        Label("Add to Plan", systemImage: "plus")
                    }
                    .disabled(newExerciseName.trimmed.isEmpty)
                }
            }
            .navigationTitle("Edit \(template.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        normalizeExerciseOrders()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
            }
            .onAppear {
                sortExercises()
            }
        }
    }

    private func setCountBinding(for exercise: Binding<TemplateExercise>) -> Binding<Int> {
        Binding(
            get: { exercise.wrappedValue.targetSetCount },
            set: { newValue in
                exercise.wrappedValue.targetSetCount = newValue
                exercise.wrappedValue.targetSetsText = "\(newValue) sets"
            }
        )
    }

    private func addExercise() {
        template.exercises.append(
            TemplateExercise(
                name: ExerciseSearch.canonicalName(for: newExerciseName, in: exerciseDefinitions),
                order: template.exercises.count,
                targetSetsText: "\(newExerciseSetCount) sets",
                targetRepsText: newExerciseReps.trimmed,
                targetSetCount: newExerciseSetCount,
                supersetGroupId: nil,
                supersetName: nil
            )
        )

        newExerciseName = ""
        newExerciseSetCount = 3
        newExerciseReps = "8-12 reps"
        normalizeExerciseOrders()
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        template.exercises.move(fromOffsets: source, toOffset: destination)
        normalizeExerciseOrders()
    }

    private func deleteExercises(at offsets: IndexSet) {
        template.exercises.remove(atOffsets: offsets)
        normalizeExerciseOrders()
    }

    private func sortExercises() {
        template.exercises.sort { $0.order < $1.order }
        normalizeExerciseOrders()
    }

    private func normalizeExerciseOrders() {
        for index in template.exercises.indices {
            template.exercises[index].order = index
        }
    }
}

private struct PlanTemplateExerciseEditorRow: View {
    @Binding var exercise: TemplateExercise
    let setCount: Binding<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Exercise", text: $exercise.name)
                .font(.body.weight(.semibold))

            HStack {
                Stepper("\(setCount.wrappedValue) sets", value: setCount, in: 1...10)

                TextField("Reps", text: $exercise.targetRepsText)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
            }
            .font(.subheadline)
            .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.vertical, 4)
    }
}

private struct PlanBlock: Identifiable {
    enum Kind {
        case single(TemplateExercise)
        case superset(exercises: [TemplateExercise])
    }

    let id: String
    let kind: Kind
}
