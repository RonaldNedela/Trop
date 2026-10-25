//
//  YouTubeChannelParser.swift
//  SwiftyTube
//
//  Created by 686udjie on 17/10/2026.
//

import Foundation

/// Parsers for a channel landing page (`browseId: "UC..."`).
public enum YouTubeChannelParser: Sendable {
    public static func channelPage(in json: [String: Any]) -> YouTubeChannelPage {
        let (channel, banner) = header(in: json)
        return YouTubeChannelPage(
            channel: channel,
            bannerURL: banner,
            tabs: YouTubeFeeds.channelTabs(in: json),
            videos: YouTubeFeedParser.videos(in: json),
            playlists: YouTubeFeedParser.playlists(in: json),
            continuation: YouTubeFeedParser.continuation(in: json)
        )
    }

    /// Header info from either the legacy `c4TabbedHeaderRenderer` or the
    /// newer `pageHeaderRenderer`.
    static func header(in json: [String: Any]) -> (YouTubeChannel?, String?) {
        guard let header = json["header"] as? [String: Any] else { return (nil, nil) }
        if let c4 = header["c4TabbedHeaderRenderer"] as? [String: Any] {
            return legacyHeader(c4)
        }
        if let page = header["pageHeaderRenderer"] as? [String: Any] {
            return pageHeader(page)
        }
        return (nil, nil)
    }

    private static func legacyHeader(_ c4: [String: Any]) -> (YouTubeChannel?, String?) {
        let texts = metadataTexts(in: c4)
            + [InnerTubeDecode.runsTextTolerant(c4["subscriberCountText"])].compactMap { $0 }
            + [InnerTubeDecode.runsTextTolerant(c4["videosCountText"])].compactMap { $0 }
        let counts = classifyCounts(texts)
        let channel = YouTubeChannel(
            channelId: c4["channelId"] as? String ?? channelId(in: c4),
            title: InnerTubeDecode.runsTextTolerant(c4["title"]) ?? "",
            handle: handle(in: c4),
            thumbnailURL: largestURL((c4["avatar"] as? [String: Any])?["thumbnails"] as? [[String: Any]]),
            subscriberCountText: counts.subscribers,
            videoCountText: counts.videos
        )
        return (channel.title.isEmpty ? nil : channel, bannerURL(c4))
    }

    private static func pageHeader(_ page: [String: Any]) -> (YouTubeChannel?, String?) {
        let viewModel = InnerTubeDecode.dict(at: ["content", "pageHeaderViewModel"], in: page) ?? page
        let title = page["pageTitle"] as? String
            ?? InnerTubeDecode.string(at: ["title", "dynamicTextViewModel", "text", "content"], in: viewModel)
            ?? ""
        let counts = classifyCounts(metadataTexts(in: page))
        let channel = YouTubeChannel(
            channelId: channelId(in: page),
            title: title,
            handle: handle(in: page),
            thumbnailURL: avatarURL(viewModel) ?? avatarURL(page),
            subscriberCountText: counts.subscribers,
            videoCountText: counts.videos,
            description: InnerTubeDecode.string(
                at: ["description", "descriptionPreviewViewModel", "description", "content"], in: viewModel
            )
        )
        return (channel.title.isEmpty ? nil : channel, bannerURL(page) ?? bannerURL(viewModel))
    }

    // MARK: - Helpers

    /// Finds a channel avatar in a channel browse response. New WEB headers
    /// have appeared with several nested avatar/image layouts, so keep this
    /// search scoped to the header before falling back to the full response.
    public static func avatarURL(in json: [String: Any]) -> String? {
        if let header = json["header"] as? [String: Any],
           let url = avatarURL(header) {
            return url
        }
        return avatarURL(json)
    }

    private static func avatarURL(_ dict: [String: Any]) -> String? {
        if let sources = InnerTubeDecode.array(at: ["image", "sources"], in: dict) {
            return largestURL(sources)
        }
        if let sources = InnerTubeDecode.array(at: ["image", "avatarViewModel", "image", "sources"], in: dict) {
            return largestURL(sources)
        }
        if let sources = InnerTubeDecode.array(at: ["avatar", "avatarViewModel", "image", "sources"], in: dict) {
            return largestURL(sources)
        }
        for (key, value) in dict {
            let lowerKey = key.lowercased()
            if lowerKey.contains("avatar") || lowerKey.contains("channelthumbnail") {
                if let child = value as? [String: Any], let url = avatarURL(child) {
                    return url
                }
                if let children = value as? [[String: Any]] {
                    for child in children {
                        if let url = avatarURL(child) { return url }
                    }
                }
            }
            if let child = value as? [String: Any], let url = avatarURL(child) {
                return url
            }
            if let children = value as? [[String: Any]] {
                for child in children {
                    if let url = avatarURL(child) { return url }
                }
            }
        }
        return nil
    }

    private static func bannerURL(_ dict: [String: Any]) -> String? {
        if let sources = InnerTubeDecode.array(at: ["banner", "imageBannerViewModel", "image", "sources"], in: dict) {
            return largestURL(sources)
        }
        if let sources = InnerTubeDecode.array(at: ["banner", "image", "sources"], in: dict) {
            return largestURL(sources)
        }
        return largestURL((dict["banner"] as? [String: Any])?["thumbnails"] as? [[String: Any]])
    }

    private static func largestURL(_ sources: [[String: Any]]?) -> String? {
        sources?.max {
            ((($0["width"] as? Int) ?? 0) * (($0["height"] as? Int) ?? 0))
                < ((($1["width"] as? Int) ?? 0) * (($1["height"] as? Int) ?? 0))
        }?["url"] as? String
    }

    private static func metadataTexts(in dict: [String: Any]) -> [String] {
        var texts: [String] = []
        YouTubeFeedParser.walk(dict) { renderer, key in
            guard key == "metadataParts" else { return }
            guard let text = InnerTubeDecode.string(at: ["text", "content"], in: renderer), !text.isEmpty else {
                return
            }
            texts.append(contentsOf: text.components(separatedBy: "•").map {
                $0.trimmingCharacters(in: .whitespaces)
            })
        }
        return texts
    }

    private static func classifyCounts(_ texts: [String]) -> (subscribers: String?, videos: String?) {
        var subscribers: String?
        var videos: String?
        for text in texts {
            let lower = text.lowercased()
            if lower.contains("subscriber"), subscribers == nil {
                subscribers = text
            } else if lower.contains("video"), videos == nil {
                videos = text
            }
        }
        return (subscribers, videos)
    }

    private static func channelId(in dict: [String: Any]) -> String? {
        var id: String?
        YouTubeFeedParser.walk(dict) { renderer, key in
            guard id == nil, key == "browseEndpoint" else { return }
            if let browseId = renderer["browseId"] as? String, browseId.hasPrefix("UC") {
                id = browseId
            }
        }
        return id
    }

    private static func handle(in dict: [String: Any]) -> String? {
        var handle: String?
        YouTubeFeedParser.walk(dict) { renderer, key in
            guard handle == nil, key == "browseEndpoint" else { return }
            guard let canonical = renderer["canonicalBaseUrl"] as? String, canonical.hasPrefix("/@") else { return }
            handle = String(canonical.dropFirst(2))
        }
        return handle
    }
}
