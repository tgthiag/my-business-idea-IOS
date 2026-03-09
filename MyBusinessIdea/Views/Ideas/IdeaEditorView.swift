import SwiftUI

struct IdeaEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    let title: String
    let primaryActionTitle: String
    let secondaryActionTitle: String
    let onSaveDraft: (IdeaEditorSeed) -> Void
    let onGenerate: (IdeaEditorSeed) async -> Void

    @State private var sourceDraftID: String?
    @State private var sourceIdeaID: Int?
    @State private var ideaTitle: String
    @State private var description: String
    @State private var investmentText: String
    @State private var currencyCode: String

    init(
        seed: IdeaEditorSeed,
        title: String,
        primaryActionTitle: String,
        secondaryActionTitle: String,
        onSaveDraft: @escaping (IdeaEditorSeed) -> Void,
        onGenerate: @escaping (IdeaEditorSeed) async -> Void
    ) {
        self.title = title
        self.primaryActionTitle = primaryActionTitle
        self.secondaryActionTitle = secondaryActionTitle
        self.onSaveDraft = onSaveDraft
        self.onGenerate = onGenerate
        _sourceDraftID = State(initialValue: seed.sourceDraftID)
        _sourceIdeaID = State(initialValue: seed.sourceIdeaID)
        _ideaTitle = State(initialValue: seed.title)
        _description = State(initialValue: seed.description)
        _investmentText = State(initialValue: seed.investment == 0 ? "" : "\(seed.investment)")
        _currencyCode = State(initialValue: CurrencySupport.normalize(seed.currencyCode))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                labeledField("Idea title") {
                    TextField("Language Learning App", text: $ideaTitle)
                }

                labeledField("Description") {
                    TextField("Describe the business idea", text: $description, axis: .vertical)
                        .lineLimit(6, reservesSpace: true)
                }

                labeledField("Investment") {
                    HStack {
                        TextField("Enter the investment amount", text: $investmentText)
                            .keyboardType(.numberPad)
                        Picker("Currency", selection: $currencyCode) {
                            ForEach(Locale.commonISOCurrencyCodes.sorted(), id: \.self) { code in
                                Text(code).tag(code)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Text("This draft is stored locally for your account.")
                    .font(.footnote)
                    .foregroundStyle(AppColors.inkMuted)
                    .appCard()

                if let globalError = appState.globalError {
                    InlineErrorCard(message: globalError)
                }

                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AppColors.border, lineWidth: 1)
                    )

                    Button(secondaryActionTitle) {
                        onSaveDraft(currentSeed)
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AppColors.border, lineWidth: 1)
                    )

                    Button(primaryActionTitle) {
                        Task {
                            await onGenerate(currentSeed)
                            dismiss()
                        }
                    }
                    .buttonStyle(AppGradientButtonStyle(disabled: appState.isGenerating || !canGenerate))
                    .disabled(appState.isGenerating || !canGenerate)
                }
            }
            .padding(20)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var currentSeed: IdeaEditorSeed {
        IdeaEditorSeed(
            sourceDraftID: sourceDraftID,
            sourceIdeaID: sourceIdeaID,
            title: ideaTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            investment: Int(investmentText) ?? 0,
            currencyCode: CurrencySupport.normalize(currencyCode)
        )
    }

    private var canGenerate: Bool {
        !ideaTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

