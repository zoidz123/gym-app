import SwiftUI
import UniformTypeIdentifiers

struct ActiveWorkoutView: View {
    @EnvironmentObject private var store: WorkoutStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var session: WorkoutSession
    var finishAccessibilityLabel = "Finish workout"
    var discardConfirmationTitle = "Discard this workout?"
    var discardButtonTitle = "Discard Workout"
    var onFinish: (() -> Void)?
    var onDiscard: (() -> Void)?

    @State private var isAddingExercise = false
    @State private var isAddingSuperset = false
    @State private var isConfirmingDiscard = false
    @State private var targetedBlockId: String?
    @State private var draggedBlockId: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                headerCard
                    .id("header")

                Divider()

                restTimerSection

                Divider()

                ForEach(Array(workoutBlocks.enumerated()), id: \.element.id) { index, block in
                    workoutBlockView(block)

                    if index < workoutBlocks.count - 1 {
                        Divider()
                    }
                }

                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: 12) {
                            workoutActionButtons
                        }
                    } else {
                        HStack(spacing: 12) {
                            workoutActionButtons
                        }
                    }
                }
                .padding(.top, 16)
                .id("actions")
            }
            .padding(.horizontal)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppTheme.screenBackground)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .destructive) {
                    isConfirmingDiscard = true
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(AppTheme.destructive)
                }
                .accessibilityLabel("Discard workout")
                .accessibilityIdentifier("discard-workout")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    finishWorkout()
                } label: {
                    Image(systemName: session.exercises.isEmpty ? "checkmark.circle" : "checkmark.circle.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(session.exercises.isEmpty ? AppTheme.textTertiary : AppTheme.success)
                }
                .disabled(session.exercises.isEmpty)
                .accessibilityLabel(finishAccessibilityLabel)
                .accessibilityIdentifier("finish-workout")
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
        .onChange(of: completedSetIDs) { previousIDs, completedIDs in
            let newlyCompletedIDs = completedIDs.subtracting(previousIDs)
            guard !newlyCompletedIDs.isEmpty else { return }

            if session.completedSetCount < session.totalSetCount {
                startRestTimer()
            } else {
                session.restTimer = nil
            }
        }
    }

    @ViewBuilder
    private var restTimerSection: some View {
        if let timer = session.restTimer {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                restTimerContent(timer: timer, date: context.date)
            }
        } else {
            Button(action: startRestTimer) {
                Label("Start 1:30 Rest", systemImage: "timer")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("start-rest-timer")
        }
    }

    private func restTimerContent(timer: WorkoutRestTimer, date: Date) -> some View {
        let remainingSeconds = timer.remainingSeconds(at: date)
        let isComplete = timer.isComplete(at: date)

        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    restTimerStatus(remainingSeconds: remainingSeconds, isComplete: isComplete)
                    restTimerControls(timer: timer, date: date, isComplete: isComplete)
                }
            } else {
                HStack(spacing: 12) {
                    restTimerStatus(remainingSeconds: remainingSeconds, isComplete: isComplete)
                    Spacer(minLength: 8)
                    restTimerControls(timer: timer, date: date, isComplete: isComplete)
                }
            }
        }
        .padding(.vertical, 10)
        .sensoryFeedback(.success, trigger: isComplete)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("rest-timer")
    }

    private func restTimerStatus(remainingSeconds: Int, isComplete: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(isComplete ? "Rest complete" : "Rest")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isComplete ? AppTheme.success : AppTheme.textSecondary)

            Text(formattedRestTime(remainingSeconds))
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.ink)
                .contentTransition(.numericText())
                .accessibilityLabel(isComplete ? "Rest complete" : "\(remainingSeconds) seconds remaining")
        }
    }

    private func restTimerControls(
        timer: WorkoutRestTimer,
        date: Date,
        isComplete: Bool
    ) -> some View {
        HStack(spacing: 8) {
            Button {
                if isComplete {
                    restartRestTimer(at: date)
                } else if timer.isPaused {
                    resumeRestTimer(at: date)
                } else {
                    pauseRestTimer(at: date)
                }
            } label: {
                Image(systemName: isComplete ? "arrow.counterclockwise" : (timer.isPaused ? "play.fill" : "pause.fill"))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.accent)
            .accessibilityLabel(isComplete ? "Restart rest timer" : (timer.isPaused ? "Resume rest timer" : "Pause rest timer"))
            .accessibilityIdentifier("rest-timer-primary-control")

            Button {
                session.restTimer = nil
            } label: {
                Text(isComplete ? "Done" : "Skip")
                    .font(.subheadline.weight(.bold))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.textSecondary)
            .accessibilityLabel(isComplete ? "Dismiss rest timer" : "Skip rest timer")
            .accessibilityIdentifier("skip-rest-timer")
        }
    }

    @ViewBuilder
    private var workoutActionButtons: some View {
        Button {
            isAddingExercise = true
        } label: {
            Label("Add Exercise", systemImage: "plus")
                .font(.headline)
                .foregroundStyle(AppTheme.contentOnStrongFill)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(AppTheme.ink)
        .accessibilityIdentifier("active-add-exercise")

        Button {
            isAddingSuperset = true
        } label: {
            Label("Add Superset", systemImage: "link.badge.plus")
                .font(.headline)
                .foregroundStyle(AppTheme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.screenBackground, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(AppTheme.accent, lineWidth: 1.5)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("active-add-superset")
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
                    .textFieldStyle(.plain)
                    .padding(.vertical, 10)
                    .frame(minHeight: 44)
                    .overlay(alignment: .bottom) {
                        Divider()
                    }
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
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
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

    private var completedSetIDs: Set<UUID> {
        Set(
            session.exercises
                .flatMap(\.sets)
                .filter(\.isCompleted)
                .map(\.id)
        )
    }

    private func startRestTimer() {
        session.restTimer = WorkoutRestTimer()
    }

    private func pauseRestTimer(at date: Date) {
        session.restTimer?.pause(at: date)
    }

    private func resumeRestTimer(at date: Date) {
        session.restTimer?.resume(at: date)
    }

    private func restartRestTimer(at date: Date) {
        session.restTimer?.restart(at: date)
    }

    private func formattedRestTime(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
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

        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
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
        session.restTimer = nil

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
