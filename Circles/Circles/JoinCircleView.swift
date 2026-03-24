import SwiftUI
import Supabase

struct JoinCircleView: View {
    @Environment(AuthManager.self) var auth
    @Environment(\.dismiss) var dismiss
    @Bindable var viewModel: CirclesViewModel

    @State private var inviteCode = ""
    @State private var isJoining = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0D1021").ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter Invite Code")
                            .font(.system(.title3, design: .serif, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Ask a circle member for their 8-character invite code.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("ABCD1234", text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled(true)
                        .font(.system(.title2, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding()
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onChange(of: inviteCode) { _, val in
                            inviteCode = String(val.uppercased().prefix(8))
                        }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Join Circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0D1021"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color(hex: "E8834B"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Join") {
                        Task {
                            isJoining = true
                            viewModel.errorMessage = nil
                            if let userId = auth.session?.user.id {
                                let result = await viewModel.joinCircle(
                                    code: inviteCode.trimmingCharacters(in: .whitespaces),
                                    userId: userId
                                )
                                if result != nil { dismiss() }
                            }
                            isJoining = false
                        }
                    }
                    .foregroundStyle(Color(hex: "E8834B"))
                    .disabled(inviteCode.trimmingCharacters(in: .whitespaces).count < 8 || isJoining)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let code = viewModel.pendingCode {
                    inviteCode = code
                    viewModel.pendingCode = nil
                }
            }
        }
    }
}
