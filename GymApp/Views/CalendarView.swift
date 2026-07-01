import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var store: WorkoutStore
    @State private var visibleMonth = Date()
    @State private var selectedDate = Date()
    @State private var isLoggingPreviousWorkout = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    monthHeader
                    weekdayHeader
                    monthGrid
                    selectedDayWorkouts
                }
                .padding()
            }
            .background(AppTheme.screenBackground)
            .navigationTitle("Calendar")
            .onAppear {
                moveToUsefulMonthIfNeeded()
            }
            .sheet(isPresented: $isLoggingPreviousWorkout) {
                LogPreviousWorkoutSheet(initialDate: selectedDate)
            }
        }
    }

    private var monthHeader: some View {
        AppCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(monthTitle)
                        .font(.system(.title, design: .rounded).weight(.bold))

                    Text("\(sessions(in: visibleMonth).count) workouts")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        moveMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        moveMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(calendar.shortStandaloneWeekdaySymbols, id: \.self) { symbol in
                Text(symbol.prefix(1))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 4)
    }

    private var monthGrid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(monthDays) { day in
                if let date = day.date {
                    dayCell(date)
                } else {
                    Color.clear
                        .frame(height: 58)
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let daySessions = sessions(on: date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)

        return Button {
            selectedDate = date
        } label: {
            VStack(spacing: 6) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : AppTheme.ink)

                HStack(spacing: 3) {
                    ForEach(0..<min(daySessions.count, 3), id: \.self) { index in
                        Circle()
                            .fill(isSelected ? Color.white.opacity(0.9) : color(for: daySessions[index].workoutName))
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.accent)
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.surface)
                }
            }
            .overlay {
                if isToday && !isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppTheme.accent, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var selectedDayWorkouts: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedDate.workoutShortDate)
                .font(.headline)

            Button {
                isLoggingPreviousWorkout = true
            } label: {
                Label("Log Workout", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(AppTheme.accent)

            let daySessions = sessions(on: selectedDate)

            if daySessions.isEmpty {
                AppCard {
                    Label("No workout logged", systemImage: "calendar")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            } else {
                ForEach(daySessions) { session in
                    NavigationLink {
                        if let binding = binding(for: session.id) {
                            HistoryDetailView(session: binding)
                        } else {
                            EmptyStateView(
                                title: "Workout Missing",
                                message: "This workout could not be loaded.",
                                systemImage: "exclamationmark.triangle"
                            )
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(color(for: session.workoutName))
                                .frame(width: 12, height: 12)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.workoutName)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.ink)

                                Text("\(session.exercises.count) exercises")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        .padding(16)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func binding(for sessionId: UUID) -> Binding<WorkoutSession>? {
        guard let index = store.data.history.firstIndex(where: { $0.id == sessionId }) else {
            return nil
        }

        return $store.data.history[index]
    }

    private var monthTitle: String {
        Self.monthFormatter.string(from: visibleMonth)
    }

    private var monthDays: [CalendarDay] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: visibleMonth),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }

        let leadingBlankCount = calendar.dateComponents([.day], from: firstWeek.start, to: monthInterval.start).day ?? 0
        let dayCount = calendar.range(of: .day, in: .month, for: visibleMonth)?.count ?? 0
        var days = (0..<leadingBlankCount).map { CalendarDay(id: "blank-\($0)", date: nil) }

        for offset in 0..<dayCount {
            if let date = calendar.date(byAdding: .day, value: offset, to: monthInterval.start) {
                days.append(CalendarDay(id: Self.dayIDFormatter.string(from: date), date: date))
            }
        }

        while days.count % 7 != 0 {
            days.append(CalendarDay(id: "tail-\(days.count)", date: nil))
        }

        return days
    }

    private func moveMonth(by value: Int) {
        visibleMonth = calendar.date(byAdding: .month, value: value, to: visibleMonth) ?? visibleMonth
        selectedDate = visibleMonth
    }

    private func moveToUsefulMonthIfNeeded() {
        guard sessions(in: visibleMonth).isEmpty,
              let latestWorkoutDate = store.data.history.map(\.date).max() else {
            return
        }

        visibleMonth = latestWorkoutDate
        selectedDate = latestWorkoutDate
    }

    private func sessions(on date: Date) -> [WorkoutSession] {
        store.data.history
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date > $1.date }
    }

    private func sessions(in date: Date) -> [WorkoutSession] {
        store.data.history.filter { calendar.isDate($0.date, equalTo: date, toGranularity: .month) }
    }

    private func color(for workoutName: String) -> Color {
        let normalized = workoutName.normalizedExerciseName

        if normalized.contains("push") {
            return AppTheme.accent
        } else if normalized.contains("pull") {
            return Color.blue
        } else if normalized.contains("leg") {
            return Color.green
        } else if normalized.contains("cardio") || normalized.contains("hiit") {
            return Color.orange
        } else {
            return Color.purple
        }
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    private static let dayIDFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct CalendarDay: Identifiable {
    let id: String
    let date: Date?
}
