import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: WorkoutStore
    @State private var previousWorkoutSelection: WeeklyWorkoutStatus?
    @State private var isAddingWorkout = false

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
            .toolbar(store.data.activeSession == nil ? .hidden : .visible, for: .navigationBar)
            .toolbar(store.data.activeSession == nil ? .visible : .hidden, for: .tabBar)
            .background(AppTheme.screenBackground)
            .sheet(item: $previousWorkoutSelection) { status in
                LogPreviousWorkoutSheet(
                    initialDate: Date(),
                    initialTemplateID: status.template.id,
                    initialOccurrenceID: status.occurrence.id
                )
            }
            .sheet(isPresented: $isAddingWorkout) {
                AddWorkoutSheet(
                    exerciseDefinitions: store.data.exerciseDefinitions,
                    onCreate: store.createWorkout
                )
            }
        }
    }

    private var workoutStartView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                NavigationLink {
                    CalendarView()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "calendar")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 44, height: 44)

                        Text(Date().workoutLongDate)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Calendar, \(Date().workoutLongDate)")

                if store.data.templates.isEmpty {
                    TodayEmptyPlanView {
                        isAddingWorkout = true
                    }
                } else {
                    WeeklyProgressCard(
                        statuses: store.weeklyHomeWorkoutStatuses,
                        groups: store.weeklyHomeTemplateGroups,
                        onLogPrevious: openPreviousWorkoutLogger
                    )

                    Divider()
                }

                if let suggested = store.nextUnloggedWeeklyStatus?.template ?? store.suggestedTemplate {
                    AppCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(store.todayLoggedSessions.isEmpty ? "Today" : "Up next")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textSecondary)

                                Spacer()

                                if store.nextUnloggedWeeklyStatus?.template.id == suggested.id {
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
                                if let status = store.nextUnloggedWeeklyStatus,
                                   status.template.id == suggested.id {
                                    store.startWorkout(for: status)
                                } else {
                                    store.startWorkout(from: suggested)
                                }
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

                    Divider()
                }

                if !store.data.templates.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Change workout")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.vertical, 14)

                        ForEach(Array(store.data.templates.enumerated()), id: \.element.id) { index, template in
                            Button {
                                store.startWorkout(from: template)
                            } label: {
                                ViewThatFits(in: .horizontal) {
                                    HStack(spacing: 8) {
                                        Text(template.name)
                                            .font(.headline)
                                            .foregroundStyle(AppTheme.ink)
                                            .lineLimit(1)

                                        Spacer(minLength: 4)

                                        HStack(spacing: 6) {
                                            templateMeta(template)
                                        }

                                        Image(systemName: "chevron.right")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(AppTheme.textTertiary)
                                    }

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(template.name)
                                            .font(.headline)
                                            .foregroundStyle(AppTheme.ink)

                                        HStack(spacing: 6) {
                                            templateMeta(template)
                                        }
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 13)

                            if index < store.data.templates.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func templateMetaRow(for template: WorkoutTemplate) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                templateMeta(template)
            }

            VStack(alignment: .leading, spacing: 6) {
                templateMeta(template)
            }
        }
    }

    @ViewBuilder
    private func templateMeta(_ template: WorkoutTemplate) -> some View {
        Pill("\(template.exercises.count) exercises", systemImage: "dumbbell")

        if template.supersetCount > 0 {
            Pill("\(template.supersetCount) supersets", systemImage: "link")
        }
    }

    private func openPreviousWorkoutLogger(status: WeeklyWorkoutStatus) {
        previousWorkoutSelection = status
    }
}

private struct TodayEmptyPlanView: View {
    let addWorkout: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            EmptyStateView(
                title: "No workouts yet",
                message: "Add your first workout to get started.",
                systemImage: "calendar.badge.plus"
            )

            Button(action: addWorkout) {
                EmptyStateActionLabel(title: "Add Workout", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(AppTheme.accent)
            .accessibilityIdentifier("today-add-workout")
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
    }
}

private struct WeeklyProgressCard: View {
    let statuses: [WeeklyWorkoutStatus]
    let groups: [WeeklyTemplateGroup]
    let onLogPrevious: (WeeklyWorkoutStatus) -> Void

    private var loggedCount: Int {
        statuses.filter(\.isLogged).count
    }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("This Week")
                            .font(.headline)

                        Text("\(loggedCount) of \(statuses.count) workouts complete")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer()

                    progressBadge
                }

                VStack(spacing: 0) {
                    ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                        WeeklyTemplateProgressRow(group: group, onLogPrevious: onLogPrevious)

                        if index < groups.count - 1 {
                            Divider()
                        }
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
            .overlay {
                Capsule()
                    .stroke(AppTheme.divider, lineWidth: 1)
            }
    }

}

private struct WeeklyTemplateProgressRow: View {
    let group: WeeklyTemplateGroup
    let onLogPrevious: (WeeklyWorkoutStatus) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(group.template.name)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)

            Spacer(minLength: 8)

            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    ForEach(Array(group.statuses.enumerated()), id: \.element.id) { index, status in
                        Button {
                            onLogPrevious(status)
                        } label: {
                            Image(systemName: status.isLogged ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(status.isLogged ? AppTheme.success : AppTheme.textTertiary)
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            "\(group.template.name), workout \(index + 1) of \(group.frequency), \(status.isLogged ? "complete" : "not complete")"
                        )
                        .accessibilityHint("Log this planned workout")
                    }
                }
            }
            .scrollIndicators(.hidden)
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("weekly-template-\(group.template.id.uuidString)")
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
