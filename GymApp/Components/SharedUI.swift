import SwiftUI

enum AppTheme {
    static let accent = Color(red: 1.0, green: 0.22, blue: 0.36)
    static let accentSoft = Color(red: 1.0, green: 0.90, blue: 0.92)
    static let success = Color(red: 0.05, green: 0.55, blue: 0.32)
    static let successSoft = Color(red: 0.90, green: 0.97, blue: 0.93)
    static let ink = Color(red: 0.08, green: 0.08, blue: 0.09)
    static let textSecondary = Color(red: 0.43, green: 0.43, blue: 0.46)
    static let textTertiary = Color(red: 0.58, green: 0.58, blue: 0.62)
    static let screenBackground = Color(red: 0.96, green: 0.96, blue: 0.95)
    static let surface = Color.white
    static let rowBackground = Color(red: 0.94, green: 0.94, blue: 0.93)
    static let chipBackground = Color.white
    static let chipBorder = Color.black.opacity(0.08)
    static let divider = Color.black.opacity(0.10)
}

struct AppCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 8)
    }
}

struct AppScreenHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.ink)

            Spacer(minLength: 12)

            trailing
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }
}

extension AppScreenHeader where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title) {
            EmptyView()
        }
    }
}

struct Pill: View {
    let title: String
    let systemImage: String?

    init(_ title: String, systemImage: String? = nil) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            if let systemImage {
                Image(systemName: systemImage)
            }
        }
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(AppTheme.ink)
        .background(AppTheme.chipBackground)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(AppTheme.chipBorder, lineWidth: 1)
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

extension Date {
    var workoutShortDate: String {
        Self.shortFormatter.string(from: self)
    }

    var workoutLongDate: String {
        Self.longFormatter.string(from: self)
    }

    var workoutWeekdayDate: String {
        Self.weekdayFormatter.string(from: self)
    }

    private static let shortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let longFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter
    }()
}
