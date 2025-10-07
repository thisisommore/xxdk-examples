import SwiftUI

@MainActor
public struct PasswordCreationView: View {
    @State private var password: String = ""
    @State private var confirm: String = ""
    @State private var attemptedSubmit: Bool = false
    @FocusState private var focusedField: Field?

    public init() {}

    // MARK: - Focus
    private enum Field { case password, confirm }

    // MARK: - Rules
    private enum PasswordRule: CaseIterable {
        case length, upper, lower, digit, symbol

        var label: String {
            switch self {
            case .length: return "At least 8 characters"
            case .upper:  return "Contains an uppercase letter"
            case .lower:  return "Contains a lowercase letter"
            case .digit:  return "Contains a number"
            case .symbol: return "Contains a symbol (!@#$…)"
            }
        }

        func isSatisfied(by s: String) -> Bool {
            switch self {
            case .length: return s.count >= 8
            case .upper:  return s.range(of: "[A-Z]", options: .regularExpression) != nil
            case .lower:  return s.range(of: "[a-z]", options: .regularExpression) != nil
            case .digit:  return s.range(of: "[0-9]", options: .regularExpression) != nil
            case .symbol: return s.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
            }
        }
    }

    private var failingRules: [PasswordRule] {
        PasswordRule.allCases.filter { !$0.isSatisfied(by: password) }
    }
    private var passwordsMatch: Bool { !password.isEmpty && password == confirm }
    private var canContinue: Bool { password.count >= 1 && passwordsMatch }

    private var strength: Double {
        let satisfied = Double(PasswordRule.allCases.count - failingRules.count)
        return max(0, min(1, satisfied / Double(PasswordRule.allCases.count)))
    }
    
    private var strengthColor: Color {
        switch strength {
        case ..<0.4: return BranchColor.primary.opacity(0.4)
        case ..<0.8: return BranchColor.primary.opacity(0.7)
        default:      return BranchColor.primary
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Join the alpha").font(.title2).bold()
                    Text("Enter a password to secure your Haven identity")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Fields with clear affordance
                VStack(spacing: 14) {
                    LabeledSecureField(
                        title: "New password",
                        text: $password,
                        isInvalid: attemptedSubmit && password.isEmpty,
                        isFocused: focusedField == .password
                    )
                    .focused($focusedField, equals: .password)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .confirm }

                    LabeledSecureField(
                        title: "Confirm password",
                        text: $confirm,
                        isInvalid: attemptedSubmit && !passwordsMatch,
                        isFocused: focusedField == .confirm
                    )
                    .focused($focusedField, equals: .confirm)
                    .submitLabel(.continue)
                    .onSubmit { handleSubmit() }
                }

                
                // Inline validation
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password recommendation")
                    ForEach(PasswordRule.allCases, id: \.self) { rule in
                        let ok = rule.isSatisfied(by: password)
                        HStack(spacing: 8) {
                            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(ok ? BranchColor.primary : .secondary)
                            Text(rule.label)
                                .foregroundStyle(ok ? .primary : .secondary)
                                .strikethrough(ok, color: .secondary)
                                .accessibilityLabel("\(rule.label) \(ok ? "satisfied" : "not satisfied")")
                        }
                        .font(.footnote)
                    }

                    if !confirm.isEmpty || attemptedSubmit {
                        HStack(spacing: 8) {
                            Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(passwordsMatch ? BranchColor.primary : .orange)
                            Text(passwordsMatch ? "Passwords match" : "Passwords don't match")
                        }
                        .font(.footnote)
                    }

                    // Strength
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: strength)
                            .tint(strengthColor)
                        Text("Strength: \(strengthLabel(for: strength))")
                            .font(.caption)
                            .foregroundStyle(strengthColor)
                    }
                    .opacity(password.isEmpty ? 0 : 1)
                    .animation(.easeInOut, value: password)
                }

                // Primary action
                Button(action: handleSubmit) {
                    Text("Continue").bold()
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)
                }
                .buttonStyle(BranchButtonStyle(isEnabled: canContinue))
                .disabled(!canContinue)
                .privacySensitive()
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .privacySensitive()
    }

    // MARK: - Actions
    private func handleSubmit() {
        attemptedSubmit = true
        guard canContinue else { return }
        // onSubmit(password)
    }

    // MARK: - Helpers
    private func strengthLabel(for value: Double) -> String {
        switch value {
        case ..<0.4: return "Weak"
        case ..<0.8: return "Okay"
        default:      return "Strong"
        }
    }
}

// MARK: - Branch Color Palette
private enum BranchColor {
    static let primary = Color.haven
    static let disabled = Color(red: 236/255, green: 186/255, blue: 96/255).opacity(0.5)
    static let light = Color(red: 246/255, green: 206/255, blue: 136/255)
}

// MARK: - Custom Button Style
private struct BranchButtonStyle: ButtonStyle {
    let isEnabled: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isEnabled ? BranchColor.primary : .gray.opacity(0.4))
                    .animation(.easeInOut(duration: 0.3), value: isEnabled)
            )
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Reusable field with clear affordance
private struct LabeledSecureField: View {
    let title: String
    @Binding var text: String
    var isInvalid: Bool
    var isFocused: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(isFocused ? BranchColor.primary : .secondary)

            HStack {
                Group {
                    SecureField("-", text: $text)
                        .textContentType(.newPassword)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .keyboardType(.asciiCapable)
                }
                .privacySensitive()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isInvalid ? Color.red : (isFocused ? BranchColor.primary : (text.isEmpty ? .clear : .separator)),
                        lineWidth: isFocused ? 1.5 : 1
                    )
            )
        }
    }
}

private extension Color {
    static let separator = Color(UIColor.separator)
}

#Preview {
    PasswordCreationView()
}
