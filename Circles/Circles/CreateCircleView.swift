import SwiftUI
import Supabase

struct CreateCircleView: View {
    @Environment(AuthManager.self) var auth
    @Environment(\.dismiss) var dismiss
    @Bindable var viewModel: CirclesViewModel

    @State private var name = ""
    @State private var description = ""
    @State private var isCreating = false
    @State private var localError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0D1021").ignoresSafeArea()

                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        // Name field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Circle Name")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                                .textCase(.uppercase)
                                .tracking(0.8)

                            TextField("e.g. Ramadan Squad", text: $name)
                                .textInputAutocapitalization(.words)
                                .foregroundStyle(.white)
                                .padding(14)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .tint(Color(hex: "E8834B"))
                                .colorScheme(.dark)
                        }

                        // Description field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Description (optional)")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                                .textCase(.uppercase)
                                .tracking(0.8)

                            TextField("What's this circle about?", text: $description, axis: .vertical)
                                .textInputAutocapitalization(.sentences)
                                .foregroundStyle(.white)
                                .lineLimit(3...5)
                                .padding(14)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .tint(Color(hex: "E8834B"))
                                .colorScheme(.dark)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    if let error = localError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    Spacer()

                    // Create button
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
                                ProgressView().tint(.white)
                            } else {
                                Text("Create Circle")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            name.trimmingCharacters(in: .whitespaces).isEmpty || isCreating
                                ? Color(hex: "E8834B").opacity(0.4)
                                : Color(hex: "E8834B")
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("New Circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0D1021"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color(hex: "E8834B"))
                }
            }
        }
    }
}
