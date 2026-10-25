# YouTube

YouTube browsing and playback. Shared transport, streams, PoTokens
and helpers live in [Usage](Usage.md).

```swift
let tube = InnerTubeClient(config: .youtube) // WEB client
```

## Feeds and search

Feeds, channel tabs and search filters are just browse ids / `params`:

```swift
let home = try await tube.browse(browseId: YouTubeFeeds.home)      // or .trending
let shorts = try await tube.browse(browseId: YouTubeFeeds.shorts)
let subs = try await tube.browse(browseId: YouTubeFeeds.subscriptions)
let liked = try await tube.browse(browseId: YouTubeFeeds.playlistBrowseId(YouTubeFeeds.likedVideosPlaylistId))
let more = try await tube.search(query: "swift", params: YouTubeSearchFilter.video.rawValue)
let page2 = try await tube.search(query: "swift", continuation: token)
let comments = try await tube.next(continuation: commentsToken)    // also related rows

// Reuse the tab params YouTube hands back rather than hardcoding them:
let tabs = YouTubeFeeds.channelTabs(in: try await tube.browse(browseId: channelId))

try await tube.dislike(videoId: id)
let hints = try await SearchSuggestions.suggest(query: "swi")
```

Search results take an opaque `params` (from `YouTubeSearchFilter`, upload date,
duration and sort-order enums) plus a continuation `token` for paging.

## Parsing feeds, watch pages and channels

Responses are raw JSON, so `YouTubeFeedParser`, `YouTubeWatchParser` and
`YouTubeChannelParser` turn them into models. Current YouTube renders most rows as
`lockupViewModel` (channel tabs, related, search) mixed with classic
`videoRenderer`s; the parsers handle both:

```swift
let results = YouTubeFeedParser.searchResults(in: try await tube.search(query: "swift"))
// results.videos / .channels / .playlists / .continuation

let watch = YouTubeWatchParser.watch(in: try await tube.next(videoId: id), videoId: id)
// watch.video / .related / .chapters / .transcriptParams / .commentsContinuation

let page = YouTubeChannelParser.channelPage(in: try await tube.browse(browseId: channelId))
// page.channel / .bannerURL / .tabs / .videos / .playlists

// Paging: feed the token back into the same call.
let page2 = YouTubeFeedParser.searchResults(in: try await tube.search(query: "swift", continuation: token))
```

Shorts come through the same parsers as `YouTubeFeedParser.videos` with `isShort` set.

## Transcripts

`get_transcript` now requires attestation, so prefer the caption track URL from an
iOS player response (no PoToken):

```swift
let player: PlayerResponse = try await tube.playerResponse(videoId: id, client: .iOS)
let track = YouTubeWatchParser.captionTracks(from: player).first { $0.languageCode == "en" }
if let url = YouTubeTranscript.json3URL(from: track!.baseURL) {
    let (data, _) = try await HttpClient.data(from: URL(string: url)!)
    let cues = YouTubeTranscript.segments(fromJSON3: data)
}
```

`YouTubeWatchParser.watch(...).transcriptParams` and
`tube.transcript(params:)` remain available for signed-in callers that can supply a
PoToken.

## Video playback

Playback uses the YouTube chain and an optional resolution cap:

```swift
var request = StreamResolveRequest(videoId: id, chain: ClientFallbackChain.youtube)
request.options.videoQuality = .p720 // nil-safe: falls to nearest available
let result = try await StreamFallback.resolveFirstValid(request, using: tube, providers: .live)
// result.muxedStreamUrl / .muxedWidth / .muxedHeight
```

## Video streams

```swift
switch try await StreamFallback.resolveVideo(request, using: tube, providers: providers) {
case .muxed(let url):
    play(url)
case .split(let video, let audio, _):
    playEDL(video, audio) // or StreamFallback.combineVideoAndAudio(videoURL:audioURL:duration:)
}
```
