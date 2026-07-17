import SwiftUI
import UIKit

struct SetRowEditor: View {
    @Binding var set: LoggedSet
    let metric: SetMetricDescriptor
    let prefersLoad: Bool

    @State private var loadText = ""
    @State private var repsText = ""
    @State private var isEditingLoad = false
    @State private var isEditingReps = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if showsLoad {
                loadEditor
            } else {
                metricSummary
            }

            repsEditor
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(set.isCompleted ? AppTheme.successSoft : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onAppear(perform: synchronizeDrafts)
        .onChange(of: set.loadValue) {
            guard !isEditingLoad else { return }
            loadText = set.loadValue?.cleanString ?? ""
        }
        .onChange(of: set.repsValue) {
            guard !isEditingReps else { return }
            repsText = set.repsValue.map(String.init) ?? ""
        }
    }

    private var loadEditor: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if set.loadUnit.usesLoadValue {
                    fieldChrome(isFocused: isEditingLoad) {
                        InlineNumericField(
                            text: $loadText,
                            kind: .decimal,
                            fontStyle: .load,
                            placeholder: "0",
                            accessibilityLabel: set.loadUnit.isTime ? "Time" : "Weight",
                            onFocusChanged: { isEditingLoad = $0 },
                            onValueChanged: commitLoadText
                        )
                        .frame(width: 62, height: 44)
                    }
                } else {
                    Text(set.loadLabel)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 62, height: 44)
                        .lineLimit(1)
                }

                unitMenu
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !previousSummary.isEmpty {
                Text(previousSummary)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var unitMenu: some View {
        Menu {
            ForEach([LoadUnit.lb, .kg, .bodyweight, .seconds, .minutes]) { unit in
                Button {
                    changeUnit(to: unit)
                } label: {
                    if unit == set.loadUnit {
                        Label(unitMenuLabel(unit), systemImage: "checkmark")
                    } else {
                        Text(unitMenuLabel(unit))
                    }
                }
            }
        } label: {
            HStack(spacing: 2) {
                if set.loadUnit.usesLoadValue {
                    Text(set.loadUnit.label)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }

                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(AppTheme.textSecondary)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Change unit, currently \(set.loadUnit.label)")
    }

    private var metricSummary: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(metric.title)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(AppTheme.ink)

            Text(metricSupportingText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var repsEditor: some View {
        HStack(spacing: 0) {
            repAdjustmentButton(systemImage: "minus", label: "Decrease reps", isEnabled: (set.repsValue ?? 0) > 0) {
                set.adjustReps(by: -1)
                repsText = set.repsValue.map(String.init) ?? ""
            }

            fieldChrome(isFocused: isEditingReps) {
                VStack(spacing: -1) {
                    InlineNumericField(
                        text: $repsText,
                        kind: .integer,
                        fontStyle: .reps,
                        placeholder: "0",
                        accessibilityLabel: "Reps",
                        onFocusChanged: { isEditingReps = $0 },
                        onValueChanged: commitRepsText
                    )
                    .frame(width: 52, height: metricCaption == nil ? 44 : 30)

                    if let metricCaption {
                        Text(metricCaption)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
                .frame(width: 52, height: 44)
            }

            repAdjustmentButton(systemImage: "plus", label: "Increase reps") {
                set.adjustReps(by: 1)
                repsText = set.repsValue.map(String.init) ?? ""
            }
        }
        .frame(width: 140)
    }

    private var showsLoad: Bool {
        prefersLoad || set.loadUnit != .custom
    }

    private var previousSummary: String {
        guard !set.previousLoadText.isEmpty || !set.previousRepsText.isEmpty else {
            return ""
        }

        if showsLoad {
            return "Last \(set.previousLabel)"
        }

        return "Last \(set.previousRepsText) \(metric.unitLabel)"
    }

    private var metricSupportingText: String {
        previousSummary.isEmpty ? metric.target : previousSummary
    }

    private var metricCaption: String? {
        showsLoad ? nil : metric.unitLabel
    }

    private func fieldChrome<Content: View>(
        isFocused: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isFocused ? AppTheme.accentSoft : AppTheme.surface.opacity(0.82))
                    .frame(height: 38)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(isFocused ? AppTheme.accent : AppTheme.chipBorder, lineWidth: isFocused ? 1.5 : 1)
                    .frame(height: 38)
            }
    }

    private func repAdjustmentButton(
        systemImage: String,
        label: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .frame(width: 28, height: 28)
                .background(AppTheme.surface.opacity(0.72))
                .clipShape(Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isEnabled ? AppTheme.accent : AppTheme.textTertiary)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }

    private func synchronizeDrafts() {
        loadText = set.loadValue?.cleanString ?? ""
        repsText = set.repsValue.map(String.init) ?? ""
    }

    private func commitLoadText(_ text: String) {
        switch SetEntryValueParser.load(from: text) {
        case .empty:
            set.loadValue = nil
            set.isCompleted = true
        case .value(let value):
            set.loadValue = value
            set.isCompleted = true
        case .invalid:
            break
        }
    }

    private func commitRepsText(_ text: String) {
        switch SetEntryValueParser.reps(from: text) {
        case .empty:
            set.repsValue = nil
            set.isCompleted = true
        case .value(let value):
            set.repsValue = value
            set.isCompleted = true
        case .invalid:
            break
        }
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
        loadText = set.loadValue?.cleanString ?? ""
    }

    private func unitMenuLabel(_ unit: LoadUnit) -> String {
        unit.isTime ? unit.label : unit.entryPickerLabel
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

enum ParsedSetEntry<Value: Equatable>: Equatable {
    case empty
    case value(Value)
    case invalid
}

enum SetEntryValueParser {
    static func reps(from text: String) -> ParsedSetEntry<Int> {
        guard !text.isEmpty else { return .empty }
        guard text.allSatisfy(\.isNumber), let value = Int(text) else { return .invalid }
        return .value(value)
    }

    static func load(from text: String) -> ParsedSetEntry<Double> {
        guard !text.isEmpty else { return .empty }
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value.isFinite, value >= 0 else { return .invalid }
        return .value(value)
    }

    static func isValidDraft(_ text: String, for kind: InlineNumericField.Kind) -> Bool {
        guard !text.isEmpty else { return true }

        switch kind {
        case .integer:
            return text.allSatisfy(\.isNumber)
        case .decimal:
            let separators = text.filter { $0 == "." || $0 == "," }
            return separators.count <= 1 && text.allSatisfy { $0.isNumber || $0 == "." || $0 == "," }
        }
    }
}

struct InlineNumericField: UIViewRepresentable {
    enum Kind {
        case integer
        case decimal
    }

    enum FontStyle {
        case load
        case reps

        var font: UIFont {
            let size: CGFloat = self == .load ? 24 : 27
            var font = UIFont.monospacedDigitSystemFont(ofSize: size, weight: .bold)
            if let rounded = font.fontDescriptor.withDesign(.rounded) {
                font = UIFont(descriptor: rounded, size: size)
            }
            let textStyle: UIFont.TextStyle = self == .load ? .title3 : .title1
            return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: font)
        }
    }

    @Binding var text: String
    let kind: Kind
    let fontStyle: FontStyle
    let placeholder: String
    let accessibilityLabel: String
    let onFocusChanged: (Bool) -> Void
    let onValueChanged: (String) -> Void

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.keyboardType = kind == .integer ? .numberPad : .decimalPad
        field.textAlignment = .center
        field.attributedPlaceholder = styledPlaceholder
        field.font = fontStyle.font
        field.adjustsFontForContentSizeCategory = true
        field.adjustsFontSizeToFitWidth = true
        field.minimumFontSize = 16
        field.accessibilityLabel = accessibilityLabel
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        field.inputAccessoryView = context.coordinator.makeAccessoryView()
        context.coordinator.field = field
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        field.keyboardType = kind == .integer ? .numberPad : .decimalPad
        field.font = fontStyle.font
        field.accessibilityLabel = accessibilityLabel
        field.attributedPlaceholder = styledPlaceholder
        context.coordinator.accessoryLabel?.text = accessibilityLabel

        if field.text != text {
            field.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private var styledPlaceholder: NSAttributedString {
        NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.secondaryLabel]
        )
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: InlineNumericField
        weak var field: UITextField?
        weak var accessoryLabel: UILabel?

        init(parent: InlineNumericField) {
            self.parent = parent
        }

        func makeAccessoryView() -> UIView {
            let accessory = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 40))
            accessory.backgroundColor = .secondarySystemBackground
            accessory.autoresizingMask = [.flexibleWidth]

            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .preferredFont(forTextStyle: .caption1)
            label.textColor = .secondaryLabel
            label.text = parent.accessibilityLabel
            label.adjustsFontForContentSizeCategory = true
            accessory.addSubview(label)
            accessoryLabel = label

            let doneButton = UIButton(type: .system)
            doneButton.translatesAutoresizingMaskIntoConstraints = false
            doneButton.setTitle("Done", for: .normal)
            doneButton.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
            doneButton.titleLabel?.adjustsFontForContentSizeCategory = true
            doneButton.tintColor = UIColor(red: 1.0, green: 0.22, blue: 0.36, alpha: 1)
            doneButton.addTarget(self, action: #selector(done), for: .touchUpInside)
            doneButton.accessibilityLabel = "Done editing \(parent.accessibilityLabel.lowercased())"
            accessory.addSubview(doneButton)

            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: accessory.leadingAnchor, constant: 16),
                label.centerYAnchor.constraint(equalTo: accessory.centerYAnchor),
                doneButton.trailingAnchor.constraint(equalTo: accessory.trailingAnchor, constant: -12),
                doneButton.centerYAnchor.constraint(equalTo: accessory.centerYAnchor),
                doneButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 52),
                doneButton.heightAnchor.constraint(equalToConstant: 40)
            ])

            return accessory
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.onFocusChanged(true)
            DispatchQueue.main.async {
                textField.selectAll(nil)
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.onFocusChanged(false)
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            guard let current = textField.text,
                  let swiftRange = Range(range, in: current) else {
                return false
            }

            let candidate = current.replacingCharacters(in: swiftRange, with: string)
            return SetEntryValueParser.isValidDraft(candidate, for: parent.kind)
        }

        @objc func textChanged(_ field: UITextField) {
            let value = field.text ?? ""
            parent.text = value
            parent.onValueChanged(value)
        }

        @objc private func done() {
            field?.resignFirstResponder()
        }
    }
}

// Historical workout editing remains a deliberate secondary flow. Active
// workout rows never present these sheets.
struct SetRepsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var set: LoggedSet
    let metric: SetMetricDescriptor
    @State private var repsText = ""

    var body: some View {
        VStack(spacing: 16) {
            SheetHeader(title: metric.title, subtitle: repsSubtitle) {
                dismiss()
            }

            ImmediateKeypadField(text: $repsText, keyboardType: .numberPad)
                .fixedSize(horizontal: false, vertical: true)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.screenBackground)
        .onAppear {
            repsText = set.repsValue.map(String.init) ?? ""
        }
    }

    private func save() {
        switch SetEntryValueParser.reps(from: repsText) {
        case .empty:
            set.repsValue = nil
            set.isCompleted = true
        case .value(let value):
            set.repsValue = value
            set.isCompleted = true
        case .invalid:
            break
        }
    }

    private var repsSubtitle: String {
        let last = set.previousRepsText.isEmpty ? "-" : set.previousRepsText
        return metric.unitLabel == "reps" ? "last \(last)" : "last \(last) \(metric.unitLabel)"
    }
}

struct SetWeightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var set: LoggedSet
    @State private var draftLoadValue: Double?
    @State private var draftLoadUnit: LoadUnit?

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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.screenBackground)
        .onAppear {
            draftLoadValue = set.loadValue
            draftLoadUnit = set.loadUnit
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
                    ImmediateKeypadField(text: loadTextBinding, keyboardType: .decimalPad)
                        .fixedSize(horizontal: false, vertical: true)
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

                return activeLoadUnit == .minutes ? .seconds : activeLoadUnit
            },
            set: changeUnit
        )
    }

    private var timeUnitBinding: Binding<LoadUnit> {
        Binding(
            get: { activeLoadUnit == .minutes ? .minutes : .seconds },
            set: changeUnit
        )
    }

    private var loadTextBinding: Binding<String> {
        Binding(
            get: { draftLoadValue?.cleanString ?? "" },
            set: { value in
                switch SetEntryValueParser.load(from: value) {
                case .empty:
                    draftLoadValue = nil
                case .value(let parsed):
                    draftLoadValue = parsed
                case .invalid:
                    break
                }
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
    }

    private func adjustDraftLoad(by delta: Double) {
        guard activeLoadUnit.usesLoadValue else { return }
        draftLoadValue = max(0, (draftLoadValue ?? 0) + delta)
    }

    private func save() {
        set.loadValue = draftLoadValue
        set.loadUnit = activeLoadUnit
        set.isCompleted = true
    }
}

private struct ImmediateKeypadField: UIViewRepresentable {
    @Binding var text: String
    let keyboardType: UIKeyboardType

    func makeUIView(context: Context) -> AutoFocusTextField {
        let field = AutoFocusTextField()
        field.keyboardType = keyboardType
        field.textAlignment = .center
        field.placeholder = "0"
        field.adjustsFontSizeToFitWidth = true
        field.minimumFontSize = 30

        var font = UIFont.monospacedDigitSystemFont(ofSize: 58, weight: .bold)
        if let rounded = font.fontDescriptor.withDesign(.rounded) {
            font = UIFont(descriptor: rounded, size: 58)
        }
        field.font = font
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        return field
    }

    func updateUIView(_ field: AutoFocusTextField, context: Context) {
        if field.text != text {
            field.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject {
        private let text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        @objc func textChanged(_ field: UITextField) {
            text.wrappedValue = field.text ?? ""
        }
    }
}

private final class AutoFocusTextField: UITextField {
    private var hasAutoFocused = false

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if window != nil && !hasAutoFocused {
            hasAutoFocused = true
            becomeFirstResponder()
        }
    }
}

private struct SheetHeader: View {
    let title: String
    let subtitle: String
    let close: () -> Void

    var body: some View {
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
