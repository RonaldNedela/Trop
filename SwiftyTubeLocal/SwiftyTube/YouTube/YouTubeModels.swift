//
//  YouTubeModels.swift
//  SwiftyTube
//
//  Created by 686udjie on 17/10/2026.
//

import Foundation

/// A video row anywhere on a YouTube surface (home, search, watch, channel).
public struct YouTubeVideo: Sendable, Hashable, Codable {
    public var videoId: String
    public var title: String
    public var channelTitle: String?
    public var channelId: String?
    public var durationSeconds: Int?
    public var thumbnailURL: String?
    public var channelAvatarURL: String?
    public var viewCountText: String?
    public var shortViewCountText: String?
    public var publishedTimeText: String?
    public var isLive: Bool
    public var isShort: Bool

    public init(
        videoId: String,
        title: String,
        channelTitle: String? = nil,
        channelId: String? = nil,
        durationSeconds: Int? = nil,
        thumbnailURL: String? = nil,
        channelAvatarURL: String? = nil,
        viewCountText: String? = nil,
        shortViewCountText: String? = nil,
        publishedTimeText: String? = nil,
        isLive: Bool = false,
        isShort: Bool = false
    ) {
        self.videoId = videoId
        self.title = title
        self.channelTitle = channelTitle
        self.channelId = channelId
        self.durationSeconds = durationSeconds
        self.thumbnailURL = thumbnailURL
        self.channelAvatarURL = channelAvatarURL
        self.viewCountText = viewCountText
        self.shortViewCountText = shortViewCountText
        self.publishedTimeText = publishedTimeText
        self.isLive = isLive
        self.isShort = isShort
    }
}

/// A channel row (search, subscriptions, channel header).
public struct YouTubeChannel: Sendable, Hashable, Codable {
    public var channelId: String?
    public var title: String
    public var handle: String?
    public var thumbnailURL: String?
    public var subscriberCountText: String?
    public var videoCountText: String?
    public var description: String?

    public init(
        channelId: String? = nil,
        title: String,
        handle: String? = nil,
        thumbnailURL: String? = nil,
        subscriberCountText: String? = nil,
        videoCountText: String? = nil,
        description: String? = nil
    ) {
        self.channelId = channelId
        self.title = title
        self.handle = handle
        self.thumbnailURL = thumbnailURL
        self.subscriberCountText = subscriberCountText
        self.videoCountText = videoCountText
        self.description = description
    }
}

/// A playlist row (search, channel, library).
public struct YouTubePlaylist: Sendable, Hashable, Codable {
    public var playlistId: String
    public var title: String
    public var thumbnailURL: String?
    public var videoCountText: String?
    public var channelTitle: String?
    public var channelId: String?

    public init(
        playlistId: String,
        title: String,
        thumbnailURL: String? = nil,
        videoCountText: String? = nil,
        channelTitle: String? = nil,
        channelId: String? = nil
    ) {
        self.playlistId = playlistId
        self.title = title
        self.thumbnailURL = thumbnailURL
        self.videoCountText = videoCountText
        self.channelTitle = channelTitle
        self.channelId = channelId
    }
}

/// A titled carousel on the home / channel page.
public struct YouTubeShelf: Sendable, Hashable, Codable {
    public var title: String?
    public var subtitle: String?
    public var videos: [YouTubeVideo]
    public var playlists: [YouTubePlaylist]

    public init(
        title: String? = nil,
        subtitle: String? = nil,
        videos: [YouTubeVideo] = [],
        playlists: [YouTubePlaylist] = []
    ) {
        self.title = title
        self.subtitle = subtitle
        self.videos = videos
        self.playlists = playlists
    }
}

/// Mixed results of a `/search` call.
public struct YouTubeSearchResults: Sendable, Hashable, Codable {
    public var videos: [YouTubeVideo]
    public var channels: [YouTubeChannel]
    public var playlists: [YouTubePlaylist]
    public var estimatedResults: Int?
    public var continuation: String?

    public init(
        videos: [YouTubeVideo] = [],
        channels: [YouTubeChannel] = [],
        playlists: [YouTubePlaylist] = [],
        estimatedResults: Int? = nil,
        continuation: String? = nil
    ) {
        self.videos = videos
        self.channels = channels
        self.playlists = playlists
        self.estimatedResults = estimatedResults
        self.continuation = continuation
    }
}

/// A chapter marker from the watch page.
public struct YouTubeChapter: Sendable, Hashable, Codable {
    public var title: String
    public var startSeconds: Int
    public var thumbnailURL: String?

    public init(title: String, startSeconds: Int, thumbnailURL: String? = nil) {
        self.title = title
        self.startSeconds = startSeconds
        self.thumbnailURL = thumbnailURL
    }
}

/// Watch-page data from a `/next` call.
public struct YouTubeWatch: Sendable, Hashable, Codable {
    public var video: YouTubeVideo?
    public var related: [YouTubeVideo]
    public var chapters: [YouTubeChapter]
    /// `get_transcript` params for the transcript panel.
    public var transcriptParams: String?
    /// Continuation token for the full comment section.
    public var commentsContinuation: String?
    /// Continuation token for more related rows.
    public var continuation: String?

    public init(
        video: YouTubeVideo? = nil,
        related: [YouTubeVideo] = [],
        chapters: [YouTubeChapter] = [],
        transcriptParams: String? = nil,
        commentsContinuation: String? = nil,
        continuation: String? = nil
    ) {
        self.video = video
        self.related = related
        self.chapters = chapters
        self.transcriptParams = transcriptParams
        self.commentsContinuation = commentsContinuation
        self.continuation = continuation
    }
}

/// One timed line of a transcript.
public struct YouTubeTranscriptSegment: Sendable, Hashable, Codable {
    public var text: String
    public var startMilliseconds: Int
    public var durationMilliseconds: Int?

    public init(text: String, startMilliseconds: Int, durationMilliseconds: Int? = nil) {
        self.text = text
        self.startMilliseconds = startMilliseconds
        self.durationMilliseconds = durationMilliseconds
    }
}

/// A caption track from a player response. Its `baseUrl` serves timedtext
/// (`&fmt=json3`) directly, without a PoToken.
public struct YouTubeCaptionTrack: Sendable, Hashable, Codable {
    public var languageCode: String?
    public var name: String?
    /// `asr` tracks are auto-generated.
    public var isAutoGenerated: Bool
    public var baseURL: String?

    public init(languageCode: String?, name: String?, isAutoGenerated: Bool, baseURL: String?) {
        self.languageCode = languageCode
        self.name = name
        self.isAutoGenerated = isAutoGenerated
        self.baseURL = baseURL
    }
}

/// Channel landing page: header, tabs and the first videos/playlists page.
public struct YouTubeChannelPage: Sendable, Hashable, Codable {
    public var channel: YouTubeChannel?
    public var bannerURL: String?
    public var tabs: [YouTubeChannelTab]
    public var videos: [YouTubeVideo]
    public var playlists: [YouTubePlaylist]
    public var continuation: String?

    public init(
        channel: YouTubeChannel? = nil,
        bannerURL: String? = nil,
        tabs: [YouTubeChannelTab] = [],
        videos: [YouTubeVideo] = [],
        playlists: [YouTubePlaylist] = [],
        continuation: String? = nil
    ) {
        self.channel = channel
        self.bannerURL = bannerURL
        self.tabs = tabs
        self.videos = videos
        self.playlists = playlists
        self.continuation = continuation
    }
}
