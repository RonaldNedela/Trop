//
//  YouTubeTranscript.swift
//  SwiftyTube
//
//  Created by 686udjie on 17/10/2026.
//

import Foundation

/// Timedtext parsing. Modern YouTube serves captions as JSON3
/// (`<captionTrack.baseURL>&fmt=json3`) with no PoToken, which is the reliable
/// transcript path; the `get_transcript` endpoint now requires attestation.
public enum YouTubeTranscript: Sendable {
    /// JSON3 body into timed segments.
    public static func segments(fromJSON3 data: Data) -> [YouTubeTranscriptSegment] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let events = root["events"] as? [[String: Any]] else { return [] }
        var segments: [YouTubeTranscriptSegment] = []
        for event in events {
            guard let segs = event["segs"] as? [[String: Any]] else { continue }
            let text = segs.compactMap { $0["utf8"] as? String }.joined()
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            segments.append(YouTubeTranscriptSegment(
                text: text,
                startMilliseconds: InnerTubeDecode.intFromStringOrInt(event["tStartMs"]) ?? 0,
                durationMilliseconds: InnerTubeDecode.intFromStringOrInt(event["dDurationMs"])
            ))
        }
        return segments
    }

    /// Appends `&fmt=json3` to a caption track URL, preserving any existing
    /// query string.
    public static func json3URL(from baseURL: String) -> String? {
        guard var components = URLComponents(string: baseURL),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }
        var items = components.queryItems ?? []
        if !items.contains(where: { $0.name == "fmt" }) {
            items.append(URLQueryItem(name: "fmt", value: "json3"))
        }
        components.queryItems = items
        return components.url?.absoluteString
    }
}
