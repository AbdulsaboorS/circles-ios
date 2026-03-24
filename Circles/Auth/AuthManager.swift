import Supabase
import Observation

@Observable
@MainActor
final class AuthManager {
    var session: Session? = nil
    var isLoading: Bool = true
    var authError: Error? = nil

    init() {
        Task { await listenToAuthChanges() }
    }

    var isAuthenticated: Bool { session != nil }

    private func listenToAuthChanges() async {
        for await (event, session) in await SupabaseService.shared.client.auth.authStateChanges {
            guard [.initialSession, .signedIn, .signedOut].contains(event) else { continue }
            self.session = session
            self.isLoading = false
        }
    }

    func signOut() async {
        do {
            try await SupabaseService.shared.client.auth.signOut()
        } catch {
            authError = error
        }
    }
}
