//
//  YouTubeChannelParserTests.swift
//  SwiftyTubeTests
//
//  Created by 686udjie on 17/10/2026.
//

import Foundation
import Testing

@testable import SwiftyTube

private func channelJSON(_ json: String) -> [String: Any] {
    // swiftlint:disable:next force_try force_cast
    try! JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
}

@Suite("YouTube channel parser")
struct YouTubeChannelParserTests {
    @Test("Legacy c4TabbedHeaderRenderer parses counts")
    func legacyHeader() {
        let json = channelJSON(#"""
        {
          "header": { "c4TabbedHeaderRenderer": {
            "channelId": "UClegacy",
            "title": { "simpleText": "Legacy" },
            "subscriberCountText": { "simpleText": "1.2M subscribers" },
            "videosCountText": { "runs": [{ "text": "500" }, { "text": " videos" }] },
            "avatar": { "thumbnails": [{ "url": "avatar", "width": 1, "height": 1 }] },
            "banner": { "thumbnails": [{ "url": "banner", "width": 1, "height": 1 }] }
          } },
          "contents": { "singleColumnBrowseResultsRenderer": { "tabs": [
            { "tabRenderer": { "title": "Videos",
                "endpoint": { "browseEndpoint": { "params": "P" } } } }
          ] } }
        }
        """#)
        let page = YouTubeChannelParser.channelPage(in: json)
        #expect(page.channel?.title == "Legacy")
        #expect(page.channel?.channelId == "UClegacy")
        #expect(page.channel?.subscriberCountText == "1.2M subscribers")
        #expect(page.channel?.videoCountText == "500 videos")
        #expect(page.channel?.thumbnailURL == "avatar")
        #expect(page.bannerURL == "banner")
        #expect(page.tabs.first?.title == "Videos")
        #expect(page.tabs.first?.params == "P")
    }

    @Test("pageHeaderRenderer parses title, avatar and metadata")
    func pageHeader() {
        let json = channelJSON(#"""
        {
          "header": { "pageHeaderRenderer": {
            "pageTitle": "Modern",
            "content": { "pageHeaderViewModel": {
              "title": { "dynamicTextViewModel": { "text": { "content": "Modern" } } },
              "image": { "avatarViewModel": { "image": { "sources": [
                { "url": "small", "width": 1, "height": 1 },
                { "url": "big", "width": 100, "height": 100 }
              ] } } },
              "banner": { "imageBannerViewModel": { "image": { "sources": [
                { "url": "pagebanner", "width": 100, "height": 1 }
              ] } } },
              "metadata": { "contentMetadataViewModel": { "metadataRows": [
                { "metadataParts": [
                  { "text": { "content": "2.5M subscribers" } },
                  { "text": { "content": "900 videos" } }
                ] }
              ] } }
            } }
          } },
          "contents": { "twoColumnBrowseResultsRenderer": { "tabs": [
            { "tabRenderer": { "title": "Home", "selected": true,
                "endpoint": { "browseEndpoint": { "browseId": "UCmodern" } } } },
            { "tabRenderer": { "title": "Playlists",
                "endpoint": { "browseEndpoint": { "params": "PP" } } } }
          ] } }
        }
        """#)
        let page = YouTubeChannelParser.channelPage(in: json)
        #expect(page.channel?.title == "Modern")
        #expect(page.channel?.subscriberCountText == "2.5M subscribers")
        #expect(page.channel?.videoCountText == "900 videos")
        #expect(page.channel?.thumbnailURL == "big")
        #expect(page.bannerURL == "pagebanner")
        #expect(page.tabs.count == 2)
        #expect(page.tabs[0].selected)
    }

    @Test("Missing header yields nil channel but keeps tabs")
    func noHeader() {
        let json = channelJSON(#"""
        { "contents": { "twoColumnBrowseResultsRenderer": { "tabs": [
            { "tabRenderer": { "title": "Videos",
                "endpoint": { "browseEndpoint": { "params": "P" } } } }
        ] } } }
        """#)
        let page = YouTubeChannelParser.channelPage(in: json)
        #expect(page.channel == nil)
        #expect(page.tabs.count == 1)
    }
}
