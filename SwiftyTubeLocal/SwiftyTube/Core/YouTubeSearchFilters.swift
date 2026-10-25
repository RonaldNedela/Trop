//
//  YouTubeSearchFilters.swift
//  SwiftyTube
//
//  Created by 686udjie on 17/10/2026.
//

import Foundation

// Opaque protobuf `params` for `/search`. Each value stands alone; combining
// filters would need a protobuf builder and is not covered here.

/// Result type filter.
public enum YouTubeSearchFilter: String, Sendable, Hashable, CaseIterable, Codable {
    case video = "EgIQAQ=="
    case channel = "EgIQAg=="
    case playlist = "EgIQAw=="
    case movie = "EgIQBA=="
}

/// Upload-date recency filter.
public enum YouTubeSearchUploadDate: String, Sendable, Hashable, CaseIterable, Codable {
    case lastHour = "EgIIAQ=="
    case today = "EgIIAg=="
    case thisWeek = "EgIIAw=="
    case thisMonth = "EgIIBA=="
    case thisYear = "EgIIBQ=="
}

/// Result duration filter.
public enum YouTubeSearchDuration: String, Sendable, Hashable, CaseIterable, Codable {
    case short = "EgIYAQ=="
    case medium = "EgIYAg=="
    case long = "EgIYAw=="
}

/// Result sort order.
public enum YouTubeSearchSortOrder: String, Sendable, Hashable, CaseIterable, Codable {
    case relevance = ""
    case uploadDate = "CAI="
    case viewCount = "CAM="
    case rating = "CAE="
}
