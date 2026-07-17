import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: WorkoutStore
    @State private var previousWorkoutSelection: WeeklyWorkoutStatus?

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
            .sheet(item: $previousWorkoutSelection) { status in
                LogPreviousWorkoutSheet(
                    initialDate: Date(),
                    initialTemplateID: status.template.id,
                    initialOccurrenceID: status.occurrence.id
                )
            }
        }
    }

    private var workoutStartView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                WeeklyProgressCard(
                    statuses: store.weeklyWorkoutStatuses,
                    groups: store.weeklyTemplateGroups,
                    onLogPrevious: openPreviousWorkoutLogger
                )

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

    private func openPreviousWorkoutLogger(status: WeeklyWorkoutStatus) {
        previousWorkoutSelection = status
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
            .background(loggedCount == statuses.count ? AppTheme.successSoft : AppTheme.screenBackground)
            .clipShape(Capsule())
    }

}

private struct WeeklyTemplateProgressRow: View {
    let group: WeeklyTemplateGroup
    let onLogPrevious: (WeeklyWorkoutStatus) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(group.template.name)
                .font(.subheadline.weight(.semibold))
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
        .padding(.vertical, 5)
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
