import Foundation

// MARK: - Groq errors

enum GroqError: LocalizedError {
    case httpError(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .httpError(let code, let body):
            switch code {
            case 401: return "Groq API key rejected (401). Check GROQ_API_KEY in Secrets.plist."
            case 404: return "Groq model not found (404). Model id may have changed — check GroqService."
            case 429: return "Groq rate limit hit (429). Please wait a moment and try again."
            case 503: return "Groq is temporarily unavailable (503). Please try again."
            default:
                let preview = body.prefix(200)
                return "Groq returned HTTP \(code): \(preview)"
            }
        }
    }
}

/// Low-latency LLM provider used for the two onboarding paths where Gemini's
/// 5–15 s cold latency was costing us users. Roadmap generation stays on
/// `GeminiService` because the long output favors Gemini and isn't latency-critical.
///
/// API surface intentionally mirrors `GeminiService` for the suggestion + rationale
/// methods so coordinators only need a one-line swap.
final class GroqService {
    static let shared = GroqService()
    private let apiKey: String
    private let endpoint = "https://api.groq.com/openai/v1/chat/completions"
    /// Llama 3.3 70B Versatile — Groq's current production-grade general model.
    /// Strong enough for short structured JSON; sub-second cold response in practice.
    private let model = "llama-3.3-70b-versatile"

    /// Tighter than Gemini's 45 s — Groq replies in well under a second normally,
    /// so anything past 8 s is almost certainly a real failure, not a cold network.
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 12
        return URLSession(configuration: config)
    }()

    private init() {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let key = dict["GROQ_API_KEY"] as? String, !key.isEmpty else {
            fatalError("GroqService: GROQ_API_KEY missing or empty in Secrets.plist")
        }
        self.apiKey = key
    }

    // MARK: - Habit suggestions (Quiz screen D)

    func generateHabitSuggestions(
        islamicStruggles: [String],
        lifeStruggles: [String]
    ) async throws -> [HabitSuggestion] {
        let formatSlug: (String) -> String = { slug in
            let stripped = slug.hasPrefix("custom:") ? String(slug.dropFirst("custom:".count)) : slug
            return "- \(stripped.replacingOccurrences(of: "_", with: " "))"
        }
        let islamicList = islamicStruggles.map(formatSlug).joined(separator: "\n")
        let lifeList    = lifeStruggles.map(formatSlug).joined(separator: "\n")

        let prompt = """
        You are a knowledgeable, gentle Islamic habits coach. Suggest a small number of
        practical, daily habits that answer the user's stated struggles. Keep each habit
        small enough to do in under 10 minutes most days.

        Islamic struggles the user chose:
        \(islamicList.isEmpty ? "(none)" : islamicList)

        Life struggles the user chose:
        \(lifeList.isEmpty ? "(none)" : lifeList)

        Return ONLY valid JSON with this exact shape:
        {"suggestions":[{"name":"short habit name","rationale":"one gentle sentence explaining why it fits"}]}
        Requirements:
        - Between 4 and 6 objects in "suggestions".
        - Habit names under 40 characters, sentence case (e.g. "Fajr on time").
        - Rationales under 140 characters, first-person friendly tone, Muslim-appropriate language.
        - Never recommend anything that contradicts Islamic teachings.
        """

        struct Envelope: Decodable {
            let suggestions: [HabitSuggestion]
        }

        let envelope: Envelope = try await chatJSON(prompt: prompt, maxTokens: 500)
        guard !envelope.suggestions.isEmpty else { throw URLError(.cannotParseResponse) }
        return Array(envelope.suggestions.prefix(6))
    }

    // MARK: - Habit rationales (Amir step 2 tiles)

    func generateHabitRationales(
        habits: [String],
        spiritualityLevel: String?,
        timeCommitment: String?,
        heartOfCircle: String?
    ) async throws -> [String: String] {
        let habitList = habits.map { "- \($0)" }.joined(separator: "\n")
        let spirit = spiritualityLevel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let time   = timeCommitment?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let heart  = heartOfCircle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let prompt = """
        You are a knowledgeable, gentle Islamic habits coach. The user has already
        chosen a fixed set of habits for their small accountability circle. Write
        ONE short rationale per habit, explaining why this habit fits *this user's*
        answers below. Use the habit name verbatim — do not rename, translate, or
        substitute habits.

        User's spiritual level: \(spirit.isEmpty ? "(not specified)" : spirit)
        Time they can commit daily: \(time.isEmpty ? "(not specified)" : time)
        What their circle is rooted in: \(heart.isEmpty ? "(not specified)" : heart)

        Habits to rationalize (use these exact names):
        \(habitList)

        Return ONLY valid JSON with this exact shape:
        {"rationales":[{"name":"<exact habit name>","rationale":"one gentle sentence"}]}
        Requirements:
        - One object per habit, in the same order as listed above.
        - Each "name" must match one of the habits above exactly (case-sensitive).
        - Each "rationale" under 140 characters, first-person friendly tone, Muslim-appropriate.
        - Never recommend anything that contradicts Islamic teachings.
        """

        struct RationaleItem: Decodable {
            let name: String
            let rationale: String
        }
        struct Envelope: Decodable {
            let rationales: [RationaleItem]
        }

        let envelope: Envelope = try await chatJSON(prompt: prompt, maxTokens: 500)
        let requested = Set(habits)
        var dict: [String: String] = [:]
        for item in envelope.rationales where requested.contains(item.name) {
            dict[item.name] = item.rationale
        }
        guard !dict.isEmpty else { throw URLError(.cannotParseResponse) }
        return dict
    }

    // MARK: - Shared chat-completion JSON-mode call

    /// Sends a single user-message prompt with `response_format: json_object` so Groq
    /// guarantees parseable JSON (no markdown-fence stripping needed). Decodes the
    /// `choices[0].message.content` string into `T`.
    private func chatJSON<T: Decodable>(prompt: String, maxTokens: Int) async throws -> T {
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.7,
            "max_tokens": maxTokens
        ]

        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await Self.session.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? "(no body)"
            throw GroqError.httpError(statusCode: http.statusCode, body: body)
        }

        let chat = try JSONDecoder().decode(GroqChatResponse.self, from: data)
        guard let content = chat.choices.first?.message.content,
              let payload = content.data(using: .utf8) else {
            throw URLError(.cannotParseResponse)
        }
        return try JSONDecoder().decode(T.self, from: payload)
    }
}

private struct GroqChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String }
        let message: Message
    }
    let choices: [Choice]
}
