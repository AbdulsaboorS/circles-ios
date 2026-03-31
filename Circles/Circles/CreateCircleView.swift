import SwiftUI
import Supabase

// MARK: - Midnight Sanctuary tokens

private extension Color {
    static let msBackground  = Color(hex: "1A2E1E")
    static let msCardShared  = Color(hex: "243828")
    static let msGold        = Color(hex: "D4A240")
    static let msTextPrimary = Color(hex: "F0EAD6")
    static let msTextMuted   = Color(hex: "8FAF94")
    static let msBorder      = Color(hex: "D4A240").opacity(0.18)
}

struct CreateCircleView: View {
    @Environment(AuthManager.self) var auth
    @Environment(\.dismiss) var dismiss
    @Bindable var viewModel: CirclesViewModel

    @State private var name = ""
    @State private var description = ""
    @State private var genderSetting = "mixed"
    @State private var isCreating = false
    @State private var localError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.msBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Name
                        fieldSection(label: "Circle Name") {
                            TextField("e.g. Fajr Squad", text: $name)
                                .textInputAutocapitalization(.words)
                                .font(.appSubheadline)
                                .foregroundStyle(Color.msTextPrimary)
                                .padding(14)
                                .background(Color.msGold.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                                .tint(Color.msGold)
                        }

                        // Description
                        fieldSection(label: "Description (optional)") {
                            TextField("What's this circle about?", text: $description, axis: .vertical)
                                .textInputAutocapitalization(.sentences)
                                .font(.appSubheadline)
                                .foregroundStyle(Color.msTextPrimary)
                                .lineLimit(3...5)
                                .padding(14)
                                .background(Color.msGold.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                                .tint(Color.msGold)
                        }

                        // Gender Setting
                        fieldSection(label: "Circle Setting") {
                            HStack(spacing: 8) {
                                ForEach([("Mixed", "mixed"), ("Brothers", "brothers"), ("Sisters", "sisters")], id: \.1) { label, value in
                                    Button {
                                        genderSetting = value
                                    } label: {
                                        Text(label)
                                            .font(.appCaptionMedium)
                                            .foregroundStyle(genderSetting == value ? Color.msBackground : Color.msGold)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(
                                                genderSetting == value ? Color.msGold : Color.msGold.opacity(0.1),
                                                in: RoundedRectangle(cornerRadius: 10)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        if let error = localError {
                            Text(error)
                                .font(.appCaption)
                                .foregroundStyle(Color.red)
                                .multilineTextAlignment(.center)
                        }

                        Spacer(minLength: 20)

                        Button {
                            Task {
                                isCreating = true
                                localError = nil
                                viewModel.errorMessage = nil
                                guard let userId = auth.session?.user.id else {
                                    localError = "Not signed in."
                                    isCreating = false
                                    return
                                }
                                let result = await viewModel.createCircle(
                                    name: name.trimmingCharacters(in: .whitespaces),
                                    description: description.isEmpty ? nil : description,
                                    prayerTime: nil,
                                    userId: userId
                                )
                                if result != nil {
                                    dismiss()
                                } else {
                                    localError = viewModel.errorMessage ?? "Something went wrong. Try again."
                                }
                                isCreating = false
                            }
                        } label: {
                            ZStack {
                                if isCreating {
                                    ProgressView().tint(Color.msBackground)
                                } else {
                                    Text("Create Circle")
                                        .font(.appSubheadline.weight(.semibold))
                                        .foregroundStyle(Color.msBackground)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                name.trimmingCharacters(in: .whitespaces).isEmpty || isCreating
                                    ? Color.msGold.opacity(0.4)
                                    : Color.msGold
                            )
                            .clipShape(Capsule())
                        }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                        .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("New Circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.msGold)
                }
            }
        }
    }

    private func fieldSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.appCaption)
                .foregroundStyle(Color.msTextMuted)
                .textCase(.uppercase)
                .tracking(0.6)
            content()
        }
    }
}
