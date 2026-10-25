//
//  YouTubeParserLiveTests.swift
//  SwiftyTubeTests
//
//  Created by 686udjie on 17/10/2026.
//

// Live smoke tests for the main-YouTube parsers (guest, keyless).

import Foundation
import Testing

@testable import SwiftyTube

@Suite("YouTube parser live")
struct YouTubeParserLiveTests {
    @Test("Search parses video lockups")
    func search() async throws {
        let client = InnerTubeClient(config: .youtube)
        let json = try await client.search(query: "lofi hip hop")
        let results = YouTubeFeedParser.searchResults(in: json)
        #expect(!results.videos.isEmpty)
        #expect(results.videos.allSatisfy { !$0.videoId.isEmpty })
        #expect(results.continuation != nil)
    }

    @Test("Watch parses related, chapters and transcript params")
    func watch() async throws {
        let client = InnerTubeClient(config: .youtube)
        let videoId = "8aGhZQkoFbQ"
        let json = try await client.next(videoId: videoId)
        let watch = YouTubeWatchParser.watch(in: json, videoId: videoId)
        #expect(!watch.related.isEmpty)
        #expect(watch.video?.title.isEmpty == false)
        #expect(watch.transcriptParams != nil)
    }

    @Test("Channel Videos tab parses video lockups")
    func channelVideos() async throws {
        let client = InnerTubeClient(config: .youtube)
        let channelId = "UCuAXFkgsw1L7xaCfnd5JJOw"
        let home = try await client.browse(browseId: channelId)
        #expect(YouTubeChannelParser.channelPage(in: home).channel != nil)
        let videosTab = YouTubeFeeds.channelTabs(in: home)
            .first { $0.title.localizedCaseInsensitiveContains("Video") }
        let json = try await client.browse(browseId: channelId, params: videosTab?.params)
        #expect(!YouTubeFeedParser.videos(in: json).isEmpty)
    }

    @Test("Captions fetch as timedtext without a PoToken")
    func captions() async throws {
        let client = InnerTubeClient(config: .youtube)
        let response: PlayerResponse = try await client.playerResponse(videoId: "8aGhZQkoFbQ", client: .iOS)
        let track = YouTubeWatchParser.captionTracks(from: response)
            .first { $0.languageCode == "en" } ?? YouTubeWatchParser.captionTracks(from: response).first
        let base = try #require(track?.baseURL)
        let url = try #require(YouTubeTranscript.json3URL(from: base))
        let requestURL = try #require(URL(string: url))
        let (data, http) = try await HttpClient.data(from: requestURL)
        #expect(http.statusCode == 200)
        #expect(!YouTubeTranscript.segments(fromJSON3: data).isEmpty)
    }
}
