import Foundation

/// DuckDuckGo Instant Answer API client for web search references.
@Observable
class WebSearchService {
    var isSearching = false
    var lastResults: [SearchResult] = []

    struct SearchResult: Identifiable {
        let id = UUID()
        let title: String
        let url: String
        let snippet: String
    }

    /// Search using DuckDuckGo Instant Answer API
    func search(query: String) async -> [SearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        isSearching = true
        defer { isSearching = false }

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://api.duckduckgo.com/?q=\(encoded)&format=json&no_html=1&skip_disambig=1") else {
            return []
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(DDGResponse.self, from: data)
            var results: [SearchResult] = []

            // Abstract (main answer)
            if !response.Abstract.isEmpty {
                results.append(SearchResult(
                    title: response.Heading.isEmpty ? "Summary" : response.Heading,
                    url: response.AbstractURL,
                    snippet: response.Abstract
                ))
            }

            // Related topics
            for topic in response.RelatedTopics.prefix(5) {
                if !topic.Text.isEmpty {
                    results.append(SearchResult(
                        title: topic.Text.prefix(60).description,
                        url: topic.FirstURL,
                        snippet: topic.Text
                    ))
                }
            }

            lastResults = results
            print("[WebSearch] Found \(results.count) results for: \(query)")
            return results
        } catch {
            print("[WebSearch] Error: \(error)")
            return []
        }
    }

    /// Format search results as context for the AI model
    func formatAsContext(_ results: [SearchResult]) -> String {
        guard !results.isEmpty else { return "" }
        var context = "Web search results:\n\n"
        for (i, result) in results.enumerated() {
            context += "[\(i + 1)] \(result.title)\n"
            context += "\(result.snippet)\n"
            if !result.url.isEmpty { context += "Source: \(result.url)\n" }
            context += "\n"
        }
        return context
    }
}

// MARK: - DuckDuckGo API Response

private struct DDGResponse: Codable {
    let Abstract: String
    let AbstractURL: String
    let Heading: String
    let RelatedTopics: [DDGTopic]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        Abstract = (try? container.decode(String.self, forKey: .Abstract)) ?? ""
        AbstractURL = (try? container.decode(String.self, forKey: .AbstractURL)) ?? ""
        Heading = (try? container.decode(String.self, forKey: .Heading)) ?? ""
        RelatedTopics = (try? container.decode([DDGTopic].self, forKey: .RelatedTopics)) ?? []
    }
}

private struct DDGTopic: Codable {
    let Text: String
    let FirstURL: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        Text = (try? container.decode(String.self, forKey: .Text)) ?? ""
        FirstURL = (try? container.decode(String.self, forKey: .FirstURL)) ?? ""
    }
}
