# SwiftyTube Usage

Every snippet assumes `import SwiftyTube`. This is the shared transport and
infrastructure reference. Surface-specific guides:

- **[YouTube Music](Music.md)** - music home, library, playlists, library sync.
- **[YouTube](YouTube.md)** - feeds, search filters, watch/channel parsing, captions, video playback.

## Client

```swift
let tube = InnerTubeClient(config: .music)   // YouTube Music
let tube = InnerTubeClient(config: .youtube) // YouTube

await tube.updateLocale(YouTubeLocale(gl: "DE", hl: "de")) // change region anytime
```

## Sign-in

```swift
let auth = try SessionImporter.importSession(from: cookieString)
// persist auth.cookies / .sapisid / .visitorData / .dataSyncId your way
await tube.loadState(from: store) // re-call after login/logout; store has 4 getters
```

### Webview sign-in

When a session is captured from a WKWebView instead of a pasted cookie
string, three steps are **required**. Skipping any of them produces a
healthy-looking 200 everywhere while authenticated endpoints (`account/account_menu`,
liked-songs sync) silently answer as an anonymous guest:

```swift
// 1. Present Google's login with the DESKTOP Safari user agent - Google
//    serves a cookie-incomplete mobile flow to mobile UAs.
webView.customUserAgent = LoginWebviewHarvest.userAgent

// 2. Poll for the harvest; do NOT read the cookie store once. The first
//    snapshot after the redirect is incomplete - Google reissues the
//    rotating __Secure-1PSIDTS/3PSIDTS through the redirect chain and the
//    landing page's first seconds.
let session = await LoginWebviewHarvest.collectSession(from: webView)
//    -> (cookies, sapisid); nil after 25s - ask the user to log in again.

// 3. Load it into the client.
await tube.loadState(from: store)
```

Rules `collectSession` (and everything below) are built around:

- The session cookie map is the **youtube.com cookie family only**. Google
  issues one family per auth domain (`.google.com`, `.google.com.hk`, …)
  with different domain-derived values, and a browser never sends
  `.google.com` cookies to a youtube.com host — mixing a google family's
  values into the overlapping youtube names (HSID/SSID/SID/…) makes every
  request answer as anonymous.
- Fresh `__Secure-1PSIDTS`/`__Secure-3PSIDTS` tokens live only in that
  youtube.com family; a session without them is rejected as expired.

### Refreshing a stale session

Google keeps rotating the yt-domain tokens, and a session reconstructed
from a webview too long ago can go stale overnight. Loading
music.youtube.com again does not re-mint anything — only a
**accounts.google.com round trip** does (`SessionTokenRefresher`, same rules
as above, offscreen). Run it once when `account/account_menu` starts
answering guest-shaped with a valid-looking session:

```swift
let reissued = await SessionTokenRefresher.shared.refreshRotatedTokens(baseCookies: savedCookies)
// empty -> re-login needed; otherwise persist `reissued`, re-call
// loadState, and confirm via accountInfo() (should be non-guest now)
```

Keep `shouldContinue` false-able (dismiss/login-already-imported guards) and
always confirm the refresh worked through `accountInfo()` — a guest-shaped
menu is the only visible symptom of any of this going wrong.

## Artwork quality

YouTube serves every size from one URL via a `w<n>-h<n>` hint, and sources
run to ~1400px, so asking up is free. `ArtworkURLs` rewrites thumbnail URLs
for a given pixel size, and exposes a per-surface ladder so each surface
shares one cache entry:

```swift
ArtworkURLs.artwork(url, at: 1200)   // rewrite the hint on a CDN URL
ArtworkURLs.highRes(url)              // same, at the player rung
ArtworkURLs.sized(url, width: 480, height: 480)
ArtworkURLs.rung(for: 450)            // 480 — smallest ladder rung covering it
ArtworkURLs.maxResVariant(url)        // ytimg → maxresdefault (strip ?sqp=…)
ArtworkURLs.sdVariant(url)            // ytimg → sddefault (more likely to exist)
ArtworkURLs.fallback(for: videoId)    // guaranteed hqdefault
```

Rungs: rows 160, cards 480, headers 720, player 1200. Video thumbnails
(ytimg) carry no size hint — swap `hqdefault` via `maxResVariant`/`sdVariant`
instead of rewriting.

## Transport

Raw JSON in, your models out. All calls take optional `client:` / `locale:`
overrides. Browse ids, search filters and parsers differ per surface; see
[Music](Music.md) and [YouTube](YouTube.md).

```swift
let page = try await tube.browse(browseId: browseId)
let page2 = try await tube.browse(continuation: token)
let results = try await tube.search(query: "lofi")
let upNext = try await tube.next(videoId: id, playlistId: playlist) // or next(continuation:)
let typed: PlayerResponse = try await tube.playerResponse(videoId: id)

// Collect all pages instead of handling continuations by hand:
let items = try await tube.paginate(
    browseId: browseId,
    parse: { MyParser.items(from: $0) },
    continuation: { MyParser.token(from: $0) }
)
```

## Play a stream

Walks the fallback chain, mints PoTokens lazily, validates, caches - returns the first working stream:

```swift
var request = StreamResolveRequest.playback(videoId: id)
request.options.audioQuality = .high
let result = try await StreamFallback.resolveFirstValid(
    request, using: tube, providers: .live
)
// result.streamUrl, .title, .author, .duration, .loudnessDb, ...

let download = StreamResolveRequest.download(videoId: id) // no cache, AAC preferred
```

`.live` wires the shared cipher fetcher, WebView, config store, and format tracking. Add yours:

```swift
var providers = StreamResolveProviders.live
providers.poTokenProvider = { videoId in
    try? await PoTokenGenerator.shared.generate(videoId: videoId, sessionId: mySessionId)
}
providers.resolvedFormatHandler = { info in
    // persist info.itag / .mimeType / .playbackUrl for tracking
}
```

One client, no loop:

```swift
let result = try await StreamResolver.resolve(
    videoId: id, client: .androidVr1_65_10, using: tube, providers: providers
)
let ok = await StreamResolver.validateStream(url: result.streamUrl)
```

## Durations

Never throws - cached value, fresh fetch, or nil while another task fetches:

```swift
if let seconds = await tube.resolveDuration(videoId: id) { ... }
// completion posts NotificationCenter .durationDidUpdate with ["videoId": id]
```

## PoTokens and cipher (standalone)

```swift
let tokens = try await PoTokenGenerator.shared.generate(videoId: id, sessionId: sid)
// tokens.playerRequestPoToken → /player body, .streamingDataPoToken → &pot=

let sts = try await PlayerJsFetcher.shared.getSignatureTimestamp()
let url = try await CipherExecutor.shared.resolveCipherURL(
    cipherText: cipher, playerJs: js, playerHash: nil
)
let config = await PlayerConfigStore.shared.config(for: hash)
```

`po_token.html` ships with the package; apps with their own copy keep working as a fallback.

## Parsing helpers

Nil instead of crashes:

```swift
InnerTubeJSON.runsText(dict)              // joined runs, falls back to simpleText
InnerTubeJSON.runsTexts(dict)             // all run texts minus separators
InnerTubeJSON.lastThumbnailURL(list)      // largest thumbnail
InnerTubeDecode.dict(at: ["contents", "x"], in: json)
InnerTubeDecode.string(at: [...], in: json)
InnerTubeDecode.intFromStringOrInt(value) // String-or-Int fields
InnerTubeDecode.continuationToken(in: shelf)
```

## Keychain, HTTP, logging

```swift
let store = SecureStore(service: "com.myapp.session")
try store.save(data, for: "key")
let data = try store.load(for: "key") // throws .notFound when missing

let (data, response) = try await HttpClient.validatedData(for: request)
try await RetryPolicy.innerTube.run({ try await fetch() }, isRetryable: { _ in true })

SwiftyTubeLog.handler = { message, level in myLogger.log("\(level): \(message)") }
// default forwards to os.Logger, subsystem "SwiftyTube"
```
