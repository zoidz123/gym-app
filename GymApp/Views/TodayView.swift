import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: WorkoutStore
    @State private var isLoggingPreviousWorkout = false
    @State private var previousWorkoutDate = Date()
    @State private var previousWorkoutTemplateID: UUID?

    var body: some View {
        NavigationStack {
            Group {
                if store.data.activeSession != nil {
                    ActiveWorkoutHostView()
                } else {
                    workoutStartView
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(store.data.activeSession == nil ? .visible : .hidden, for: .tabBar)
            .toolbar {
                if store.data.activeSession == nil {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink {
                            CalendarView()
                        } label: {
                            Image(systemName: "calendar")
                                .font(.headline.weight(.semibold))
                        }
                        .accessibilityLabel("Calendar")
                    }
                }
            }
            .background(AppTheme.screenBackground)
            .sheet(isPresented: $isLoggingPreviousWorkout) {
                LogPreviousWorkoutSheet(
                    initialDate: previousWorkoutDate,
                    initialTemplateID: previousWorkoutTemplateID
                )
            }
        }
    }

    private var workoutStartView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                WeeklyProgressCard(
                    statuses: store.weeklyWorkoutStatuses,
                    loggedToday: store.todayLoggedSessions,
                    onLogPrevious: openPreviousWorkoutLogger
                )

                if let suggested = store.nextUnloggedWeeklyTemplate ?? store.suggestedTemplate {
                    AppCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(store.todayLoggedSessions.isEmpty ? "Today" : "Up next")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textSecondary)

                                Spacer()

                                if store.scheduledTemplateForToday?.id == suggested.id {
                                    Pill("Scheduled", systemImage: "calendar")
                                } else {
                                    Pill("Next up", systemImage: "arrow.right")
                                }
                            }

                            Text(suggested.name)
                                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)

                            templateMetaRow(for: suggested)

                            Button {
                                store.startWorkout(from: suggested)
                            } label: {
                                Label("Start \(suggested.name)", systemImage: "play.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(AppTheme.accent)
                            .padding(.top, 6)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Change workout")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)

                    ForEach(store.data.templates) { template in
                        Button {
                            store.startWorkout(from: template)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(template.name)
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.ink)

                                    templateMetaRow(for: template)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(14)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: 6)
                    }
                }
            }
            .padding()
        }
    }

    private func templateMetaRow(for template: WorkoutTemplate) -> some View {
        HStack(spacing: 8) {
            Pill("\(template.exercises.count) exercises", systemImage: "dumbbell")

            if template.supersetCount > 0 {
                Pill("\(template.supersetCount) supersets", systemImage: "link")
            }
        }
    }

    private func openPreviousWorkoutLogger(template: WorkoutTemplate) {
        previousWorkoutDate = Date()
        previousWorkoutTemplateID = template.id
        isLoggingPreviousWorkout = true
    }
}

private struct WeeklyProgressCard: View {
    let statuses: [WeeklyWorkoutStatus]
    let loggedToday: [WorkoutSession]
    let onLogPrevious: (WorkoutTemplate) -> Void

    private var loggedCount: Int {
        statuses.filter(\.isLogged).count
    }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(loggedToday.isEmpty ? "This week" : "Workout logged today")
                            .font(.headline)

                        Text("\(loggedCount) of \(statuses.count) workouts complete")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer()

                    progressBadge
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(statuses) { status in
                        WeeklyWorkoutChip(status: status) {
                            onLogPrevious(status.template)
                        }
                    }
                }

                if !loggedToday.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.success)

                        Text(todayLoggedText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private var progressBadge: some View {
        Text("\(loggedCount)/\(statuses.count)")
            .font(.system(.headline, design: .rounded).weight(.bold))
            .foregroundStyle(loggedCount == statuses.count ? AppTheme.success : AppTheme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(loggedCount == statuses.count ? AppTheme.successSoft : AppTheme.screenBackground)
            .clipShape(Capsule())
    }

    private var todayLoggedText: String {
        let names = loggedToday.map(\.workoutName).joined(separator: ", ")
        return names.isEmpty ? "Logged today" : "Logged today: \(names)"
    }
}

private struct WeeklyWorkoutChip: View {
    let status: WeeklyWorkoutStatus
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 7) {
                Image(systemName: status.isLogged ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(status.isLogged ? AppTheme.success : AppTheme.textTertiary)

                Text(status.displayName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(status.isLogged ? AppTheme.ink : AppTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(status.isLogged ? AppTheme.successSoft : AppTheme.screenBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct ActiveWorkoutHostView: View {
    @EnvironmentObject private var store: WorkoutStore

    var body: some View {
        if let binding = activeSessionBinding {
            ActiveWorkoutView(session: binding)
        } else {
            EmptyStateView(
                title: "No Active Workout",
                message: "Start a planned workout to begin logging.",
                systemImage: "figure.strengthtraining.traditional"
            )
        }
    }

    private var activeSessionBinding: Binding<WorkoutSession>? {
        return Binding(
            get: {
                store.data.activeSession ?? WorkoutSession(
                    date: Date(),
                    workoutName: "",
                    bodyweight: "",
                    duration: "",
                    notes: "",
                    isSeededHistory: false,
                    exercises: []
                )
            },
            set: { updatedSession in
                guard store.data.activeSession != nil else { return }
                store.data.activeSession = updatedSession
            }
        )
    }
}
