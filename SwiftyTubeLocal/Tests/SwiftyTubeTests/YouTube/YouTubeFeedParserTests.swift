//
//  YouTubeFeedParserTests.swift
//  SwiftyTubeTests
//
//  Created by 686udjie on 17/10/2026.
//

import Foundation
import Testing

@testable import SwiftyTube

private func feedJSON(_ json: String) -> [String: Any] {
    // swiftlint:disable:next force_try force_cast
    try! JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
}

@Suite("YouTube feed parser")
struct YouTubeFeedParserTests {
    @Test("videoRenderer yields a full video")
    func videoRenderer() {
        let renderer = feedJSON(#"""
        { "videoRenderer": {
            "videoId": "abc",
            "title": { "runs": [{ "text": "Hello " }, { "text": "World" }] },
            "ownerText": { "runs": [{ "text": "Chan",
                "navigationEndpoint": { "browseEndpoint": { "browseId": "UC123" } } }] },
            "lengthText": { "simpleText": "12:34" },
            "thumbnail": { "thumbnails": [{ "url": "t", "width": 1, "height": 1 }] },
            "viewCountText": { "simpleText": "1,234 views" },
            "publishedTimeText": { "simpleText": "3 days ago" }
        } }
        """#)
        let video = YouTubeFeedParser.videos(in: renderer).first
        #expect(video?.videoId == "abc")
        #expect(video?.title == "Hello World")
        #expect(video?.channelTitle == "Chan")
        #expect(video?.channelId == "UC123")
        #expect(video?.durationSeconds == 754)
        #expect(video?.viewCountText == "1,234 views")
        #expect(video?.publishedTimeText == "3 days ago")
        #expect(video?.isLive == false)
    }

    @Test("compactVideoRenderer picks up the channel avatar")
    func channelAvatar() {
        let renderer = feedJSON(#"""
        { "compactVideoRenderer": {
            "videoId": "cv1",
            "title": { "runs": [{ "text": "Compact" }] },
            "channelThumbnail": {
                "thumbnails": [{ "url": "https://yt3.ggpht.com/a=s68", "width": 68, "height": 68 }]
            }
        } }
        """#)
        let video = YouTubeFeedParser.videos(in: renderer).first
        #expect(video?.channelAvatarURL == "https://yt3.ggpht.com/a=s68")
    }

    @Test("search renderer finds nested avatarViewModel sources")
    func searchNestedChannelAvatar() {
        let renderer = feedJSON(#"""
        { "videoRenderer": {
            "videoId": "search1",
            "title": { "simpleText": "Search result" },
            "channelThumbnail": {
                "avatarViewModel": {
                    "image": { "sources": [{ "url": "https://yt3.ggpht.com/search=s48", "width": 48, "height": 48 }] }
                }
            }
        } }
        """#)
        let video = YouTubeFeedParser.videos(in: renderer).first
        #expect(video?.channelAvatarURL == "https://yt3.ggpht.com/search=s48")
    }

    @Test("search renderer finds avatarStackViewModel sources")
    func searchAvatarStack() {
        let renderer = feedJSON(#"""
        { "videoRenderer": {
            "videoId": "search2",
            "title": { "simpleText": "Search result" },
            "metadata": { "avatarStackViewModel": { "avatars": [
                { "avatarViewModel": { "image": { "sources": [
                    { "url": "https://yt3.ggpht.com/stack=s48", "width": 48, "height": 48 }
                ] } } }
            ] } }
        } }
        """#)
        let video = YouTubeFeedParser.videos(in: renderer).first
        #expect(video?.channelAvatarURL == "https://yt3.ggpht.com/stack=s48")
    }

    @Test("LIVE length text clears duration and flags the video")
    func liveVideo() {
        let renderer = feedJSON(#"""
        { "videoRenderer": { "videoId": "l1", "title": { "simpleText": "Live" },
            "lengthText": { "simpleText": "LIVE" } } }
        """#)
        let video = YouTubeFeedParser.videos(in: renderer).first
        #expect(video?.isLive == true)
        #expect(video?.durationSeconds == nil)
    }

    @Test("reelItemRenderer flags a short")
    func short() {
        let renderer = feedJSON(#"""
        { "reelItemRenderer": { "videoId": "s1", "headline": { "simpleText": "Short title" },
            "thumbnail": { "thumbnails": [] } } }
        """#)
        let video = YouTubeFeedParser.videos(in: renderer).first
        #expect(video?.isShort == true)
        #expect(video?.title == "Short title")
    }

    @Test("videoWithContextRenderer reads headline and shortViewCount")
    func videoWithContext() {
        let renderer = feedJSON(#"""
        { "videoWithContextRenderer": {
            "videoId": "v2",
            "headline": { "runs": [{ "text": "Ctx" }] },
            "shortBylineText": { "runs": [{ "text": "Ch2",
                "navigationEndpoint": { "browseEndpoint": { "browseId": "UC2" } } }] },
            "lengthText": { "simpleText": "3:00" },
            "shortViewCountText": { "simpleText": "5 views" }
        } }
        """#)
        let video = YouTubeFeedParser.videos(in: renderer).first
        #expect(video?.title == "Ctx")
        #expect(video?.channelId == "UC2")
        #expect(video?.durationSeconds == 180)
        #expect(video?.viewCountText == "5 views")
    }

    @Test("lockupViewModel parses a video with classified channel")
    func lockupVideo() {
        let renderer = feedJSON(#"""
        { "lockupViewModel": {
            "contentId": "lv1",
            "contentType": "LOCKUP_CONTENT_TYPE_VIDEO",
            "metadata": { "lockupMetadataViewModel": {
                "title": { "content": "Lockup title" },
                "image": { "decoratedAvatarViewModel": { "avatar": { "avatarViewModel": {
                    "image": { "sources": [{ "url": "avatar", "width": 48, "height": 48 }] }
                } } } },
                "metadata": { "contentMetadataViewModel": { "metadataRows": [
                    { "metadataParts": [
                        { "text": { "content": "ChanX", "commandRuns": [
                            { "onTap": { "innertubeCommand": { "browseEndpoint": { "browseId": "UCX" } } } }
                        ] } },
                        { "text": { "content": "9 views" } }
                    ] }
                ] } }
            } },
            "contentImage": { "thumbnailViewModel": {
                "image": { "sources": [
                    { "url": "small", "width": 1, "height": 1 },
                    { "url": "big", "width": 100, "height": 100 }
                ] },
                "overlays": [{ "thumbnailBottomOverlayViewModel": { "badges": [
                    { "thumbnailBadgeViewModel": { "text": "1:23" } }
                ] } }]
            } }
        } }
        """#)
        let video = YouTubeFeedParser.videos(in: renderer).first
        #expect(video?.videoId == "lv1")
        #expect(video?.title == "Lockup title")
        #expect(video?.channelTitle == "ChanX")
        #expect(video?.channelId == "UCX")
        #expect(video?.viewCountText == "9 views")
        #expect(video?.durationSeconds == 83)
        #expect(video?.thumbnailURL == "big")
        #expect(video?.channelAvatarURL == "avatar")
    }

    @Test("lockupViewModel parses a playlist")
    func lockupPlaylist() {
        let renderer = feedJSON(#"""
        { "lockupViewModel": {
            "contentId": "PL1",
            "contentType": "LOCKUP_CONTENT_TYPE_PLAYLIST",
            "metadata": { "lockupMetadataViewModel": { "title": { "content": "My List" } } },
            "contentImage": { "collectionThumbnailViewModel": { "primaryThumbnail": {
                "thumbnailViewModel": { "image": { "sources": [
                    { "url": "p", "width": 1, "height": 1 }
                ] } }
            } } }
        } }
        """#)
        #expect(YouTubeFeedParser.videos(in: renderer).isEmpty)
        let playlist = YouTubeFeedParser.playlists(in: renderer).first
        #expect(playlist?.playlistId == "PL1")
        #expect(playlist?.title == "My List")
        #expect(playlist?.thumbnailURL == "p")
    }

    @Test("lockupViewModel reads direct metadata avatar image sources")
    func lockupDirectMetadataAvatar() {
        let renderer = feedJSON(#"""
        { "lockupViewModel": {
            "contentId": "music1",
            "contentType": "LOCKUP_CONTENT_TYPE_VIDEO",
            "metadata": { "lockupMetadataViewModel": {
                "title": { "content": "Music video" },
                "image": { "sources": [{ "url": "metadata-avatar", "width": 48, "height": 48 }] }
            } },
            "contentImage": { "thumbnailViewModel": { "image": { "sources": [
                { "url": "video-thumbnail", "width": 1280, "height": 720 }
            ] } } }
        } }
        """#)
        let video = YouTubeFeedParser.videos(in: renderer).first
        #expect(video?.thumbnailURL == "video-thumbnail")
        #expect(video?.channelAvatarURL == "metadata-avatar")
    }

    @Test("Continuation reads both command and legacy shapes")
    func continuation() {
        let command = feedJSON(#"""
        { "x": { "continuationItemRenderer": {
            "continuationEndpoint": { "continuationCommand": { "token": "TOKEN" } } } } }
        """#)
        #expect(YouTubeFeedParser.continuation(in: command) == "TOKEN")
        let legacy = feedJSON(#"""
        { "x": { "continuations": [{ "nextContinuationData": { "continuation": "OLD" } }] } }
        """#)
        #expect(YouTubeFeedParser.continuation(in: legacy) == "OLD")
        #expect(YouTubeFeedParser.continuation(in: [:]) == nil)
    }

    @Test("Duplicate video ids collapse to one row")
    func dedupe() {
        let renderer = feedJSON(#"""
        { "a": { "videoRenderer": { "videoId": "dup", "title": { "simpleText": "A" } } },
          "b": { "videoRenderer": { "videoId": "dup", "title": { "simpleText": "B" } } } }
        """#)
        #expect(YouTubeFeedParser.videos(in: renderer).count == 1)
    }

    @Test("Mixed search response splits by type")
    func searchResults() {
        let renderer = feedJSON(#"""
        { "estimatedResults": "42",
          "contents": {
            "videoRenderer": { "videoId": "v1", "title": { "simpleText": "V" } },
            "channelRenderer": { "channelId": "UCc", "title": { "simpleText": "C" } },
            "playlistRenderer": { "playlistId": "PLp", "title": { "simpleText": "P" } }
          } }
        """#)
        let results = YouTubeFeedParser.searchResults(in: renderer)
        #expect(results.videos.count == 1)
        #expect(results.channels.count == 1)
        #expect(results.playlists.count == 1)
        #expect(results.estimatedResults == 42)
    }

    @Test("Shelves carry a title and their videos")
    func shelves() {
        let renderer = feedJSON(#"""
        { "sectionListRenderer": { "contents": [
            { "shelfRenderer": {
                "title": { "simpleText": "Trending" },
                "content": { "horizontalListRenderer": { "items": [
                    { "videoRenderer": { "videoId": "sv", "title": { "simpleText": "S" } } }
                ] } }
            } }
        ] } }
        """#)
        let shelves = YouTubeFeedParser.shelves(in: renderer)
        #expect(shelves.count == 1)
        #expect(shelves.first?.title == "Trending")
        #expect(shelves.first?.videos.first?.videoId == "sv")
    }
}
