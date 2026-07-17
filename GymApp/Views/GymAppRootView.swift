import SwiftUI

struct GymAppRootView: View {
    @State private var selectedTab = AppTab.initial

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.shadowColor = UIColor(AppTheme.divider)

        let selectedColor = UIColor(AppTheme.accent)
        let normalColor = UIColor(AppTheme.textSecondary)

        for itemAppearance in [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance
        ] {
            itemAppearance.selected.iconColor = selectedColor
            itemAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
            itemAppearance.normal.iconColor = normalColor
            itemAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "figure.strengthtraining.traditional")
                }
                .tag(AppTab.today)

            PlanView()
                .tabItem {
                    Label("Plan", systemImage: "list.bullet.rectangle")
                }
                .tag(AppTab.plan)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(AppTab.history)
        }
    }
}

private enum AppTab: Hashable {
    case today
    case plan
    case history

    static var initial: AppTab {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["UI_TEST_START_TAB"] {
        case "history":
            return .history
        case "plan":
            return .plan
        default:
            return .today
        }
        #else
        return .today
        #endif
    }
}
