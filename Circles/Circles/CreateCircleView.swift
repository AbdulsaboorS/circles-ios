import SwiftUI
import Supabase

struct CreateCircleView: View {
    @Environment(AuthManager.self) var auth
    @Environment(\.dismiss) var dismiss
    @Bindable var viewModel: CirclesViewModel

    @State private var name = ""
    @State private var description = ""
    @State private var genderSetting = "mixed"
    @State private var isCreating = false
    @State private var localError: String?
    @Environment(\.colorScheme) private var colorScheme

    private var colors: AppColors { AppColors.resolve(colorScheme) }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        // Name
                        fieldSection(label: "Circle Name") {
                            TextField("e.g. Fajr Squad", text: $name)
                                .textInputAutocapitalization(.words)
                                .font(.appSubheadline)
                                .foregroundStyle(colors.textPrimary)
                                .padding(14)
                                .background(Color.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                                .tint(Color.accent)
                        }

                        // Description
                        fieldSection(label: "Description (optional)") {
                            TextField("What's this circle about?", text: $description, axis: .vertical)
                                .textInputAutocapitalization(.sentences)
                                .font(.appSubheadline)
                                .foregroundStyle(colors.textPrimary)
                                .lineLimit(3...5)
                                .padding(14)
                                .background(Color.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                                .tint(Color.accent)
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
                                            .foregroundStyle(genderSetting == value ? .white : Color.accent)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(
                                                genderSetting == value ? Color.accent : Color.accent.opacity(0.1),
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
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }

                        Spacer(minLength: 20)

                        PrimaryButton(title: "Create Circle", isLoading: isCreating) {
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
                        }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("New Circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.accent)
                }
            }
        }
    }

    private func fieldSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.appCaption)
                .foregroundStyle(colors.textSecondary)
                .textCase(.uppercase)
                .tracking(0.6)
            content()
        }
    }
}
