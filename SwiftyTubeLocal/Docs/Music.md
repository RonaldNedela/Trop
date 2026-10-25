# YouTube Music

Music-specific browsing, library and sync. Shared transport, streams, PoTokens
and helpers live in [Usage](Usage.md).

```swift
let tube = InnerTubeClient(config: .music)
```

## Browse, search, player

Feeds are browse ids; the same transport drives music shelves and search:

```swift
let home = try await tube.browse(browseId: "FEmusic_home")
let page2 = try await tube.browse(continuation: token)
let results = try await tube.search(query: "lofi")
let upNext = try await tube.next(videoId: id, playlistId: playlist)
let typed: PlayerResponse = try await tube.playerResponse(videoId: id)

// Collect all pages instead of handling continuations by hand:
let items = try await tube.paginate(
    browseId: "FEmusic_liked_playlists",
    parse: { MyParser.items(from: $0) },
    continuation: { MyParser.token(from: $0) }
)
```

`LibraryBrowseParser` / `BrowseLens` parse the library shelves into
`ParsedSong` / `ParsedAlbum` / `ParsedArtist` / `ParsedPlaylist` /
`ParsedPodcast` when you need the raw rows.

## Library and account

```swift
try await tube.like(videoId: id)
try await tube.unlike(videoId: id)
try await tube.feedback(tokens: [token]) // library add/remove
try await tube.editPlaylist(
    playlistId: id,
    actions: PlaylistEditAction.dictionaries([.addVideo(videoId: id)])
)
try await tube.createPlaylist(title: "Gym")
try await tube.deletePlaylist(playlistId: id)
try await tube.subscribe(channelId: id)
try await tube.unsubscribe(channelId: id)
let me = try await tube.accountInfo() // name, email, avatar
```

`.addVideo(videoId:setVideoId:)`, `.removeVideo(setVideoId:)`, `.renamePlaylist(name:)` build the action dicts. Pair local-then-remote writes with `OptimisticMutation.attemptingRemote(remote, rollback:)`.

## Library sync

The `Sync` module owns library orchestration; your database stays yours.
Conform a store to `LibrarySyncStore` (batch section merges plus song /
playlist / artist / album / podcast primitives), then drive the actors:

```swift
let store: any LibrarySyncStore = MyStore()
let tube = InnerTubeClient(config: .music)
let sync = LibrarySyncService(client: tube, store: store)
let mutations = MutationService(client: tube, store: store)
let incremental = IncrementalSyncService(client: tube, librarySync: sync)

let options = LibrarySyncOptions(syncArtists: true, syncSongs: true /* ... */)
let result = await sync.syncAll(options: options) {
    await likes.refresh()
}
await incremental.checkAndSyncIfStale(options: options)

try await mutations.likeSong(videoId: id)
try await mutations.addToPlaylist(playlistId: id, songId: videoId)
_ = try await mutations.createPlaylist(title: "Gym")
```

`SyncSong` / `SyncPlaylist` carry the same preserve-on-merge policy the actors apply.
