import Foundation

struct AISuggestion: Codable {
    let suggestedAmount: String
    let motivation: String
    let tip: String

    enum CodingKeys: String, CodingKey {
        case suggestedAmount = "suggestedAmount"
        case motivation
        case tip
    }
}

final class GeminiService {
    static let shared = GeminiService()
    private let apiKey: String
    private let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent"

    private init() {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let key = dict["GEMINI_API_KEY"] as? String, !key.isEmpty else {
            fatalError("GeminiService: GEMINI_API_KEY missing or empty in Secrets.plist")
        }
        self.apiKey = key
    }

    /// Call Gemini (same endpoint as roadmap: `gemini-3-flash-preview`) for a post-Ramadan habit suggestion.
    /// - Parameters:
    ///   - habitName: e.g. "Salah"
    ///   - ramadanAmount: e.g. "5 times per day"
    /// - Returns: AISuggestion with suggestedAmount, motivation, tip
    func fetchSuggestion(habitName: String, ramadanAmount: String) async throws -> AISuggestion {
        let prompt = """
        You are a knowledgeable Islamic advisor helping a Muslim transition their Ramadan habits into sustainable daily routines after Ramadan ends.

        The person did the following during Ramadan:
        - Habit: \(habitName)
        - Ramadan Amount: \(ramadanAmount)

        Generate a personalized, realistic, and sustainable suggestion. Return JSON:
        {
          "suggestedAmount": "...",
          "motivation": "brief Islamic motivation sentence",
          "tip": "one practical tip"
        }
        """

        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ]
        ]

        guard let url = URL(string: "\(endpoint)?key=\(apiKey)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        // Parse: .candidates[0].content.parts[0].text → JSON string → AISuggestion
        struct GeminiResponse: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { let text: String }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]
        }

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let rawText = geminiResponse.candidates.first?.content.parts.first?.text else {
            throw URLError(.cannotParseResponse)
        }

        // Gemini may wrap JSON in markdown code fences — strip them
        let cleaned = rawText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8) else {
            throw URLError(.cannotParseResponse)
        }

        return try JSONDecoder().decode(AISuggestion.self, from: jsonData)
    }

    /// Generate exactly 28 daily milestones for a 28-day Islamic habit roadmap.
    /// - Parameters:
    ///   - userRefinementRequest: optional feedback when refining an existing plan.
    func generate28DayRoadmap(
        habitName: String,
        planNotes: String?,
        userRefinementRequest: String?
    ) async throws -> [HabitMilestone] {
        let notes = planNotes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 }
        let refine = userRefinementRequest.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 }

        var prompt = """
        You are a knowledgeable, gentle Islamic habits coach. Create a 28-day progressive roadmap for ONE habit.

        Habit name: \(habitName)
        """
        if let notes {
            prompt += "\nContext from the user about this habit: \(notes)\n"
        }
        if let refine {
            prompt += "\nThe user asked to adjust the plan. Honor this request while keeping steps realistic and merciful (no shame, small steps):\n\(refine)\n"
        }
        prompt += """
        Return ONLY valid JSON (no markdown fences) with this exact shape:
        {"milestones":[{"day":1,"title":"short title","description":"one or two sentences"},{"day":2,...},...]}
        Requirements:
        - Exactly 28 objects in "milestones", days 1 through 28 in order.
        - Each day builds gently; use encouraging, Muslim-appropriate language.
        - Titles under 60 characters; descriptions under 280 characters.
        """

        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ]
        ]

        guard let url = URL(string: "\(endpoint)?key=\(apiKey)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        struct RoadmapEnvelope: Decodable {
            let milestones: [HabitMilestone]
        }

        let cleaned = try Self.extractGeminiTextJSON(from: data)
        let decoded = try JSONDecoder().decode(RoadmapEnvelope.self, from: cleaned)
        guard decoded.milestones.count == 28 else {
            throw URLError(.cannotParseResponse)
        }
        let days = Set(decoded.milestones.map(\.day))
        guard days.count == 28, days == Set(1 ... 28) else {
            throw URLError(.cannotParseResponse)
        }
        return decoded.milestones.sorted { $0.day < $1.day }
    }

    // MARK: - Shared Gemini response parsing

    private static func extractGeminiTextJSON(from data: Data) throws -> Data {
        struct GeminiResponse: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { let text: String }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]
        }

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let rawText = geminiResponse.candidates.first?.content.parts.first?.text else {
            throw URLError(.cannotParseResponse)
        }

        let cleaned = rawText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8) else {
            throw URLError(.cannotParseResponse)
        }
        return jsonData
    }
}
