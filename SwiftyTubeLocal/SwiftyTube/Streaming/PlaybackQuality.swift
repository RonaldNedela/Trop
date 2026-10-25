//
//  PlaybackQuality.swift
//  SwiftyTube
//
//  Created by 686udjie on 03/10/2026.
//

import Foundation

/// Streaming quality preference.
public enum AudioQuality: String, Sendable, Hashable, Identifiable, CaseIterable, Codable {
    case auto
    case high
    case medium
    case low

    public var id: String { rawValue }
}

/// Download quality preference.
public enum DownloadQuality: String, Sendable, Hashable, Identifiable, CaseIterable, Codable {
    case auto
    case high
    case standard

    public var id: String { rawValue }
}

/// Video resolution preference for the muxed stream. `.auto` picks the best.
public enum VideoQuality: String, Sendable, Hashable, Identifiable, CaseIterable, Codable {
    case auto
    case p2160
    case p1440
    case p1080
    case p720
    case p480
    case p360
    case p240

    public var id: String { rawValue }

    /// Target height in pixels, or nil for `.auto`.
    public var height: Int? {
        switch self {
        case .auto: return nil
        case .p2160: return 2160
        case .p1440: return 1440
        case .p1080: return 1080
        case .p720: return 720
        case .p480: return 480
        case .p360: return 360
        case .p240: return 240
        }
    }
}
