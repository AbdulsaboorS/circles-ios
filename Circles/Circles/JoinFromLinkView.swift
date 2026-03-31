import SwiftUI

/// Thin wrapper that presents JoinCircleView with a pre-filled invite code.
/// Used when a returning (already-onboarded) user opens a circles://join/CODE deep link.
struct JoinFromLinkView: View {
    let inviteCode: String
    @Environment(AuthManager.self) private var auth

    @State private var viewModel = CirclesViewModel()

    var body: some View {
        JoinCircleView(viewModel: viewModel)
            .environment(auth)
            .onAppear {
                viewModel.pendingCode = inviteCode
            }
    }
}
