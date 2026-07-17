import SwiftUI

struct PlanView: View {
    @EnvironmentObject private var store: WorkoutStore
    @State private var selectedTemplate: WorkoutTemplate?
    @State private var editingTemplate: WorkoutTemplate?
    @State private var pendingEditingTemplate: WorkoutTemplate?
    @State private var removingGroup: WeeklyTemplateGroup?
    @State private var pendingRemovingGroup: WeeklyTemplateGroup?
    @State private var confirmingCompletedDecrease: WeeklyTemplateGroup?
    @State private var isAddingWorkout = false

    var body: some View {
        NavigationStack {
            List {
                planHeader
                .listRowInsets(EdgeInsets())
                .listRowBackground(AppTheme.screenBackground)
                .listRowSeparator(.hidden)

                Section {
                    if store.weeklyTemplateGroups.isEmpty {
                        PlanEmptyState(
                            savedTemplates: unscheduledTemplates,
                            addWorkout: { isAddingWorkout = true },
                            addSavedWorkout: store.addOccurrence
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(store.weeklyTemplateGroups) { group in
                            PlanTemplateRow(
                                group: group,
                                showDetails: { selectedTemplate = group.template },
                                edit: { editingTemplate = group.template },
                                increment: { store.addOccurrence(templateID: group.id) },
                                moveUp: { store.moveTemplateGroup(templateID: group.id, by: -1) },
                                moveDown: { store.moveTemplateGroup(templateID: group.id, by: 1) },
                                canMoveUp: group.id != store.weeklyTemplateGroups.first?.id,
                                canMoveDown: group.id != store.weeklyTemplateGroups.last?.id,
                                remove: { removingGroup = group }
                            )
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 12))
                            .listRowBackground(AppTheme.screenBackground)
                            .listRowSeparatorTint(AppTheme.divider)
                        }
                        .onMove(perform: store.moveTemplateGroups)
                    }
                } header: {
                    if !store.weeklyTemplateGroups.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("This Week")
                                .font(.headline)
                                .foregroundStyle(AppTheme.ink)

                            Text("Your weekly workouts repeat every Monday. Each session gets its own checkmark.")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                                .textCase(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if !store.weeklyTemplateGroups.isEmpty {
                    Color.clear
                        .frame(height: 72)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .accessibilityHidden(true)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedTemplate, onDismiss: presentPendingDetailsAction) { template in
                PlanTemplateDetailsSheet(
                    templateID: template.id,
                    blocks: planBlocks(for: template),
                    edit: {
                        pendingEditingTemplate = template
                        selectedTemplate = nil
                    },
                    decrease: decreaseFrequency,
                    remove: {
                        pendingRemovingGroup = store.weeklyTemplateGroups.first { $0.id == template.id }
                        selectedTemplate = nil
                    }
                )
            }
            .sheet(isPresented: $isAddingWorkout) {
                AddWorkoutSheet(
                    exerciseDefinitions: store.data.exerciseDefinitions,
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
                "Remove \(removingGroup?.template.name ?? "workout") from this week?",
                isPresented: removeConfirmationIsPresented,
                titleVisibility: .visible
            ) {
                Button("Remove from This Week", role: .destructive) {
                    guard let removingGroup else { return }
                    store.removeTemplateFromWeek(templateID: removingGroup.id)
                    self.removingGroup = nil
                }

                Button("Cancel", role: .cancel) {
                    removingGroup = nil
                }
            } message: {
                Text("The reusable workout and all workout history will be kept.")
            }
            .confirmationDialog(
                "Decrease \(confirmingCompletedDecrease?.template.name ?? "workout") frequency?",
                isPresented: completedDecreaseConfirmationIsPresented,
                titleVisibility: .visible
            ) {
                Button("Remove One Completed Plan", role: .destructive) {
                    guard let confirmingCompletedDecrease else { return }
                    _ = store.decreaseFrequency(
                        templateID: confirmingCompletedDecrease.id,
                        allowCompletedRemoval: true
                    )
                    self.confirmingCompletedDecrease = nil
                }

                Button("Cancel", role: .cancel) {
                    confirmingCompletedDecrease = nil
                }
            } message: {
                Text("Every planned occurrence is complete. The workout session will stay in History, but one completion marker will be removed from this week.")
            }
        }
    }

    private var planHeader: some View {
        AppScreenHeader("Plan") {
            if !store.weeklyTemplateGroups.isEmpty {
                addWorkoutButton
            }
        }
    }

    private var addWorkoutButton: some View {
        Button {
            isAddingWorkout = true
        } label: {
            Label("Add Workout", systemImage: "plus")
                .font(.headline.weight(.bold))
                .labelStyle(.iconOnly)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .tint(AppTheme.accent)
        .contextMenu {
            savedWorkoutActions
        }
        .accessibilityIdentifier("plan-add-workout")
    }

    private var removeConfirmationIsPresented: Binding<Bool> {
        Binding(
            get: { removingGroup != nil },
            set: { isPresented in
                if !isPresented {
                    removingGroup = nil
                }
            }
        )
    }

    private var completedDecreaseConfirmationIsPresented: Binding<Bool> {
        Binding(
            get: { confirmingCompletedDecrease != nil },
            set: { isPresented in
                if !isPresented {
                    confirmingCompletedDecrease = nil
                }
            }
        )
    }

    private func decreaseFrequency(_ group: WeeklyTemplateGroup) {
        guard group.frequency > 1 else { return }
        if store.decreaseFrequency(templateID: group.id) == .requiresCompletedConfirmation {
            confirmingCompletedDecrease = group
        }
    }

    private func presentPendingDetailsAction() {
        if let pendingEditingTemplate {
            editingTemplate = pendingEditingTemplate
            self.pendingEditingTemplate = nil
        } else if let pendingRemovingGroup {
            removingGroup = pendingRemovingGroup
            self.pendingRemovingGroup = nil
        }
    }

    private var unscheduledTemplates: [WorkoutTemplate] {
        let scheduledIDs = Set(store.weeklyTemplateGroups.map(\.id))
        return store.data.templates
            .filter { !scheduledIDs.contains($0.id) }
            .sorted { $0.order < $1.order }
    }

    @ViewBuilder
    private var savedWorkoutActions: some View {
        if !unscheduledTemplates.isEmpty {
            Section("Saved Workouts") {
                ForEach(unscheduledTemplates) { template in
                    Button {
                        store.addOccurrence(templateID: template.id)
                    } label: {
                        Label("Add \(template.name) This Week", systemImage: "calendar.badge.plus")
                    }
                }
            }
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
    let savedTemplates: [WorkoutTemplate]
    let addWorkout: () -> Void
    let addSavedWorkout: (UUID) -> Void

    var body: some View {
        VStack(spacing: 16) {
            EmptyStateView(
                title: "No workouts yet",
                message: "Add your first workout to plan the week.",
                systemImage: "calendar.badge.plus"
            )

            Button(action: addWorkout) {
                EmptyStateActionLabel(title: "Add Workout", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(AppTheme.accent)
            .padding(.horizontal)
            .contextMenu {
                if !savedTemplates.isEmpty {
                    Section("Saved Workouts") {
                        ForEach(savedTemplates) { template in
                            Button {
                                addSavedWorkout(template.id)
                            } label: {
                                Label("Add \(template.name) This Week", systemImage: "calendar.badge.plus")
                            }
                        }
                    }
                }
            }
        }
        .padding(.bottom, 24)
    }
}

private struct PlanTemplateRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let group: WeeklyTemplateGroup
    let showDetails: () -> Void
    let edit: () -> Void
    let increment: () -> Void
    let moveUp: () -> Void
    let moveDown: () -> Void
    let canMoveUp: Bool
    let canMoveDown: Bool
    let remove: () -> Void

    var body: some View {
        Button(action: showDetails) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.template.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)

                    Text(scheduleSummary)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                }

                Spacer(minLength: 8)

                frequencyMark

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .contextMenu { managementActions }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: remove) {
                Label("Remove", systemImage: "trash")
            }

            Button(action: edit) {
                Label("Edit", systemImage: "pencil")
            }
            .tint(AppTheme.accent)
        }
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint("Opens weekly frequency and exercise details")
        .accessibilityIdentifier("plan-template-\(group.id.uuidString)")
    }

    private var frequencyMark: some View {
        Text("\(group.frequency)×")
            .font(.subheadline.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(AppTheme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppTheme.rowBackground)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(AppTheme.divider, lineWidth: 1)
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var managementActions: some View {
        Button(action: edit) {
            Label("Edit Workout", systemImage: "pencil")
        }

        Button(action: increment) {
            Label("Add Another This Week", systemImage: "plus.square.on.square")
        }

        Divider()

        Button(action: moveUp) {
            Label("Move Up", systemImage: "arrow.up")
        }
        .disabled(!canMoveUp)

        Button(action: moveDown) {
            Label("Move Down", systemImage: "arrow.down")
        }
        .disabled(!canMoveDown)

        Divider()

        Button(role: .destructive, action: remove) {
            Label("Remove from This Week", systemImage: "trash")
        }
    }

    private var scheduleSummary: String {
        let frequency = group.frequency == 1 ? "Once this week" : "\(group.frequency) times this week"
        guard group.completedCount > 0 else { return frequency }
        return "\(frequency) · \(group.completedCount) complete"
    }

    private var accessibilitySummary: String {
        "\(group.template.name), \(group.frequency) \(group.frequency == 1 ? "time" : "times") this week, \(group.completedCount) complete"
    }
}

private struct PlanTemplateDetailsSheet: View {
    @EnvironmentObject private var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let templateID: UUID
    let blocks: [PlanBlock]
    let edit: () -> Void
    let decrease: (WeeklyTemplateGroup) -> Void
    let remove: () -> Void
    @State private var editingExercise: TemplateExercise?

    var body: some View {
        NavigationStack {
            List {
                if let group {
                    Section {
                        Stepper(value: frequency, in: 1...14) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Times per week")
                                    .font(.body.weight(.semibold))
                                Text("\(group.frequency) \(group.frequency == 1 ? "session" : "sessions") every week")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        .accessibilityIdentifier("plan-frequency-stepper")
                    } footer: {
                        Text("Each planned session has its own checkmark. Your plan repeats every Monday.")
                            .textCase(nil)
                    }

                    Section("Exercises") {
                        if blocks.isEmpty {
                            Text("No exercises yet")
                                .foregroundStyle(AppTheme.textSecondary)
                        } else {
                            ForEach(blocks) { block in
                                switch block.kind {
                                case .single(let exercise):
                                    exerciseButton(exercise)
                                case .superset(let exercises):
                                    VStack(alignment: .leading, spacing: 0) {
                                        Label("Superset", systemImage: "link")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(AppTheme.textSecondary)
                                            .padding(.bottom, 4)

                                        ForEach(exercises) { exercise in
                                            exerciseButton(exercise)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Section {
                        Button(action: edit) {
                            Label("Edit Workout", systemImage: "pencil")
                        }

                        Button(role: .destructive, action: remove) {
                            Label("Remove from This Week", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenBackground)
            .navigationTitle(group?.template.name ?? "Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                        .foregroundStyle(AppTheme.contentOnStrongFill)
                }
            }
        }
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .fullScreenCover(item: $editingExercise) { exercise in
            PlanExerciseEditorScreen(
                initialExercise: exercise,
                exerciseDefinitions: store.data.exerciseDefinitions,
                save: saveExercise
            )
        }
    }

    private var group: WeeklyTemplateGroup? {
        store.weeklyTemplateGroups.first { $0.id == templateID }
    }

    private var frequency: Binding<Int> {
        Binding(
            get: { group?.frequency ?? 1 },
            set: { newValue in
                guard let group else { return }
                if newValue > group.frequency {
                    store.addOccurrence(templateID: templateID)
                } else if newValue < group.frequency {
                    decrease(group)
                }
            }
        )
    }

    private func exerciseButton(_ exercise: TemplateExercise) -> some View {
        Button {
            editingExercise = exercise
        } label: {
            HStack(spacing: 8) {
                PlanExerciseRow(exercise: exercise)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit \(exercise.name)")
        .accessibilityHint("Opens full-screen exercise details")
        .accessibilityIdentifier("plan-exercise-\(exercise.id.uuidString)")
    }

    private func saveExercise(_ exercise: TemplateExercise) {
        guard var template = group?.template,
              let exerciseIndex = template.exercises.firstIndex(where: { $0.id == exercise.id }) else {
            return
        }

        template.exercises[exerciseIndex] = exercise
        store.updateWorkout(template)
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
                .frame(width: 24, alignment: .trailing)

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
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

private struct PlanExerciseEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    let initialExercise: TemplateExercise
    let exerciseDefinitions: [ExerciseDefinition]
    let save: (TemplateExercise) -> Void

    @State private var exercise: TemplateExercise
    @State private var isConfirmingDiscard = false

    init(
        initialExercise: TemplateExercise,
        exerciseDefinitions: [ExerciseDefinition],
        save: @escaping (TemplateExercise) -> Void
    ) {
        self.initialExercise = initialExercise
        self.exerciseDefinitions = exerciseDefinitions
        self.save = save
        _exercise = State(initialValue: initialExercise)
    }

    var body: some View {
        NavigationStack {
            Form {
                ExerciseSearchField(
                    title: "Exercise",
                    placeholder: "Exercise name",
                    text: $exercise.name,
                    exerciseDefinitions: exerciseDefinitions
                )

                Section("Planned Sets") {
                    Stepper("\(exercise.targetSetCount) sets", value: setCount, in: 1...10)
                    TextField("Target reps", text: $exercise.targetRepsText)
                        .textInputAutocapitalization(.never)
                }

                if exercise.supersetGroupId != nil {
                    Section {
                        Label("Part of a superset", systemImage: "link")
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenBackground)
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(hasUnsavedChanges)
            .accessibilityIdentifier("plan-exercise-editor")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            isConfirmingDiscard = true
                        } else {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        exercise.name = ExerciseSearch.canonicalName(
                            for: exercise.name,
                            in: exerciseDefinitions
                        )
                        exercise.targetRepsText = exercise.targetRepsText.trimmed
                        save(exercise)
                        dismiss()
                    }
                    .disabled(exercise.name.trimmed.isEmpty)
                    .accessibilityIdentifier("save-exercise")
                }
            }
            .confirmationDialog(
                "Discard exercise changes?",
                isPresented: $isConfirmingDiscard,
                titleVisibility: .visible
            ) {
                Button("Discard Changes", role: .destructive) {
                    dismiss()
                }

                Button("Keep Editing", role: .cancel) {}
            }
        }
    }

    private var hasUnsavedChanges: Bool {
        exercise != initialExercise
    }

    private var setCount: Binding<Int> {
        Binding(
            get: { exercise.targetSetCount },
            set: { newValue in
                exercise.targetSetCount = newValue
                exercise.targetSetsText = "\(newValue) sets"
            }
        )
    }
}

struct AddWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exerciseDefinitions: [ExerciseDefinition]
    let onCreate: (WorkoutTemplate, Int) -> Void

    @State private var template = WorkoutTemplate(name: "", order: 0, exercises: [])
    @State private var weeklyFrequency = 1
    @State private var path: [WorkoutTemplateRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("Workout") {
                    TextField("Leg Day", text: $template.name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .accessibilityLabel("Workout name")
                        .accessibilityIdentifier("workout-name")
                }

                Section("Schedule") {
                    Stepper(value: $weeklyFrequency, in: 1...14) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Times per week")
                                .font(.body.weight(.semibold))

                            Text("\(weeklyFrequency) \(weeklyFrequency == 1 ? "session" : "sessions") every week")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .accessibilityIdentifier("new-workout-frequency")
                }

                Section {
                    if template.exercises.isEmpty {
                        Text("No exercises yet")
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
                } header: {
                    HStack {
                        Text("Exercises")
                        Spacer()
                        if template.exercises.count > 1 {
                            EditButton()
                                .textCase(nil)
                        }
                    }
                } footer: {
                    if template.exercises.isEmpty {
                        Text("Add at least one exercise to save this workout.")
                            .textCase(nil)
                    }
                }

                Section {
                    NavigationLink(value: WorkoutTemplateRoute.exercise) {
                        Label("Add Exercise", systemImage: "plus")
                    }

                    NavigationLink(value: WorkoutTemplateRoute.superset) {
                        Label("Add Superset", systemImage: "link.badge.plus")
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenBackground)
            .navigationTitle("New Workout")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(hasDraftContent)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                        .accessibilityIdentifier("save-workout")
                }
            }
            .navigationDestination(for: WorkoutTemplateRoute.self) { route in
                switch route {
                case .exercise:
                    TemplateExerciseEntryView(
                        exerciseDefinitions: exerciseDefinitions,
                        cancel: returnToWorkout,
                        add: addExercise
                    )
                case .superset:
                    TemplateSupersetEntryView(
                        exerciseDefinitions: exerciseDefinitions,
                        cancel: returnToWorkout,
                        add: addSuperset
                    )
                }
            }
        }
    }

    private var hasDraftContent: Bool {
        !template.name.trimmed.isEmpty || !template.exercises.isEmpty || weeklyFrequency != 1
    }

    private var canSave: Bool {
        !template.name.trimmed.isEmpty && !template.exercises.isEmpty
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

    private func save() {
        normalizeExerciseOrders()
        template.name = template.name.trimmed
        onCreate(template, weeklyFrequency)
        dismiss()
    }

    private func addExercise(_ exercise: TemplateExercise) {
        var exercise = exercise
        exercise.order = template.exercises.count
        template.exercises.append(exercise)
        normalizeExerciseOrders()
        returnToWorkout()
    }

    private func addSuperset(_ exercises: [TemplateExercise]) {
        template.exercises.append(contentsOf: exercises)
        normalizeExerciseOrders()
        returnToWorkout()
    }

    private func returnToWorkout() {
        guard !path.isEmpty else { return }
        path.removeLast()
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

private enum WorkoutTemplateRoute: Hashable {
    case exercise
    case superset
}

private struct TemplateExerciseEntryView: View {
    let exerciseDefinitions: [ExerciseDefinition]
    let cancel: () -> Void
    let add: (TemplateExercise) -> Void

    @State private var name = ""
    @State private var setCount = 3
    @State private var targetReps = "8-12 reps"

    var body: some View {
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
        .scrollContentBackground(.hidden)
        .background(AppTheme.screenBackground)
        .navigationTitle("Add Exercise")
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: cancel)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Add", action: addExercise)
                    .disabled(name.trimmed.isEmpty)
            }
        }
    }

    private func addExercise() {
        add(
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
    }
}

private struct TemplateSupersetEntryView: View {
    let exerciseDefinitions: [ExerciseDefinition]
    let cancel: () -> Void
    let add: ([TemplateExercise]) -> Void

    @State private var firstName = ""
    @State private var secondName = ""
    @State private var setCount = 3
    @State private var targetReps = "8-12 reps"

    var body: some View {
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
        .scrollContentBackground(.hidden)
        .background(AppTheme.screenBackground)
        .navigationTitle("Add Superset")
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: cancel)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Add", action: addSuperset)
                    .disabled(!canAdd)
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

        add(
            [first, second].enumerated().map { index, name in
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
    }
}

private struct WorkoutTemplateEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let exerciseDefinitions: [ExerciseDefinition]
    let onSave: (WorkoutTemplate) -> Void

    @State private var template: WorkoutTemplate
    @State private var path: [WorkoutTemplateRoute] = []

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
        NavigationStack(path: $path) {
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
                    NavigationLink(value: WorkoutTemplateRoute.exercise) {
                        Label("Add Exercise", systemImage: "plus")
                    }

                    NavigationLink(value: WorkoutTemplateRoute.superset) {
                        Label("Add Superset", systemImage: "link.badge.plus")
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenBackground)
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
            .navigationDestination(for: WorkoutTemplateRoute.self) { route in
                switch route {
                case .exercise:
                    TemplateExerciseEntryView(
                        exerciseDefinitions: exerciseDefinitions,
                        cancel: returnToWorkout,
                        add: addExercise
                    )
                case .superset:
                    TemplateSupersetEntryView(
                        exerciseDefinitions: exerciseDefinitions,
                        cancel: returnToWorkout,
                        add: addSuperset
                    )
                }
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
        returnToWorkout()
    }

    private func addSuperset(_ exercises: [TemplateExercise]) {
        template.exercises.append(contentsOf: exercises)
        normalizeExerciseOrders()
        returnToWorkout()
    }

    private func returnToWorkout() {
        guard !path.isEmpty else { return }
        path.removeLast()
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

private struct PlanBlock: Identifiable {
    enum Kind {
        case single(TemplateExercise)
        case superset([TemplateExercise])
    }

    let id: UUID
    let kind: Kind
}
