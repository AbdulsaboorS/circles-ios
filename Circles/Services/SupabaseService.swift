import Foundation
import Supabase

final class SupabaseService: @unchecked Sendable {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let urlString = dict["SUPABASE_URL"] as? String,
              let url = URL(string: urlString),
              let key = dict["SUPABASE_ANON_KEY"] as? String
        else {
            fatalError("Secrets.plist missing or malformed — add SUPABASE_URL and SUPABASE_ANON_KEY")
        }
        client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }
}
