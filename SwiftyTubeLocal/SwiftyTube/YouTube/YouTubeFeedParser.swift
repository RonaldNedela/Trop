//
//  YouTubeFeedParser.swift
//  SwiftyTube
//
//  Created by 686udjie on 17/10/2026.
//

import Foundation

/// Tolerant parsers for browse / search responses. Renderers move around
/// between layouts, so rows are collected by a recursive sweep and deduped by
/// id rather than by fixed paths.
public enum YouTubeFeedParser: Sendable {
    /// Renderer keys that carry a video.
    static let videoKeys: Set<String> = [
        "videoRenderer",
        "compactVideoRenderer",
        "gridVideoRenderer",
        "videoWithContextRenderer",
        "reelItemRenderer",
        "playlistVideoRenderer",
        "playlistPanelVideoRenderer",
        "gridPlaylistVideoRenderer",
        "reelItemRenderer"
    ]

    /// Newer content shapes (video or playlist depending on `contentType`).
    static let lockupKeys: Set<String> = ["lockupViewModel", "shortsLockupViewModel"]

    // MARK: - Collections

    /// Every video in the response, in document order, deduped by id.
    public static func videos(in json: [String: Any]) -> [YouTubeVideo] {
        collect(in: json, keys: videoKeys.union(lockupKeys)) { renderer, key in
            switch key {
            case "lockupViewModel":
                return video(fromLockup: renderer)
            case "shortsLockupViewModel":
                return video(fromShortsLockup: renderer)
            default:
                return video(from: renderer, rendererKey: key)
            }
        }
    }

    /// Every channel in the response, deduped by id/handle/title.
    public static func channels(in json: [String: Any]) -> [YouTubeChannel] {
        collect(in: json, keys: ["channelRenderer", "gridChannelRenderer"]) { renderer, _ in
            channel(from: renderer)
        }
    }

    /// Every playlist in the response, deduped by id.
    public static func playlists(in json: [String: Any]) -> [YouTubePlaylist] {
        let keys = lockupKeys.union(["playlistRenderer", "gridPlaylistRenderer", "compactPlaylistRenderer"])
        return collect(in: json, keys: keys) { renderer, key in
            key == "lockupViewModel" ? playlist(fromLockup: renderer) : playlist(from: renderer)
        }
    }

    /// Titled carousels (home / channel shelves).
    public static func shelves(in json: [String: Any]) -> [YouTubeShelf] {
        var out: [YouTubeShelf] = []
        walk(json) { renderer, key in
            guard key == "shelfRenderer" || key == "richShelfRenderer" else { return }
            let shelf = YouTubeShelf(
                title: InnerTubeDecode.runsTextTolerant(renderer["title"]),
                subtitle: InnerTubeDecode.runsTextTolerant(renderer["subtitle"])
                    ?? InnerTubeDecode.runsTextTolerant(renderer["subtitleText"]),
                videos: videos(in: renderer),
                playlists: playlists(in: renderer)
            )
            if !shelf.videos.isEmpty || !shelf.playlists.isEmpty {
                out.append(shelf)
            }
        }
        return out
    }

    /// Search page across all renderer types.
    public static func searchResults(in json: [String: Any]) -> YouTubeSearchResults {
        YouTubeSearchResults(
            videos: videos(in: json),
            channels: channels(in: json),
            playlists: playlists(in: json),
            estimatedResults: InnerTubeDecode.intFromStringOrInt(json["estimatedResults"]),
            continuation: continuation(in: json)
        )
    }

    // MARK: - Continuation

    /// Next-page token: `continuationCommand.token`, else `nextContinuationData`.
    public static func continuation(in json: [String: Any]) -> String? {
        var token: String?
        walk(json) { renderer, key in
            guard token == nil else { return }
            switch key {
            case "continuationItemRenderer":
                token = InnerTubeDecode.string(
                    at: ["continuationEndpoint", "continuationCommand", "token"], in: renderer
                )
            case "nextContinuationData", "reloadContinuationData":
                token = renderer["continuation"] as? String
            default:
                break
            }
        }
        return token
    }

    // MARK: - Renderer → model

    static func video(from renderer: [String: Any], rendererKey: String) -> YouTubeVideo? {
        guard let videoId = renderer["videoId"] as? String, !videoId.isEmpty else { return nil }
        let title = InnerTubeDecode.runsTextTolerant(renderer["title"])
            ?? InnerTubeDecode.runsTextTolerant(renderer["headline"])
            ?? ""
        let byline = bylineInfo(renderer)
        let lengthText = InnerTubeDecode.runsTextTolerant(renderer["lengthText"])?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let isLive = lengthText?.uppercased() == "LIVE" || hasLiveBadge(renderer)
        let duration = (isLive || lengthText == nil) ? nil : DurationFormat.parseClock(lengthText ?? "")
        let channelAvatar = InnerTubeDecode.array(
            at: ["avatar", "decoratedAvatarViewModel", "avatar", "avatarViewModel", "image", "sources"], in: renderer
        ) ?? InnerTubeDecode.array(
            at: ["channelThumbnailSupportedRenderers", "channelThumbnailWithLinkRenderer", "thumbnail", "thumbnails"], in: renderer
        ) ?? InnerTubeDecode.array(
            at: ["channelThumbnail", "thumbnails"], in: renderer
        )
        let channelAvatarURL = InnerTubeDecode.thumbnailURLTolerant(
            ["thumbnails": channelAvatar ?? []]
        ) ?? avatarURL(in: renderer)
let viewCount = InnerTubeDecode.runsTextTolerant(renderer["viewCountText"])
            ?? InnerTubeDecode.runsTextTolerant(renderer["shortViewCountText"])
        let shortViewCount = InnerTubeDecode.runsTextTolerant(renderer["shortViewCountText"])
            ?? InnerTubeDecode.runsTextTolerant(renderer["viewCountText"])
        return YouTubeVideo(
            videoId: videoId,
            title: title,
            channelTitle: byline?.title,
            channelId: byline?.channelId,
            durationSeconds: duration,
            thumbnailURL: InnerTubeDecode.thumbnailURLTolerant(renderer),
            channelAvatarURL: channelAvatarURL,
            viewCountText: viewCount,
            shortViewCountText: shortViewCount,
            publishedTimeText: InnerTubeDecode.runsTextTolerant(renderer["publishedTimeText"]),
            isLive: isLive,
            isShort: rendererKey == "reelItemRenderer" || isShort(renderer)
        )
    }

    static func channel(from renderer: [String: Any]) -> YouTubeChannel? {
        let title = InnerTubeDecode.runsTextTolerant(renderer["title"]) ?? ""
        guard !title.isEmpty else { return nil }
        return YouTubeChannel(
            channelId: renderer["channelId"] as? String ?? channelIdFromNavigation(renderer),
            title: title,
            handle: handle(from: renderer),
            thumbnailURL: InnerTubeDecode.thumbnailURLTolerant(renderer),
            subscriberCountText: InnerTubeDecode.runsTextTolerant(renderer["subscriberCountText"]),
            videoCountText: InnerTubeDecode.runsTextTolerant(renderer["videoCountText"])
                ?? InnerTubeDecode.runsTextTolerant(renderer["videosCountText"]),
            description: InnerTubeDecode.runsTextTolerant(renderer["descriptionSnippet"])
        )
    }

    static func playlist(from renderer: [String: Any]) -> YouTubePlaylist? {
        guard let playlistId = renderer["playlistId"] as? String, !playlistId.isEmpty else { return nil }
        let byline = bylineInfo(renderer)
        let count = InnerTubeDecode.runsTextTolerant(renderer["videoCountText"])
            ?? (renderer["videoCount"] as? String)
            ?? InnerTubeDecode.intFromStringOrInt(renderer["videoCount"]).map { "\($0) videos" }
        return YouTubePlaylist(
            playlistId: playlistId,
            title: InnerTubeDecode.runsTextTolerant(renderer["title"]) ?? "",
            thumbnailURL: InnerTubeDecode.thumbnailURLTolerant(renderer),
            videoCountText: count,
            channelTitle: byline?.title,
            channelId: byline?.channelId
        )
    }

    // MARK: - lockupViewModel (newer home/search/channel shape)

    /// `lockupViewModel` carries a video when `contentType` says so; reads the
    /// dict directly (the renderer is not wrapped again).
    static func video(fromLockup lockup: [String: Any]) -> YouTubeVideo? {
        guard let contentId = lockup["contentId"] as? String, !contentId.isEmpty else { return nil }
        guard (lockup["contentType"] as? String ?? "").contains("VIDEO") else { return nil }
        let meta = InnerTubeDecode.dict(at: ["metadata", "lockupMetadataViewModel"], in: lockup)
        let info = lockupMetadata(lockup)
        return YouTubeVideo(
            videoId: contentId,
            title: lockupTitle(meta) ?? "",
            channelTitle: info.channelTitle,
            channelId: info.channelId,
            durationSeconds: lockupDuration(lockup),
            thumbnailURL: lockupThumbnail(lockup),
            channelAvatarURL: lockupChannelAvatar(lockup),
            viewCountText: info.viewCount,
            publishedTimeText: info.published,
            isLive: lockupIsLive(lockup),
            isShort: false
        )
    }

    static func playlist(fromLockup lockup: [String: Any]) -> YouTubePlaylist? {
        guard let contentId = lockup["contentId"] as? String, !contentId.isEmpty else { return nil }
        let type = lockup["contentType"] as? String ?? ""
        guard type.contains("PLAYLIST") || type.contains("ALBUM") || type.contains("PODCAST") else { return nil }
        let meta = InnerTubeDecode.dict(at: ["metadata", "lockupMetadataViewModel"], in: lockup)
        let info = lockupMetadata(lockup)
        return YouTubePlaylist(
            playlistId: contentId,
            title: lockupTitle(meta) ?? "",
            thumbnailURL: lockupThumbnail(lockup),
            videoCountText: info.videoCount ?? info.viewCount,
            channelTitle: info.channelTitle,
            channelId: info.channelId
        )
    }

    /// `shortsLockupViewModel`: id in the reel watch endpoint, text in overlay.
    static func video(fromShortsLockup renderer: [String: Any]) -> YouTubeVideo? {
        let videoId = InnerTubeDecode.string(
            at: ["onTap", "innertubeCommand", "reelWatchEndpoint", "videoId"], in: renderer
        ) ?? InnerTubeDecode.string(at: ["onTap", "innertubeCommand", "watchEndpoint", "videoId"], in: renderer)
        guard let videoId, !videoId.isEmpty else { return nil }
        let overlay = InnerTubeDecode.dict(at: ["overlayMetadata"], in: renderer) ?? [:]
        let sources = InnerTubeDecode.array(at: ["thumbnail", "sources"], in: renderer)
            ?? InnerTubeDecode.array(at: ["thumbnail", "thumbnails"], in: renderer)
        return YouTubeVideo(
            videoId: videoId,
            title: InnerTubeDecode.string(at: ["primaryText", "content"], in: overlay) ?? "",
            thumbnailURL: sourceURL(sources),
            viewCountText: InnerTubeDecode.string(at: ["secondaryText", "content"], in: overlay),
            isShort: true
        )
    }

    private static func lockupTitle(_ meta: [String: Any]?) -> String? {
        guard let title = meta?["title"] as? [String: Any] else { return nil }
        if let content = title["content"] as? String { return content }
        return InnerTubeDecode.runsTextTolerant(title)
    }

    /// Classified metadata from a lockup's rows.
    struct LockupMetadata {
        var channelTitle: String?
        var channelId: String?
        var viewCount: String?
        var published: String?
        var videoCount: String?
    }

    /// Channel comes from a `commandRuns` browse link; the remaining parts are
    /// classified by keyword (views / videos / "… ago").
    static func lockupMetadata(_ lockup: [String: Any]) -> LockupMetadata {
        var info = LockupMetadata()
        guard let container = InnerTubeDecode.dict(
            at: ["metadata", "lockupMetadataViewModel", "metadata", "contentMetadataViewModel"],
            in: lockup
        ), let rows = container["metadataRows"] as? [[String: Any]] else { return info }
        for row in rows {
            for part in (row["metadataParts"] as? [[String: Any]]) ?? [] {
                guard let text = InnerTubeDecode.dict(at: ["text"], in: part) else { continue }
                let content = (text["content"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
                if let browseId = channelLink(in: text), info.channelId == nil {
                    info.channelTitle = info.channelTitle ?? (content.isEmpty ? nil : content)
                    info.channelId = browseId
                    continue
                }
                guard !content.isEmpty else { continue }
                let lower = content.lowercased()
                if lower.contains("view") || lower.contains("subscriber") {
                    info.viewCount = info.viewCount ?? content
                } else if lower.contains("video") {
                    info.videoCount = info.videoCount ?? content
                } else if lower.contains("ago") {
                    info.published = info.published ?? content
                } else if info.channelTitle == nil {
                    info.channelTitle = content
                } else {
                    info.published = info.published ?? content
                }
            }
        }
        return info
    }

    private static func channelLink(in text: [String: Any]) -> String? {
        guard let runs = text["commandRuns"] as? [[String: Any]] else { return nil }
        return runs.compactMap { run -> String? in
            InnerTubeDecode.string(at: ["onTap", "innertubeCommand", "browseEndpoint", "browseId"], in: run)
        }.first { $0.hasPrefix("UC") }
    }

    /// Channel avatar from lockup metadata rows (WEB client).
    static func lockupChannelAvatar(_ lockup: [String: Any]) -> String? {
        // Some music/search lockups omit decoratedAvatarViewModel and place
        // the channel image directly in lockupMetadataViewModel.image. This
        // is safe because the video's thumbnail is separate under contentImage.
        if let sources = InnerTubeDecode.array(
            at: ["metadata", "lockupMetadataViewModel", "image", "sources"],
            in: lockup
        ), let url = sourceURL(sources) {
            return url
        }

        if let sources = InnerTubeDecode.array(
            at: [
                "metadata", "lockupMetadataViewModel", "image",
                "decoratedAvatarViewModel", "avatar", "avatarViewModel",
                "image", "sources"
            ], in: lockup
        ) {
            return sourceURL(sources)
        }

        if let url = avatarURL(in: lockup) {
            return url
        }

        guard let container = InnerTubeDecode.dict(
            at: ["metadata", "lockupMetadataViewModel", "metadata", "contentMetadataViewModel"],
            in: lockup
        ), let rows = container["metadataRows"] as? [[String: Any]] else {
            return nil
        }
        for row in rows {
            for part in (row["metadataParts"] as? [[String: Any]]) ?? [] {
                if let sources = InnerTubeDecode.array(at: ["thumbnail", "thumbnailViewModel", "image", "sources"], in: part) {
                    return sourceURL(sources)
                }
                if let sources = InnerTubeDecode.array(at: ["thumbnail", "image", "sources"], in: part) {
                    return sourceURL(sources)
                }
                if let sources = InnerTubeDecode.array(at: ["thumbnail", "thumbnails"], in: part) {
                    return sourceURL(sources)
                }
            }
        }
        return nil
    }

    private static func lockupThumbnail(_ lockup: [String: Any]) -> String? {
        // contentImage.thumbnailViewModel.image.sources, or the collection
        // variant's primaryThumbnail.
        if let sources = InnerTubeDecode.array(
            at: ["contentImage", "thumbnailViewModel", "image", "sources"], in: lockup
        ), let url = sourceURL(sources) {
            return url
        }
        if let sources = InnerTubeDecode.array(
            at: [
                "contentImage", "collectionThumbnailViewModel", "primaryThumbnail",
                "thumbnailViewModel", "image", "sources"
            ], in: lockup
        ) {
            return sourceURL(sources)
        }
        return nil
    }

    static func sourceURL(_ sources: [[String: Any]]?) -> String? {
        sources?.max {
            ((($0["width"] as? Int) ?? 0) * (($0["height"] as? Int) ?? 0))
                < ((($1["width"] as? Int) ?? 0) * (($1["height"] as? Int) ?? 0))
        }?["url"] as? String
    }

    /// Finds avatar-specific image sources across WEB search renderer variants.
    /// It only returns images reached through avatar/channel-thumbnail keys, so
    /// a video's main thumbnail is never mistaken for its channel avatar.
    private static func avatarURL(in value: Any) -> String? {
        guard let dict = value as? [String: Any] else { return nil }
        for (key, child) in dict {
            let lowerKey = key.lowercased()
            if lowerKey.contains("avatar") || lowerKey.contains("channelthumbnail") {
                if let childDict = child as? [String: Any] {
                    if let sources = InnerTubeDecode.array(at: ["image", "sources"], in: childDict),
                       let url = sourceURL(sources) { return url }
                    if let sources = InnerTubeDecode.array(at: ["avatarViewModel", "image", "sources"], in: childDict),
                       let url = sourceURL(sources) { return url }
                    if let url = InnerTubeDecode.thumbnailURLTolerant(childDict) { return url }
                }
                if let childArray = child as? [[String: Any]] {
                    for item in childArray {
                        if let url = avatarURL(in: item) { return url }
                    }
                }
            }
            if let childDict = child as? [String: Any], let url = avatarURL(in: childDict) { return url }
            if let childArray = child as? [[String: Any]] {
                for item in childArray {
                    if let url = avatarURL(in: item) { return url }
                }
            }
        }
        return nil
    }

    private static func lockupDuration(_ lockup: [String: Any]) -> Int? {
        var seconds: Int?
        walk(lockup) { renderer, key in
            guard seconds == nil else { return }
            if key == "thumbnailBadgeViewModel", let text = renderer["text"] as? String {
                seconds = DurationFormat.parseClock(text)
            } else if key == "thumbnailOverlayTimeStatusRenderer",
                      let text = InnerTubeDecode.runsTextTolerant(renderer["text"]) {
                seconds = DurationFormat.parseClock(text)
            }
        }
        return seconds
    }

    private static func lockupIsLive(_ lockup: [String: Any]) -> Bool {
        var live = false
        walk(lockup) { renderer, key in
            guard !live else { return }
            if key == "thumbnailBadgeViewModel",
               let text = renderer["text"] as? String, text.uppercased() == "LIVE" {
                live = true
            } else if key == "thumbnailOverlayTimeStatusRenderer",
                      let text = InnerTubeDecode.runsTextTolerant(renderer["text"]),
                      text.uppercased() == "LIVE" {
                live = true
            }
        }
        return live
    }

    // MARK: - Shared helpers

    /// (channel name, channel id) from any byline shape.
    static func bylineInfo(_ renderer: [String: Any]) -> (title: String, channelId: String?)? {
        for key in ["ownerText", "longBylineText", "shortBylineText"] {
            guard let text = renderer[key] as? [String: Any] else { continue }
            let runs = text["runs"] as? [[String: Any]] ?? []
            let title = runs.compactMap { $0["text"] as? String }.joined()
            guard !title.isEmpty else { continue }
            let channelId = runs.compactMap { run -> String? in
                guard let nav = run["navigationEndpoint"] as? [String: Any],
                      let browse = nav["browseEndpoint"] as? [String: Any] else { return nil }
                return browse["browseId"] as? String
            }.first
            return (title, channelId)
        }
        return nil
    }

    static func channelIdFromNavigation(_ renderer: [String: Any]) -> String? {
        guard let nav = renderer["navigationEndpoint"] as? [String: Any],
              let browse = nav["browseEndpoint"] as? [String: Any] else { return nil }
        return browse["browseId"] as? String
    }

    static func handle(from renderer: [String: Any]) -> String? {
        if let nav = renderer["navigationEndpoint"] as? [String: Any],
           let browse = nav["browseEndpoint"] as? [String: Any],
           let canonical = browse["canonicalBaseUrl"] as? String {
            return canonical.hasPrefix("/@") ? String(canonical.dropFirst(2)) : canonical
        }
        return nil
    }

    static func hasLiveBadge(_ renderer: [String: Any]) -> Bool {
        if let badges = renderer["badges"] as? [[String: Any]] {
            for entry in badges {
                let label = (entry["metadataBadgeRenderer"] as? [String: Any])?["label"] as? String
                if label?.uppercased() == "LIVE" { return true }
            }
        }
        if let overlays = renderer["thumbnailOverlays"] as? [[String: Any]] {
            for entry in overlays {
                if let status = entry["thumbnailOverlayTimeStatusRenderer"] as? [String: Any],
                   let text = InnerTubeDecode.runsTextTolerant(status["text"])?.uppercased(),
                   text == "LIVE" {
                    return true
                }
            }
        }
        return false
    }

    static func isShort(_ renderer: [String: Any]) -> Bool {
        InnerTubeDecode.dict(at: ["navigationEndpoint", "reelWatchEndpoint"], in: renderer) != nil
    }

    // MARK: - Recursive sweep

    /// Depth-first sweep. `visit` receives the dict that sits under `key`
    /// (arrays propagate their element key), so callers can pattern-match on
    /// renderer names regardless of nesting.
    static func walk(_ value: Any, key: String? = nil, _ visit: ([String: Any], String) -> Void) {
        if let dict = value as? [String: Any] {
            if let key { visit(dict, key) }
            for (childKey, child) in dict {
                walk(child, key: childKey, visit)
            }
        } else if let array = value as? [Any] {
            for element in array {
                walk(element, key: key, visit)
            }
        }
    }

    /// Sweep for `keys`, deduping by the model's identity.
    static func collect<T: YouTubeIdentifiable>(
        in json: [String: Any],
        keys: Set<String>,
        _ extract: ([String: Any], String) -> T?
    ) -> [T] {
        var seen = Set<String>()
        var out: [T] = []
        walk(json) { renderer, key in
            guard keys.contains(key), let model = extract(renderer, key) else { return }
            if seen.insert(model.swiftyTubeIdentity).inserted {
                out.append(model)
            }
        }
        return out
    }
}

/// Common identity for dedupe.
protocol YouTubeIdentifiable {
    var swiftyTubeIdentity: String { get }
}

extension YouTubeVideo: YouTubeIdentifiable {
    var swiftyTubeIdentity: String { videoId }
}

extension YouTubePlaylist: YouTubeIdentifiable {
    var swiftyTubeIdentity: String { playlistId }
}

extension YouTubeChannel: YouTubeIdentifiable {
    var swiftyTubeIdentity: String { channelId ?? handle ?? title }
}
