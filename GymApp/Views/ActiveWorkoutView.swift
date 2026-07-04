import SwiftUI
import UniformTypeIdentifiers

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
    @State private var targetedBlockId: String?
    @State private var draggedBlockId: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                headerCard
                    .id("header")

                ForEach(workoutBlocks) { block in
                    workoutBlockView(block)
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

    @ViewBuilder
    private func workoutBlockView(_ block: WorkoutBlock) -> some View {
        switch block.kind {
        case .single(let exerciseId):
            ExerciseCard(
                exercise: binding(for: exerciseId),
                onRemove: { removeExercise(id: exerciseId) },
                trailingHeaderControl: AnyView(dragHandle(for: block))
            )
            .workoutBlockDropTarget(
                block,
                draggedBlockId: $draggedBlockId,
                targetedBlockId: $targetedBlockId,
                moveBlock: moveBlock
            )
            .id(block.id)
        case .superset(let exerciseIds):
            supersetBlock(exerciseIds: exerciseIds, block: block)
                .workoutBlockDropTarget(
                    block,
                    draggedBlockId: $draggedBlockId,
                    targetedBlockId: $targetedBlockId,
                    moveBlock: moveBlock
                )
                .id(block.id)
        }
    }

    private func supersetBlock(exerciseIds: [UUID], block: WorkoutBlock) -> some View {
        AppCard {
            HStack(alignment: .center, spacing: 8) {
                Pill("Superset")
                Spacer()
                dragHandle(for: block)
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

    private func dragHandle(for block: WorkoutBlock) -> some View {
        Image(systemName: "line.3.horizontal")
            .font(.callout.weight(.bold))
            .foregroundStyle(AppTheme.textSecondary)
            .frame(width: 38, height: 38)
            .background(AppTheme.surface.opacity(0.96))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(AppTheme.chipBorder, lineWidth: 1)
            }
            .contentShape(Capsule())
            .onDrag {
                draggedBlockId = block.id
                return NSItemProvider(object: block.id as NSString)
            } preview: {
                Text("Move")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(AppTheme.surface)
                    .clipShape(Capsule())
            }
            .accessibilityLabel("Move exercise")
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

    private func moveBlock(_ draggedBlockId: String, before targetBlockId: String) {
        guard draggedBlockId != targetBlockId else { return }
        var blocks = workoutBlocks

        guard let sourceIndex = blocks.firstIndex(where: { $0.id == draggedBlockId }),
              let targetIndex = blocks.firstIndex(where: { $0.id == targetBlockId }) else {
            return
        }

        withAnimation(.snappy) {
            let draggedBlock = blocks.remove(at: sourceIndex)
            let destinationIndex = sourceIndex < targetIndex ? targetIndex : targetIndex
            blocks.insert(draggedBlock, at: destinationIndex)

            applyBlockOrder(blocks)
        }
    }

    private func applyBlockOrder(_ blocks: [WorkoutBlock]) {
        var nextOrder = 0

        for block in blocks {
            for exerciseId in block.exerciseIds {
                guard let exerciseIndex = session.exercises.firstIndex(where: { $0.id == exerciseId }) else {
                    continue
                }

                session.exercises[exerciseIndex].order = nextOrder
                nextOrder += 1
            }
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

    var exerciseIds: [UUID] {
        switch kind {
        case .single(let exerciseId):
            return [exerciseId]
        case .superset(let exerciseIds):
            return exerciseIds
        }
    }
}

private extension View {
    func workoutBlockDropTarget(
        _ block: WorkoutBlock,
        draggedBlockId: Binding<String?>,
        targetedBlockId: Binding<String?>,
        moveBlock: @escaping (String, String) -> Void
    ) -> some View {
        self
            .opacity(targetedBlockId.wrappedValue == block.id ? 0.72 : 1)
            .onDrop(
                of: [UTType.text],
                delegate: WorkoutBlockDropDelegate(
                    targetBlock: block,
                    draggedBlockId: draggedBlockId,
                    targetedBlockId: targetedBlockId,
                    moveBlock: moveBlock
                )
            )
    }
}

private struct WorkoutBlockDropDelegate: DropDelegate {
    let targetBlock: WorkoutBlock
    @Binding var draggedBlockId: String?
    @Binding var targetedBlockId: String?
    let moveBlock: (String, String) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedBlockId, draggedBlockId != targetBlock.id else {
            return
        }

        targetedBlockId = targetBlock.id
        moveBlock(draggedBlockId, targetBlock.id)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedBlockId = nil
        targetedBlockId = nil
        return true
    }

    func dropExited(info: DropInfo) {
        if targetedBlockId == targetBlock.id {
            targetedBlockId = nil
        }
    }
}
