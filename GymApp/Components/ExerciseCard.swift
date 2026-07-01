import SwiftUI

struct ExerciseCard: View {
    @Binding var exercise: LoggedExercise
    let onRemove: () -> Void

    var body: some View {
        AppCard {
            ExerciseLoggingContent(
                exercise: $exercise,
                isInsideSuperset: false,
                onRemove: onRemove
            )
        }
    }
}

struct ExerciseLoggingContent: View {
    @Binding var exercise: LoggedExercise
    let isInsideSuperset: Bool
    let onRemove: () -> Void
    @State private var isConfirmingRemove = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(isInsideSuperset ? .headline : .title3.weight(.semibold))
                        .lineLimit(2)
                }

                Spacer()

                Button(role: .destructive) {
                    isConfirmingRemove = true
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 36, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(exercise.name)")
            }

            VStack(spacing: 0) {
                ForEach(Array($exercise.sets.enumerated()), id: \.element.id) { index, $set in
                    SetRowEditor(
                        set: $set,
                        metric: .from(targetRepsText: exercise.targetRepsText),
                        prefersLoad: prefersLoad
                    )

                    if index < exercise.sets.count - 1 {
                        Divider()
                            .padding(.leading, 12)
                    }
                }
            }
            .padding(.vertical, 2)
            .background(AppTheme.rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack(spacing: 10) {
                Button {
                    exercise.addBlankSet()
                } label: {
                    Label("Add Set", systemImage: "plus")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.accent)

                if exercise.sets.count > 1 {
                    Button(role: .destructive) {
                        removeLastSet()
                    } label: {
                        Label("Remove", systemImage: "minus")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .confirmationDialog("Remove \(exercise.name)?", isPresented: $isConfirmingRemove, titleVisibility: .visible) {
            Button("Remove Exercise", role: .destructive) {
                onRemove()
            }

            Button("Cancel", role: .cancel) {}
        }
    }

    private func removeLastSet() {
        exercise.sets.removeLast()

        for index in exercise.sets.indices {
            exercise.sets[index].order = index + 1
        }
    }

    private var prefersLoad: Bool {
        exercise.sets.contains { set in
            set.loadValue != nil || set.previousLoadValue != nil || !set.previousLoadText.isEmpty
        }
    }
}
