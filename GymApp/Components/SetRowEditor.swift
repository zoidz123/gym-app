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
        .onTapGesture {
            set.isCompleted.toggle()
        }
        .sheet(isPresented: $isEditingWeight) {
            SetWeightSheet(set: $set)
                .presentationDetents([.height(360), .medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isEditingReps) {
            SetRepsSheet(set: $set, metric: metric)
                .presentationDetents([.height(250)])
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
            return "Weight"
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
            isFocused = true
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
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            SheetHeader(title: "Weight", subtitle: "last \(set.previousLabel)") {
                dismiss()
            }

            Picker("Unit", selection: unitBinding) {
                ForEach([LoadUnit.lb, .kg, .bodyweight, .machine]) { unit in
                    Text(unit.label).tag(unit)
                }
            }
            .pickerStyle(.segmented)

            weightEditor

            if set.previousLoadValue != nil || !set.previousLoadText.isEmpty {
                Button {
                    set.loadValue = set.previousLoadValue
                    set.loadUnit = set.previousLoadUnit ?? set.loadUnit
                    set.isCompleted = true
                } label: {
                    Label("Use Last Weight", systemImage: "arrow.uturn.backward")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Button {
                set.isCompleted = true
                dismiss()
            } label: {
                Text("Save Weight")
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
            isFocused = set.loadUnit.usesLoadValue
        }
    }

    private var weightEditor: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.surface)

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.chipBorder, lineWidth: 1)

                if set.loadUnit == .bodyweight {
                    Text("Bodyweight")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                } else {
                    TextField("Weight", text: loadTextBinding, prompt: Text("0"))
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
                    set.adjustLoad(by: -set.loadUnit.defaultStep)
                } label: {
                    Image(systemName: "minus")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.bordered)
                .disabled(!set.loadUnit.usesLoadValue)

                Button {
                    set.adjustLoad(by: set.loadUnit.defaultStep)
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.bordered)
                .disabled(!set.loadUnit.usesLoadValue)
            }
        }
    }

    private var unitBinding: Binding<LoadUnit> {
        Binding(
            get: { set.loadUnit == .custom ? .lb : set.loadUnit },
            set: { newUnit in
                changeUnit(to: newUnit)
            }
        )
    }

    private var loadTextBinding: Binding<String> {
        Binding(
            get: { set.loadValue?.cleanString ?? "" },
            set: { value in
                set.loadValue = Double(value)
                set.isCompleted = true
            }
        )
    }

    private func changeUnit(to newUnit: LoadUnit) {
        let oldUnit = set.loadUnit

        if let value = set.loadValue {
            if oldUnit == .lb && newUnit == .kg {
                set.loadValue = (value * 0.45359237 * 10).rounded() / 10
            } else if oldUnit == .kg && newUnit == .lb {
                set.loadValue = (value * 2.20462262).rounded()
            } else if !newUnit.usesLoadValue {
                set.loadValue = nil
            }
        }

        if newUnit.usesLoadValue && set.loadValue == nil {
            set.loadValue = 0
        }

        set.loadUnit = newUnit
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
