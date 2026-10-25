//
//  YouTubeWatchParserTests.swift
//  SwiftyTubeTests
//
//  Created by 686udjie on 17/10/2026.
//

import Foundation
import Testing

@testable import SwiftyTube

private func jsonObject(_ json: String) -> [String: Any] {
    // swiftlint:disable:next force_try force_cast
    try! JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
}

@Suite("YouTube watch parser")
struct YouTubeWatchParserTests {
    private let nextJSON = jsonObject(#"""
    {
      "contents": {
        "twoColumnWatchNextResults": {
          "results": {
            "result": {
              "contents": [
                { "videoPrimaryInfoRenderer": {
                    "title": { "runs": [{ "text": "Current Title" }] },
                    "viewCount": { "videoViewCountRenderer": {
                        "viewCount": { "simpleText": "10 views" } } }
                } },
                { "videoSecondaryInfoRenderer": {
                    "owner": { "videoOwnerRenderer": {
                        "title": { "runs": [{ "text": "Owner" }] },
                        "navigationEndpoint": { "browseEndpoint": { "browseId": "UCo" } }
                    } }
                } }
              ]
            }
          },
          "secondaryResults": {
            "secondaryResults": {
              "results": [
                { "compactVideoRenderer": { "videoId": "rel1", "title": { "simpleText": "Related" } } },
                { "compactVideoRenderer": { "videoId": "cur", "title": { "simpleText": "Self" } } }
              ]
            }
          }
        }
      },
      "playerOverlays": {
        "playerOverlayRenderer": {
          "decoratedPlayerBarRenderer": {
            "decoratedPlayerBarRenderer": {
              "playerBar": {
                "multiMarkersPlayerBarRenderer": {
                  "markersMap": [
                    { "key": "chapters",
                      "value": { "chapters": [
                        { "chapterRenderer": {
                            "title": { "simpleText": "Intro" },
                            "timeRangeStartMillis": 65000
                        } }
                      ] } }
                  ]
                }
              }
            }
          }
        }
      },
      "engagementPanels": [
        { "engagementPanelSectionListRenderer": {
            "engagementPanelTitleHeaderRenderer": { "title": { "runs": [{ "text": "Transcript" }] } },
            "content": { "continuationItemRenderer": { "continuationEndpoint": {
                "getTranscriptEndpoint": { "params": "TPARAMS" } } } }
        } }
      ],
      "comments": {
        "x": { "itemSectionRenderer": {
          "sectionIdentifier": "comment-item-section",
          "contents": [
            { "continuationItemRenderer": { "continuationEndpoint": {
                "continuationCommand": { "token": "CTOKEN" } } } }
          ]
        } }
      }
    }
    """#)

    @Test("watch parses video, related, chapters, transcript and comments")
    func watch() {
        let watch = YouTubeWatchParser.watch(in: nextJSON, videoId: "cur")
        #expect(watch.video?.title == "Current Title")
        #expect(watch.video?.viewCountText == "10 views")
        #expect(watch.video?.channelTitle == "Owner")
        #expect(watch.video?.channelId == "UCo")
        #expect(watch.related.map(\.videoId) == ["rel1"])
        #expect(watch.chapters.first?.title == "Intro")
        #expect(watch.chapters.first?.startSeconds == 65)
        #expect(watch.transcriptParams == "TPARAMS")
        #expect(watch.commentsContinuation == "CTOKEN")
    }

    @Test("transcript parses segment and cue shapes")
    func transcript() {
        let body = jsonObject(#"""
        { "actions": [
            { "seg1": { "transcriptSegmentRenderer": {
                "startMs": "1000", "endMs": "3000",
                "snippet": { "runs": [{ "text": "Hello " }, { "text": "world" }] } } } },
            { "cue": { "transcriptCueRenderer": {
                "startOffsetMs": "5000", "durationMs": "1500",
                "cue": { "simpleText": "Next line" } } } }
        ] }
        """#)
        let segments = YouTubeWatchParser.transcript(in: body)
        #expect(segments.count == 2)
        #expect(segments[0].text == "Hello world")
        #expect(segments[0].startMilliseconds == 1000)
        #expect(segments[0].durationMilliseconds == 2000)
        #expect(segments[1].text == "Next line")
        #expect(segments[1].startMilliseconds == 5000)
    }

    @Test("caption tracks parse from a player response body")
    func captionTracks() {
        let body = jsonObject(#"""
        { "captions": { "playerCaptionsTracklistRenderer": { "captionTracks": [
            { "baseUrl": "https://www.youtube.com/api/timedtext?v=x",
              "name": { "simpleText": "English" }, "languageCode": "en", "vssId": ".en" },
            { "baseUrl": "https://www.youtube.com/api/timedtext?v=x&kind=asr",
              "name": { "runs": [{ "text": "English (auto)" }] }, "languageCode": "en", "kind": "asr" }
        ] } } }
        """#)
        let tracks = YouTubeWatchParser.captionTracks(in: body)
        #expect(tracks.count == 2)
        #expect(tracks[0].name == "English")
        #expect(tracks[0].isAutoGenerated == false)
        #expect(tracks[0].languageCode == "en")
        #expect(tracks[1].isAutoGenerated == true)
        #expect(tracks[1].name == "English (auto)")
    }
}
