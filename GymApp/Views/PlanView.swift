import SwiftUI

struct PlanView: View {
    @EnvironmentObject private var store: WorkoutStore
    @State private var expandedOccurrenceIDs = Set<UUID>()
    @State private var editingTemplate: WorkoutTemplate?
    @State private var deletingOccurrence: PlannedWorkoutOccurrence?
    @State private var isAddingWorkout = false

    var body: some View {
        NavigationStack {
            List {
                AppScreenHeader("Plan") {
                    HStack(spacing: 10) {
                        EditButton()

                        Button {
                            isAddingWorkout = true
                        } label: {
                            Label("Add Workout", systemImage: "plus")
                                .font(.subheadline.weight(.bold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                        .accessibilityIdentifier("plan-add-workout")
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(AppTheme.screenBackground)
                .listRowSeparator(.hidden)

                Section {
                    if store.currentWeekOccurrences.isEmpty {
                        PlanEmptyState {
                            isAddingWorkout = true
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(store.currentWeekOccurrences) { occurrence in
                            if let template = store.template(for: occurrence) {
                                PlanOccurrenceCard(
                                    occurrence: occurrence,
                                    template: template,
                                    blocks: planBlocks(for: template),
                                    isExpanded: expandedOccurrenceIDs.contains(occurrence.id),
                                    toggle: { toggle(occurrence.id) },
                                    edit: { editingTemplate = template },
                                    addAnother: { store.addOccurrence(templateID: template.id) },
                                    delete: { deletingOccurrence = occurrence }
                                )
                                .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
                                .listRowBackground(AppTheme.screenBackground)
                                .listRowSeparator(.hidden)
                            }
                        }
                        .onMove(perform: store.moveOccurrences)
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("This Week")
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)

                        Text("Repeats every Monday with fresh checkmarks")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .textCase(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isAddingWorkout) {
                AddWorkoutSheet(
                    templates: store.data.templates,
                    exerciseDefinitions: store.data.exerciseDefinitions,
                    onAddExisting: store.addOccurrence,
                    onCreate: store.createWorkout
                )
            }
            .sheet(item: $editingTemplate) { template in
                WorkoutTemplateEditorSheet(
                    initialTemplate: template,
                    title: "Edit Workout",
                    exerciseDefinitions: store.data.exerciseDefinitions,
                    onSave: store.updateWorkout
                )
            }
            .confirmationDialog(
                "Remove this workout from the week?",
                isPresented: deleteConfirmationIsPresented,
                titleVisibility: .visible
            ) {
                Button("Remove Workout", role: .destructive) {
                    guard let deletingOccurrence else { return }
                    expandedOccurrenceIDs.remove(deletingOccurrence.id)
                    store.deleteOccurrence(id: deletingOccurrence.id)
                    self.deletingOccurrence = nil
                }

                Button("Cancel", role: .cancel) {
                    deletingOccurrence = nil
                }
            } message: {
                Text("The reusable workout and workout history will be kept.")
            }
        }
    }

    private var deleteConfirmationIsPresented: Binding<Bool> {
        Binding(
            get: { deletingOccurrence != nil },
            set: { isPresented in
                if !isPresented {
                    deletingOccurrence = nil
                }
            }
        )
    }

    private func toggle(_ id: UUID) {
        if expandedOccurrenceIDs.contains(id) {
            expandedOccurrenceIDs.remove(id)
        } else {
            expandedOccurrenceIDs.insert(id)
        }
    }

    private func planBlocks(for template: WorkoutTemplate) -> [PlanBlock] {
        var blocks: [PlanBlock] = []
        var emittedGroups = Set<UUID>()

        for exercise in template.exercises.sorted(by: { $0.order < $1.order }) {
            if let groupID = exercise.supersetGroupId {
                guard !emittedGroups.contains(groupID) else { continue }
                emittedGroups.insert(groupID)
                let groupExercises = template.exercises
                    .filter { $0.supersetGroupId == groupID }
                    .sorted { $0.order < $1.order }
                blocks.append(PlanBlock(id: groupID, kind: .superset(groupExercises)))
            } else {
                blocks.append(PlanBlock(id: exercise.id, kind: .single(exercise)))
            }
        }

        return blocks
    }
}

private struct PlanEmptyState: View {
    let addWorkout: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            EmptyStateView(
                title: "Plan Your Week",
                message: "Add a workout day to choose your exercises and track it on Home.",
                systemImage: "calendar.badge.plus"
            )

            Button(action: addWorkout) {
                Label("Add Your First Workout", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(AppTheme.accent)
            .padding(.horizontal)
        }
        .padding(.bottom, 24)
    }
}

private struct PlanOccurrenceCard: View {
    let occurrence: PlannedWorkoutOccurrence
    let template: WorkoutTemplate
    let blocks: [PlanBlock]
    let isExpanded: Bool
    let toggle: () -> Void
    let edit: () -> Void
    let addAnother: () -> Void
    let delete: () -> Void

    var body: some View {
        AppCard {
            HStack(spacing: 12) {
                Button(action: toggle) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(template.name)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.ink)
                                .lineLimit(2)

                            Text("Workout \(occurrence.order + 1) · \(template.exercises.count) exercises")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 6)

                        Image(systemName: "chevron.down")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Menu {
                    Button(action: edit) {
                        Label("Edit Workout", systemImage: "pencil")
                    }

                    Button(action: addAnother) {
                        Label("Add Another This Week", systemImage: "plus.square.on.square")
                    }

                    Divider()

                    Button(role: .destructive, action: delete) {
                        Label("Remove from This Week", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .foregroundStyle(AppTheme.accent)
                .accessibilityLabel("Actions for \(template.name), workout \(occurrence.order + 1)")
            }

            if isExpanded {
                Divider()

                if blocks.isEmpty {
                    Text("No exercises yet")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    VStack(spacing: 10) {
                        ForEach(blocks) { block in
                            switch block.kind {
                            case .single(let exercise):
                                PlanExerciseRow(exercise: exercise)
                            case .superset(let exercises):
                                VStack(alignment: .leading, spacing: 8) {
                                    Pill("Superset", systemImage: "link")

                                    ForEach(exercises) { exercise in
                                        PlanExerciseRow(exercise: exercise)
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
        }
        .animation(.snappy, value: isExpanded)
        .accessibilityIdentifier("plan-occurrence-\(occurrence.id.uuidString)")
    }
}

private struct PlanExerciseRow: View {
    let exercise: TemplateExercise

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(exercise.order + 1)")
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
                    .lineLimit(2)

                Text([exercise.targetSetsText, exercise.targetRepsText].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(AppTheme.rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct AddWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    let templates: [WorkoutTemplate]
    let exerciseDefinitions: [ExerciseDefinition]
    let onAddExisting: (UUID) -> Void
    let onCreate: (WorkoutTemplate) -> Void

    @State private var isCreatingWorkout = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        isCreatingWorkout = true
                    } label: {
                        Label("Create New Workout", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                    .accessibilityIdentifier("create-new-workout")
                }

                if !templates.isEmpty {
                    Section("Add a Saved Workout") {
                        ForEach(templates.sorted(by: { $0.order < $1.order })) { template in
                            Button {
                                onAddExisting(template.id)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(template.name)
                                            .font(.headline)
                                            .foregroundStyle(AppTheme.ink)
                                            .lineLimit(2)

                                        Text("\(template.exercises.count) exercises")
                                            .font(.subheadline)
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }

                                    Spacer()

                                    Image(systemName: "plus.circle")
                                        .foregroundStyle(AppTheme.accent)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Add Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isCreatingWorkout) {
                WorkoutTemplateEditorSheet(
                    initialTemplate: WorkoutTemplate(name: "", order: templates.count, exercises: []),
                    title: "New Workout",
                    exerciseDefinitions: exerciseDefinitions
                ) { template in
                    onCreate(template)
                    dismiss()
                }
            }
        }
    }
}

private struct WorkoutTemplateEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let exerciseDefinitions: [ExerciseDefinition]
    let onSave: (WorkoutTemplate) -> Void

    @State private var template: WorkoutTemplate
    @State private var isAddingExercise = false
    @State private var isAddingSuperset = false

    init(
        initialTemplate: WorkoutTemplate,
        title: String,
        exerciseDefinitions: [ExerciseDefinition],
        onSave: @escaping (WorkoutTemplate) -> Void
    ) {
        self.title = title
        self.exerciseDefinitions = exerciseDefinitions
        self.onSave = onSave
        _template = State(initialValue: initialTemplate)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Workout") {
                    TextField("Workout name", text: $template.name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .accessibilityIdentifier("workout-name")
                }

                Section("Exercises") {
                    if template.exercises.isEmpty {
                        Text("Add an exercise or superset to build this workout.")
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        ForEach($template.exercises) { $exercise in
                            PlanTemplateExerciseEditorRow(
                                exercise: $exercise,
                                setCount: setCountBinding(for: $exercise)
                            )
                        }
                        .onMove(perform: moveExercises)
                        .onDelete(perform: deleteExercises)
                    }
                }

                Section {
                    Button {
                        isAddingExercise = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                    }

                    Button {
                        isAddingSuperset = true
                    } label: {
                        Label("Add Superset", systemImage: "link.badge.plus")
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(template.name.trimmed.isEmpty == false || template.exercises.isEmpty == false)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .confirmationAction) {
                    EditButton()

                    Button("Save") {
                        normalizeExerciseOrders()
                        template.name = template.name.trimmed
                        onSave(template)
                        dismiss()
                    }
                    .disabled(template.name.trimmed.isEmpty || template.exercises.isEmpty)
                    .accessibilityIdentifier("save-workout")
                }
            }
            .sheet(isPresented: $isAddingExercise) {
                TemplateExerciseSheet(
                    exerciseDefinitions: exerciseDefinitions,
                    onAdd: addExercise
                )
            }
            .sheet(isPresented: $isAddingSuperset) {
                TemplateSupersetSheet(
                    exerciseDefinitions: exerciseDefinitions,
                    onAdd: addSuperset
                )
            }
            .onAppear {
                template.exercises.sort { $0.order < $1.order }
                normalizeExerciseOrders()
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

    private func addExercise(_ exercise: TemplateExercise) {
        var exercise = exercise
        exercise.order = template.exercises.count
        template.exercises.append(exercise)
        normalizeExerciseOrders()
    }

    private func addSuperset(_ exercises: [TemplateExercise]) {
        template.exercises.append(contentsOf: exercises)
        normalizeExerciseOrders()
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        template.exercises.move(fromOffsets: source, toOffset: destination)
        normalizeExerciseOrders()
    }

    private func deleteExercises(at offsets: IndexSet) {
        let deletedGroupIDs = Set(offsets.compactMap { template.exercises[$0].supersetGroupId })
        template.exercises.remove(atOffsets: offsets)

        for groupID in deletedGroupIDs {
            let remainingIndices = template.exercises.indices.filter {
                template.exercises[$0].supersetGroupId == groupID
            }
            if remainingIndices.count == 1, let remainingIndex = remainingIndices.first {
                template.exercises[remainingIndex].supersetGroupId = nil
                template.exercises[remainingIndex].supersetName = nil
            }
        }

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
            HStack {
                TextField("Exercise", text: $exercise.name)
                    .font(.body.weight(.semibold))

                if exercise.supersetGroupId != nil {
                    Pill("Superset", systemImage: "link")
                }
            }

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

private struct TemplateExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exerciseDefinitions: [ExerciseDefinition]
    let onAdd: (TemplateExercise) -> Void

    @State private var name = ""
    @State private var setCount = 3
    @State private var targetReps = "8-12 reps"

    var body: some View {
        NavigationStack {
            Form {
                ExerciseSearchField(
                    title: "Exercise",
                    placeholder: "Exercise name",
                    text: $name,
                    exerciseDefinitions: exerciseDefinitions
                )

                Section("Planned Sets") {
                    Stepper("\(setCount) sets", value: $setCount, in: 1...10)
                    TextField("Target reps", text: $targetReps)
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(
                            TemplateExercise(
                                name: ExerciseSearch.canonicalName(for: name, in: exerciseDefinitions),
                                order: 0,
                                targetSetsText: "\(setCount) sets",
                                targetRepsText: targetReps.trimmed,
                                targetSetCount: setCount,
                                supersetGroupId: nil,
                                supersetName: nil
                            )
                        )
                        dismiss()
                    }
                    .disabled(name.trimmed.isEmpty)
                }
            }
        }
    }
}

private struct TemplateSupersetSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exerciseDefinitions: [ExerciseDefinition]
    let onAdd: ([TemplateExercise]) -> Void

    @State private var firstName = ""
    @State private var secondName = ""
    @State private var setCount = 3
    @State private var targetReps = "8-12 reps"

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
                }
            }
            .navigationTitle("Add Superset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addSuperset()
                    }
                    .disabled(!canAdd)
                }
            }
        }
    }

    private var canAdd: Bool {
        !firstName.trimmed.isEmpty &&
            !secondName.trimmed.isEmpty &&
            firstName.normalizedExerciseName != secondName.normalizedExerciseName
    }

    private func addSuperset() {
        let first = ExerciseSearch.canonicalName(for: firstName, in: exerciseDefinitions)
        let second = ExerciseSearch.canonicalName(for: secondName, in: exerciseDefinitions)
        let groupID = UUID()
        let groupName = "\(first) + \(second)"
        let names = [first, second]

        onAdd(
            names.enumerated().map { index, name in
                TemplateExercise(
                    name: name,
                    order: index,
                    targetSetsText: "\(setCount) sets",
                    targetRepsText: targetReps.trimmed,
                    targetSetCount: setCount,
                    supersetGroupId: groupID,
                    supersetName: groupName
                )
            }
        )
        dismiss()
    }
}

private struct PlanBlock: Identifiable {
    enum Kind {
        case single(TemplateExercise)
        case superset([TemplateExercise])
    }

    let id: UUID
    let kind: Kind
}
