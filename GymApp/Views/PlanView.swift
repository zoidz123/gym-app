import SwiftUI

struct PlanView: View {
    @EnvironmentObject private var store: WorkoutStore
    @State private var expandedTemplateIds = Set<UUID>()

    var body: some View {
        ScrollView {
            AppScreenHeader("Plan")

            VStack(alignment: .leading, spacing: 14) {
                ForEach(store.data.templates) { template in
                    PlanTemplateCard(
                        template: template,
                        blocks: planBlocks(for: template),
                        isExpanded: expandedTemplateIds.contains(template.id),
                        toggle: { toggle(template.id) }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(AppTheme.screenBackground)
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

private struct PlanBlock: Identifiable {
    enum Kind {
        case single(TemplateExercise)
        case superset(exercises: [TemplateExercise])
    }

    let id: String
    let kind: Kind
}
