//
//  SearchSuggestions.swift
//  SwiftyTube
//
//  Created by 686udjie on 17/10/2026.
//

import Foundation

/// Autocomplete suggestions. Unlike the InnerTube endpoints this hits the
/// public suggestion service (no auth, no context).
public enum SearchSuggestions: Sendable {
    private static let endpoint = "https://suggestqueries-clients6.youtube.com/complete/search"

    public static func suggest(
        query: String,
        gl: String = "US",
        hl: String = "en",
        session: URLSession = .shared
    ) async throws -> [String] {
        guard var components = URLComponents(string: endpoint) else {
            throw InnerTubeError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "client", value: "firefox"),
            URLQueryItem(name: "ds", value: "yt"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "hl", value: hl),
            URLQueryItem(name: "gl", value: gl)
        ]
        guard let url = components.url else { throw InnerTubeError.invalidResponse }

        var request = URLRequest(url: url)
        request.setValue("en", forHTTPHeaderField: "Accept-Language")
        let (data, http) = try await HttpClient.data(for: request, session: session)
        guard (200 ... 299).contains(http.statusCode) else {
            throw InnerTubeError.httpError(statusCode: http.statusCode, data: data)
        }
        return parse(data: data)
    }

    /// Plain JSON array, or a `window.google.ac.h(...)` JSONP wrapper.
    static func parse(data: Data) -> [String] {
        var payload = data
        if let text = String(data: data, encoding: .utf8),
           let open = text.firstIndex(of: "("),
           let close = text.lastIndex(of: ")"),
           open < close
        {
            let inner = text[text.index(after: open) ..< close]
            if let wrapped = inner.data(using: .utf8) { payload = wrapped }
        }
        guard let root = try? JSONSerialization.jsonObject(with: payload) as? [Any],
              root.count > 1,
              let entries = root[1] as? [Any] else { return [] }
        return entries.compactMap { entry in
            (entry as? [Any])?.first as? String
        }
    }
}
