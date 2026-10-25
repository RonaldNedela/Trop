//
//  YouTubeFeedsTests.swift
//  SwiftyTubeTests
//
//  Created by 686udjie on 17/10/2026.
//

import Testing

@testable import SwiftyTube

@Suite("YouTube feeds")
struct YouTubeFeedsTests {
    @Test("Top-level feeds use the watch-feed browse ids")
    func feedIDs() {
        #expect(YouTubeFeeds.home == "FEwhat_to_watch")
        #expect(YouTubeFeeds.trending == "FEtrending")
        #expect(YouTubeFeeds.subscriptions == "FEsubscriptions")
        #expect(YouTubeFeeds.history == "FEhistory")
        #expect(YouTubeFeeds.shorts == "FEshorts")
        #expect(YouTubeFeeds.likedVideosPlaylistId == "LL")
        #expect(YouTubeFeeds.watchLaterPlaylistId == "WL")
    }

    @Test("Playlist browse id gets the VL prefix once")
    func playlistBrowseId() {
        #expect(YouTubeFeeds.playlistBrowseId("LL") == "VLLL")
        #expect(YouTubeFeeds.playlistBrowseId("PL123") == "VLPL123")
        #expect(YouTubeFeeds.playlistBrowseId("VLPL123") == "VLPL123")
    }

    @Test("Channel tabs parse from a two-column channel response")
    func channelTabs() {
        let json: [String: Any] = [
            "contents": [
                "twoColumnBrowseResultsRenderer": [
                    "tabs": [
                        [
                            "tabRenderer": [
                                "title": "Home",
                                "selected": true,
                                "endpoint": ["browseEndpoint": ["browseId": "UCabc"]]
                            ]
                        ],
                        [
                            "tabRenderer": [
                                "title": ["runs": [["text": "Videos"]]],
                                "endpoint": ["browseEndpoint": ["params": "EgZ2aWRlb3M"]]
                            ]
                        ]
                    ]
                ]
            ]
        ]
        let tabs = YouTubeFeeds.channelTabs(in: json)
        #expect(tabs.count == 2)
        #expect(tabs[0].title == "Home")
        #expect(tabs[0].selected)
        #expect(tabs[0].browseId == "UCabc")
        #expect(tabs[1].title == "Videos")
        #expect(tabs[1].params == "EgZ2aWRlb3M")
        #expect(tabs[1].selected == false)
    }

    @Test("Channel tabs tolerate missing contents")
    func channelTabsEmpty() {
        #expect(YouTubeFeeds.channelTabs(in: [:]).isEmpty)
        #expect(YouTubeFeeds.channelTabs(in: ["contents": [:]]).isEmpty)
    }

    @Test("Search filter params are the known protobuf values")
    func searchFilters() {
        #expect(YouTubeSearchFilter.video.rawValue == "EgIQAQ==")
        #expect(YouTubeSearchFilter.channel.rawValue == "EgIQAg==")
        #expect(YouTubeSearchFilter.playlist.rawValue == "EgIQAw==")
        #expect(YouTubeSearchSortOrder.uploadDate.rawValue == "CAI=")
        #expect(YouTubeSearchUploadDate.today.rawValue == "EgIIAg==")
        #expect(YouTubeSearchDuration.long.rawValue == "EgIYAw==")
    }
}
