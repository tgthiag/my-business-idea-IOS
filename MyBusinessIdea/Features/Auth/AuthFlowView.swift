import SwiftUI

struct AuthFlowView: View {
    @EnvironmentObject private var appState: AppState

    @State private var mode: AuthMode = .login
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var birthDate = Date()
    @State private var selectedQuestionID = SecurityQuestion.all.first?.id ?? "pet_name"
    @State private var securityAnswer = ""
    @State private var showRecoverySheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                authModePicker
                authForm

                if let authError = appState.authError {
                    InlineErrorCard(message: authError)
                }

                PrimaryActionButton(
                    title: appState.isAuthenticating
                        ? "Please wait…"
                        : (mode == .login ? "Sign in" : "Create account"),
                    disabled: appState.isAuthenticating || !canSubmit
                ) {
                    Task {
                        await appState.authenticate(
                            mode: mode,
                            name: name,
                            email: email,
                            password: password,
                            birthDate: birthDate.formattedBirthDate(),
                            securityQuestionID: selectedQuestionID,
                            securityAnswer: securityAnswer
                        )
                    }
                }

                Text("Build your business idea with more clarity.")
                    .font(.footnote)
                    .foregroundStyle(AppColors.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(24)
        }
        .background(AppColors.background.ignoresSafeArea())
        .sheet(isPresented: $showRecoverySheet) {
            PasswordRecoverySheet()
                .environmentObject(appState)
        }
    }

    private var canSubmit: Bool {
        let base = !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !password.isEmpty
        if mode == .login { return base }
        return base &&
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !securityAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var header: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColors.mutedSurface)
                .frame(width: 58, height: 58)
                .overlay(
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(AppColors.accentStart)
                        .font(.title2)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text("My Business Idea")
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppColors.ink)
                Text("Turn ideas into action")
                    .foregroundStyle(AppColors.inkMuted)
            }
        }
    }

    private var authModePicker: some View {
        Picker("Mode", selection: $mode) {
            Text("Sign in").tag(AuthMode.login)
            Text("Register").tag(AuthMode.register)
        }
        .pickerStyle(.segmented)
    }

    private var authForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            if mode == .register {
                Group {
                    labeledField("Name") {
                        TextField("Enter your name", text: $name)
                            .textInputAutocapitalization(.words)
                    }
                    labeledField("Birth date") {
                        DatePicker("", selection: $birthDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                    labeledField("Security question") {
                        Picker("Question", selection: $selectedQuestionID) {
                            ForEach(SecurityQuestion.all) { question in
                                Text(question.title).tag(question.id)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    labeledField("Security answer") {
                        TextField("Type your answer", text: $securityAnswer)
                    }
                    Text("Use a short answer you will remember.")
                        .font(.footnote)
                        .foregroundStyle(AppColors.inkMuted)
                }
            }

            labeledField("Email") {
                TextField("Enter your email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            labeledField("Password") {
                SecureField("Enter your password", text: $password)
            }

            if mode == .login {
                Button("Forgot password?") {
                    appState.resetRecoveryFlow(prefilledEmail: email)
                    showRecoverySheet = true
                }
                .font(.footnote.weight(.semibold))
            }
        }
        .appCard()
    }
}

private struct PasswordRecoverySheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var recoveryBirthDate = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Recover password")
                        .font(.largeTitle.bold())
                    Text("Confirm your identity, answer the security question, and set a new password.")
                        .foregroundStyle(AppColors.inkMuted)

                    switch appState.recovery.step {
                    case .identify:
                        VStack(alignment: .leading, spacing: 14) {
                            labeledField("Email") {
                                TextField("Registered email", text: $appState.recovery.email)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                            labeledField("Birth date") {
                                DatePicker("", selection: $recoveryBirthDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                    .onChange(of: recoveryBirthDate) { _, newValue in
                                        appState.recovery.birthDate = newValue.formattedBirthDate()
                                    }
                            }
                        }
                        .appCard()

                    case .question:
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Security question")
                                .font(.headline)
                            Text(appState.recovery.questionText ?? "")
                                .foregroundStyle(AppColors.ink)
                            labeledField("Answer") {
                                TextField("Type your answer", text: $appState.recovery.answer)
                            }
                            Text("Use the same normalized answer used during registration.")
                                .font(.footnote)
                                .foregroundStyle(AppColors.inkMuted)
                        }
                        .appCard()

                    case .reset:
                        VStack(alignment: .leading, spacing: 14) {
                            labeledField("New password") {
                                SecureField("New password", text: $appState.recovery.newPassword)
                            }
                            labeledField("Confirm new password") {
                                SecureField("Confirm new password", text: $appState.recovery.confirmPassword)
                            }
                        }
                        .appCard()

                    case .done:
                        EmptyStateCard(
                            title: "Password updated",
                            subtitle: appState.recovery.message ?? "You can close this dialog and sign in with the new password."
                        )
                    }

                    if let message = appState.recovery.message, appState.recovery.step != .done {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.accentStart)
                    }
                    if let error = appState.recovery.error {
                        InlineErrorCard(message: error)
                    }

                    HStack(spacing: 12) {
                        Button("Close") {
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

                        PrimaryActionButton(title: buttonTitle) {
                            Task {
                                switch appState.recovery.step {
                                case .identify:
                                    await appState.startRecovery()
                                case .question:
                                    await appState.verifyRecovery()
                                case .reset:
                                    await appState.resetRecovery()
                                case .done:
                                    dismiss()
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Recovery")
            .onAppear {
                if !appState.recovery.birthDate.isEmpty,
                   let parsed = ISO8601DateFormatter.shortDate.date(from: appState.recovery.birthDate) {
                    recoveryBirthDate = parsed
                } else {
                    appState.recovery.birthDate = recoveryBirthDate.formattedBirthDate()
                }
            }
        }
    }

    private var buttonTitle: String {
        switch appState.recovery.step {
        case .identify: return "Continue"
        case .question: return "Confirm"
        case .reset: return "Save password"
        case .done: return "Close"
        }
    }
}

private func labeledField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppColors.ink)
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 1)
            )
    }
}

