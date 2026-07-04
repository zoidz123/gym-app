import SwiftUI

struct SetRowEditor: View {
    @Binding var set: LoggedSet
    let metric: SetMetricDescriptor
    let prefersLoad: Bool
    @State private var isEditingWeight = false
    @State private var isEditingReps = false

    var body: some View {
        HStack(spacing: 12) {
            if showsLoad {
                Button {
                    isEditingWeight = true
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(weightSummary)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(weightSummary == "Weight" ? AppTheme.accent : AppTheme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)

                        if !previousSummary.isEmpty {
                            Text(previousSummary)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit weight")
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text(metric.title)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.ink)

                    if !metric.target.isEmpty {
                        Text(metric.target)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            RepStepper(
                repsValue: set.repsValue,
                caption: showsLoad ? nil : metric.unitLabel,
                edit: { isEditingReps = true },
                decrement: { set.adjustReps(by: -1) },
                increment: { set.adjustReps(by: 1) }
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .background(set.isCompleted ? AppTheme.successSoft : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .sheet(isPresented: $isEditingWeight) {
            SetWeightSheet(set: $set)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $isEditingReps) {
            SetRepsSheet(set: $set, metric: metric)
                .presentationDetents([.height(320), .medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var showsLoad: Bool {
        if set.loadUnit == .bodyweight {
            return true
        }

        if prefersLoad {
            return true
        }

        if set.loadUnit.usesLoadValue {
            return set.loadValue != nil || set.previousLoadValue != nil || !set.previousLoadText.isEmpty
        }

        return false
    }

    private var weightSummary: String {
        if set.loadValue == nil && set.loadUnit != .bodyweight {
            return set.loadUnit.isTime ? "Time" : "Weight"
        }

        return set.loadLabel
    }

    private var previousSummary: String {
        guard !set.previousLoadText.isEmpty || !set.previousRepsText.isEmpty else {
            return ""
        }

        return "last \(set.previousLabel)"
    }
}

struct SetMetricDescriptor {
    let title: String
    let target: String
    let unitLabel: String

    static func from(targetRepsText: String) -> SetMetricDescriptor {
        let lowercasedTarget = targetRepsText.lowercased()

        if lowercasedTarget.contains("min") {
            return SetMetricDescriptor(title: "Duration", target: "target \(targetRepsText)", unitLabel: "min")
        }

        if lowercasedTarget.contains("sec") {
            return SetMetricDescriptor(title: "Time", target: "target \(targetRepsText)", unitLabel: "sec")
        }

        if lowercasedTarget.contains("round") {
            return SetMetricDescriptor(title: "Rounds", target: "target \(targetRepsText)", unitLabel: "rounds")
        }

        if targetRepsText.isEmpty {
            return SetMetricDescriptor(title: "Reps", target: "", unitLabel: "reps")
        }

        return SetMetricDescriptor(title: "Reps", target: "target \(targetRepsText)", unitLabel: "reps")
    }
}

private struct RepStepper: View {
    let repsValue: Int?
    let caption: String?
    let edit: () -> Void
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: decrement) {
                Image(systemName: "minus")
                    .font(.headline.weight(.bold))
                    .frame(width: 52, height: 52)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle((repsValue ?? 0) == 0 ? AppTheme.textTertiary : AppTheme.accent)
            .disabled((repsValue ?? 0) == 0)

            Button(action: edit) {
                VStack(spacing: 0) {
                    Text(repsValue.map(String.init) ?? "0")
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .monospacedDigit()

                    if let caption {
                        Text(caption)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
                .frame(width: 64, height: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(repsValue == nil ? AppTheme.textTertiary : AppTheme.ink)
            .accessibilityLabel("Edit reps")

            Button(action: increment) {
                Image(systemName: "plus")
                    .font(.headline.weight(.bold))
                    .frame(width: 52, height: 52)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.accent)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .background(AppTheme.surface)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(AppTheme.chipBorder, lineWidth: 1)
        }
    }
}

struct SetRepsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var set: LoggedSet
    let metric: SetMetricDescriptor
    @State private var repsText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            SheetHeader(title: metric.title, subtitle: repsSubtitle) {
                dismiss()
            }

            TextField("Reps", text: $repsText, prompt: Text("0"))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 58, weight: .bold, design: .rounded))
                .monospacedDigit()
                .focused($isFocused)
                .frame(maxWidth: .infinity, minHeight: 86)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppTheme.chipBorder, lineWidth: 1)
                }

            Button {
                save()
                dismiss()
            } label: {
                Text("Save")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(AppTheme.accent)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 22)
        .background(AppTheme.screenBackground)
        .onAppear {
            repsText = set.repsValue.map(String.init) ?? ""
            DispatchQueue.main.async {
                isFocused = true
            }
        }
    }

    private func save() {
        set.repsValue = Int(repsText)
        set.isCompleted = true
    }

    private var repsSubtitle: String {
        let last = set.previousRepsText.isEmpty ? "-" : set.previousRepsText

        if metric.unitLabel == "reps" {
            return "last \(last)"
        }

        return "last \(last) \(metric.unitLabel)"
    }
}

struct SetWeightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var set: LoggedSet
    @State private var draftLoadValue: Double?
    @State private var draftLoadUnit: LoadUnit?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(AppTheme.textTertiary.opacity(0.45))
                .frame(width: 56, height: 6)
                .padding(.top, 4)
                .padding(.bottom, 2)

            SheetHeader(title: sheetTitle, subtitle: "last \(set.previousLabel)") {
                dismiss()
            }

            Picker("Unit", selection: unitBinding) {
                ForEach([LoadUnit.lb, .kg, .bodyweight, .seconds]) { unit in
                    Text(unit.entryPickerLabel).tag(unit)
                }
            }
            .pickerStyle(.segmented)

            if set.loadUnit.isTime {
                Picker("Time Unit", selection: timeUnitBinding) {
                    Text("sec").tag(LoadUnit.seconds)
                    Text("min").tag(LoadUnit.minutes)
                }
                .pickerStyle(.segmented)
            }

            weightEditor

            if set.previousLoadValue != nil || !set.previousLoadText.isEmpty {
                Button {
                    draftLoadValue = set.previousLoadValue
                    draftLoadUnit = set.previousLoadUnit ?? activeLoadUnit
                    save()
                    dismiss()
                } label: {
                    Label(useLastTitle, systemImage: "arrow.uturn.backward")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Button {
                save()
                dismiss()
            } label: {
                Text(saveTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(AppTheme.accent)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 22)
        .background(AppTheme.screenBackground)
        .onAppear {
            draftLoadValue = set.loadValue
            draftLoadUnit = set.loadUnit

            DispatchQueue.main.async {
                isFocused = activeLoadUnit.usesLoadValue
            }
        }
    }

    private var activeLoadUnit: LoadUnit {
        draftLoadUnit ?? set.loadUnit
    }

    private var sheetTitle: String {
        activeLoadUnit.isTime ? "Time" : "Weight"
    }

    private var saveTitle: String {
        activeLoadUnit.isTime ? "Save Time" : "Save Weight"
    }

    private var useLastTitle: String {
        activeLoadUnit.isTime ? "Use Last Time" : "Use Last Weight"
    }

    private var weightEditor: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.surface)

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.chipBorder, lineWidth: 1)

                if activeLoadUnit == .bodyweight {
                    Text("Bodyweight")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                } else {
                    TextField(activeLoadUnit.isTime ? "Time" : "Weight", text: loadTextBinding, prompt: Text("0"))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 58, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .focused($isFocused)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 86)

            HStack(spacing: 10) {
                Button {
                    adjustDraftLoad(by: -activeLoadUnit.defaultStep)
                } label: {
                    Image(systemName: "minus")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.bordered)
                .disabled(!activeLoadUnit.usesLoadValue)

                Button {
                    adjustDraftLoad(by: activeLoadUnit.defaultStep)
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.bordered)
                .disabled(!activeLoadUnit.usesLoadValue)
            }
        }
    }

    private var unitBinding: Binding<LoadUnit> {
        Binding(
            get: {
                if activeLoadUnit == .custom {
                    return .lb
                }

                if activeLoadUnit == .minutes {
                    return .seconds
                }

                return activeLoadUnit
            },
            set: { newUnit in
                changeUnit(to: newUnit)
            }
        )
    }

    private var timeUnitBinding: Binding<LoadUnit> {
        Binding(
            get: { activeLoadUnit == .minutes ? .minutes : .seconds },
            set: { newUnit in
                changeUnit(to: newUnit)
            }
        )
    }

    private var loadTextBinding: Binding<String> {
        Binding(
            get: { draftLoadValue?.cleanString ?? "" },
            set: { value in
                draftLoadValue = Double(value)
            }
        )
    }

    private func changeUnit(to newUnit: LoadUnit) {
        let oldUnit = activeLoadUnit

        if let value = draftLoadValue {
            if oldUnit == .lb && newUnit == .kg {
                draftLoadValue = (value * 0.45359237 * 10).rounded() / 10
            } else if oldUnit == .kg && newUnit == .lb {
                draftLoadValue = (value * 2.20462262).rounded()
            } else if !newUnit.usesLoadValue {
                draftLoadValue = nil
            }
        }

        if newUnit.usesLoadValue && draftLoadValue == nil {
            draftLoadValue = 0
        }

        draftLoadUnit = newUnit
        isFocused = newUnit.usesLoadValue
    }

    private func adjustDraftLoad(by delta: Double) {
        guard activeLoadUnit.usesLoadValue else { return }
        let currentValue = draftLoadValue ?? 0
        draftLoadValue = max(0, currentValue + delta)
    }

    private func save() {
        set.loadValue = draftLoadValue
        set.loadUnit = activeLoadUnit
        set.isCompleted = true
    }
}

private struct SheetHeader: View {
    let title: String
    let subtitle: String
    let close: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(.title2, design: .rounded).weight(.bold))

                    Text(subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.bold))
                        .frame(width: 40, height: 40)
                        .background(AppTheme.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}
