//
//  YouTubeFeeds.swift
//  SwiftyTube
//
//  Created by 686udjie on 17/10/2026.
//

import Foundation

/// Main-YouTube browse ids and channel-tab helpers. Used with the `.youtube`
/// service host; YouTube Music browse ids live with the `Sync` module.
public enum YouTubeFeeds: Sendable {
    // MARK: - Top-level feeds (`browseId`)

    /// Home recommendations.
    public static let home = "FEwhat_to_watch"
    /// Trending / Explore.
    public static let trending = "FEtrending"
    /// Subscription uploads (signed in).
    public static let subscriptions = "FEsubscriptions"
    /// Watch history (signed in).
    public static let history = "FEhistory"
    /// Shorts feed.
    public static let shorts = "FEshorts"

    // MARK: - Library playlists

    /// Liked videos. Browse with `playlistBrowseId(likedVideosPlaylistId)`.
    public static let likedVideosPlaylistId = "LL"
    /// Watch later. Browse with `playlistBrowseId(watchLaterPlaylistId)`.
    public static let watchLaterPlaylistId = "WL"

    /// Playlist `browseId` (`VL` + id); accepts an already-prefixed id.
    public static func playlistBrowseId(_ playlistId: String) -> String {
        playlistId.hasPrefix("VL") ? playlistId : "VL\(playlistId)"
    }

    // MARK: - Channel tabs

    /// Parse the tab chips off a channel browse response. Reusing these
    /// `params` is safer than hardcoding tab protobufs that YouTube rotates.
    public static func channelTabs(in json: [String: Any]) -> [YouTubeChannelTab] {
        tabRenderers(in: json).compactMap { tab in
            guard let title = tabTitle(tab) else { return nil }
            let browse = (tab["endpoint"] as? [String: Any])?["browseEndpoint"] as? [String: Any]
            return YouTubeChannelTab(
                title: title,
                params: browse?["params"] as? String,
                browseId: browse?["browseId"] as? String,
                selected: tab["selected"] as? Bool ?? false
            )
        }
    }

    static func tabRenderers(in json: [String: Any]) -> [[String: Any]] {
        guard let contents = json["contents"] as? [String: Any] else { return [] }
        let tabArrays = [
            (contents["twoColumnBrowseResultsRenderer"] as? [String: Any])?["tabs"],
            (contents["singleColumnBrowseResultsRenderer"] as? [String: Any])?["tabs"]
        ]
        for case let tabs as [[String: Any]] in tabArrays {
            let renderers = tabs.compactMap { $0["tabRenderer"] as? [String: Any] }
            if !renderers.isEmpty { return renderers }
        }
        return []
    }

    static func tabTitle(_ tab: [String: Any]) -> String? {
        if let title = tab["title"] as? String, !title.isEmpty { return title }
        return InnerTubeJSON.runsText(tab["title"] as? [String: Any])
    }
}

/// A chip on a channel page (Videos / Shorts / Live / Playlists / ...).
public struct YouTubeChannelTab: Sendable, Hashable, Codable {
    public let title: String
    public let params: String?
    public let browseId: String?
    public let selected: Bool

    public init(title: String, params: String? = nil, browseId: String? = nil, selected: Bool = false) {
        self.title = title
        self.params = params
        self.browseId = browseId
        self.selected = selected
    }
}
