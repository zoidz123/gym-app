import SwiftUI

struct LogPreviousWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: WorkoutStore

    @State private var selectedDate: Date
    @State private var selectedTemplateID: UUID?
    @State private var selectedOccurrenceID: UUID?
    @State private var draftSession: WorkoutSession?

    init(
        initialDate: Date = Date(),
        initialTemplateID: UUID? = nil,
        initialOccurrenceID: UUID? = nil
    ) {
        _selectedDate = State(initialValue: initialDate)
        _selectedTemplateID = State(initialValue: initialTemplateID)
        _selectedOccurrenceID = State(initialValue: initialOccurrenceID)
    }

    var body: some View {
        NavigationStack {
            if draftSession != nil {
                ActiveWorkoutView(
                    session: draftBinding,
                    finishAccessibilityLabel: "Save previous workout",
                    discardConfirmationTitle: "Discard this log?",
                    discardButtonTitle: "Discard Log",
                    onFinish: saveDraft,
                    onDiscard: { dismiss() }
                )
                .navigationTitle("Log Previous")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                setupView
            }
        }
    }

    private var setupView: some View {
        Form {
            Section("Date") {
                DatePicker(
                    "Workout date",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
            }

            Section("Workout") {
                ForEach(store.data.templates) { template in
                    Button {
                        selectedTemplateID = template.id
                        selectedOccurrenceID = nil
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.ink)

                                Text("\(template.exercises.count) exercises")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }

                            Spacer()

                            if selectedTemplateID == template.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.success)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section {
                Button {
                    makeDraft()
                } label: {
                    Label("Continue", systemImage: "arrow.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(AppTheme.accent)
                .disabled(selectedTemplate == nil)
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Log Previous")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedTemplateID == nil, let status = store.nextUnloggedWeeklyStatus {
                selectedTemplateID = status.template.id
                selectedOccurrenceID = status.occurrence.id
            } else {
                selectedTemplateID = selectedTemplateID ?? selectedTemplate?.id
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Next") {
                    makeDraft()
                }
                .disabled(selectedTemplate == nil)
            }
        }
    }

    private var selectedTemplate: WorkoutTemplate? {
        if let selectedTemplateID,
           let template = store.data.templates.first(where: { $0.id == selectedTemplateID }) {
            return template
        }

        return store.nextUnloggedWeeklyTemplate ?? store.suggestedTemplate
    }

    private var draftBinding: Binding<WorkoutSession> {
        Binding(
            get: {
                draftSession ?? WorkoutSession(
                    date: selectedDate,
                    workoutName: "",
                    bodyweight: "",
                    duration: "",
                    notes: "",
                    isSeededHistory: false,
                    exercises: []
                )
            },
            set: { updatedSession in
                draftSession = updatedSession
            }
        )
    }

    private func makeDraft() {
        guard let selectedTemplate else { return }
        if let selectedOccurrenceID,
           let status = store.weeklyWorkoutStatuses.first(where: { $0.occurrence.id == selectedOccurrenceID }),
           status.template.id == selectedTemplate.id {
            draftSession = store.makeDraftSession(for: status, date: selectedDate)
        } else {
            draftSession = store.makeDraftSession(from: selectedTemplate, date: selectedDate)
        }
    }

    private func saveDraft() {
        guard let draftSession else { return }
        store.saveWorkoutSession(draftSession)
        dismiss()
    }
}
