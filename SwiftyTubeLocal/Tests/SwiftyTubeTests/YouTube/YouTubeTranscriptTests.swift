//
//  YouTubeTranscriptTests.swift
//  SwiftyTubeTests
//
//  Created by 686udjie on 17/10/2026.
//

import Foundation
import Testing

@testable import SwiftyTube

@Suite("YouTube transcript")
struct YouTubeTranscriptTests {
    @Test("JSON3 events become segments and skip empty ones")
    func json3() throws {
        let json = #"""
        {"events":[
            {"tStartMs":0,"dDurationMs":1200,"segs":[{"utf8":"Hello "},{"utf8":"there"}]},
            {"tStartMs":1200,"dDurationMs":300,"segs":[{"utf8":"\n"}]},
            {"tStartMs":1500,"segs":[{"utf8":"Second line"}]}
        ]}
        """#
        let segments = YouTubeTranscript.segments(fromJSON3: Data(json.utf8))
        #expect(segments.count == 2)
        #expect(segments[0].text == "Hello there")
        #expect(segments[0].startMilliseconds == 0)
        #expect(segments[0].durationMilliseconds == 1200)
        #expect(segments[1].text == "Second line")
        #expect(segments[1].durationMilliseconds == nil)
    }

    @Test("Malformed JSON3 yields no segments")
    func malformed() {
        #expect(YouTubeTranscript.segments(fromJSON3: Data("nope".utf8)).isEmpty)
        #expect(YouTubeTranscript.segments(fromJSON3: Data(#"{"events":{}}"#.utf8)).isEmpty)
    }

    @Test("json3URL appends fmt without dropping the query")
    func json3URL() {
        let url = YouTubeTranscript.json3URL(from: "https://www.youtube.com/api/timedtext?v=abc&lang=en")
        #expect(url?.contains("v=abc") == true)
        #expect(url?.contains("fmt=json3") == true)
        #expect(YouTubeTranscript.json3URL(from: "not a url") == nil)
    }
}
