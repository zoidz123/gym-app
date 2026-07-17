import SwiftUI

enum AppTheme {
    static let accent = Color("AccentColor")
    static let accentSoft = Color("AccentColor").opacity(0.14)
    static let success = Color("AccentColor")
    static let successSoft = Color("AccentColor").opacity(0.1)
    static let ink = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(.tertiaryLabel)
    static let screenBackground = Color(.systemBackground)
    static let surface = Color(.systemBackground)
    static let rowBackground = Color(.secondarySystemBackground)
    static let chipBackground = Color.clear
    static let chipBorder = Color(.separator)
    static let divider = Color(.separator)
}

struct AppCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .font(.caption.weight(.medium))
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let message: String?
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(AppTheme.ink)

            Text(title)
                .font(.headline)

            if let message, !message.isEmpty {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 24 : 48)
    }
}

struct EmptyStateActionLabel: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let systemImage: String

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                Text(title)
            } else {
                Label(title, systemImage: systemImage)
            }
        }
        .frame(maxWidth: .infinity)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
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
