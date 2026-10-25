//
//  YouTubeStreamingTests.swift
//  SwiftyTubeTests
//
//  Created by 686udjie on 17/10/2026.
//

import Foundation
import Testing

@testable import SwiftyTube

private func format(_ json: String) -> Format {
    // swiftlint:disable:next force_try
    try! JSONDecoder().decode(Format.self, from: Data(json.utf8))
}

@Suite("YouTube streaming")
struct YouTubeStreamingTests {
    private let muxed360 = format(
        #"{"itag":18,"mimeType":"video/mp4; codecs=\"avc1.42001E\"","width":640,"height":360,"audioChannels":2,"url":"https://example/360"}"#
    )
    private let muxed720 = format(
        #"{"itag":22,"mimeType":"video/mp4; codecs=\"avc1.64001F\"","width":1280,"height":720,"audioChannels":2,"url":"https://example/720"}"#
    )
    private let muxed1080 = format(
        #"{"itag":37,"mimeType":"video/mp4; codecs=\"avc1.640028\"","width":1920,"height":1080,"audioChannels":2,"url":"https://example/1080"}"#
    )

    @Test("VideoQuality maps to heights")
    func qualityHeights() {
        #expect(VideoQuality.auto.height == nil)
        #expect(VideoQuality.p1080.height == 1080)
        #expect(VideoQuality.p360.height == 360)
    }

    @Test("Height preference caps to the nearest stream at or below")
    func heightCap() {
        let all = [muxed360, muxed720, muxed1080]
        #expect(FormatSelector.bestVideoFormat(from: all, preference: .auto)?.itag == 37)
        #expect(FormatSelector.bestVideoFormat(from: all, preference: .p1080)?.itag == 37)
        #expect(FormatSelector.bestVideoFormat(from: all, preference: .p720)?.itag == 22)
        #expect(FormatSelector.bestVideoFormat(from: all, preference: .p480)?.itag == 18)
    }

    @Test("Height preference above the ceiling picks the smallest stream")
    func heightAboveCeiling() {
        let all = [muxed360, muxed720]
        #expect(FormatSelector.bestVideoFormat(from: all, preference: .p2160)?.itag == 22)
    }

    @Test("SELECT BY HEIGHT handles empty pools")
    func emptyPool() {
        #expect(FormatSelector.selectByHeight([], preference: .p720) { _ in 0 } == nil)
    }

    @Test("YouTube chain ends in the WEB client")
    func youtubeChain() {
        let chain = ClientFallbackChain.youtube
        #expect(chain.last?.client == .web)
        #expect(chain.count == ClientFallbackChain.preferred.count)
    }

    @Test("PlaybackResult carries muxed dimensions through Codable")
    func muxedDimensionsCodable() throws {
        let result = PlaybackResult(
            streamUrl: "u", itag: 22, mimeType: "m", bitrate: 2,
            audioQuality: "q", videoId: "v", title: nil, author: nil,
            duration: nil, expiresInSeconds: 1, clientName: "WEB",
            musicVideoType: nil, hasVideoContent: true,
            muxedStreamUrl: "mu", muxedWidth: 1280, muxedHeight: 720, loudnessDb: nil
        )
        let decoded = try JSONDecoder().decode(PlaybackResult.self, from: try JSONEncoder().encode(result))
        #expect(decoded.muxedWidth == 1280)
        #expect(decoded.muxedHeight == 720)
        #expect(decoded == result)
    }
}
