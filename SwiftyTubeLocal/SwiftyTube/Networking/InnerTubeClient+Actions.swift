//
//  InnerTubeClient+Actions.swift
//  SwiftyTube
//
//  Created by 686udjie on 03/10/2026.
//

import Foundation

// Account, library and queue endpoints. Parsing stays in apps.
public extension InnerTubeClient {
    // MARK: - Auth state

    /// Loads persisted session fields from the app's store.
    func loadState(from store: any AuthStateProvider) async {
        let cookies = await store.cookies()
        let sapisid = await store.sapisid()
        let visitorData = await store.visitorData()
        let dataSyncId = await store.dataSyncId()
        SwiftyTubeLog.debug("[Auth] loadState: cookies=\(cookies.count) sapisid=\(sapisid != nil ? "yes" : "no") visitorData=\(visitorData != nil ? "yes" : "no") dataSyncId=\(dataSyncId != nil ? "yes" : "no")")
        auth = AuthState(
            cookies: cookies,
            sapisid: sapisid,
            visitorData: visitorData,
            dataSyncId: dataSyncId
        )
    }

    /// Ensures visitorData is set, fetching it via the home tab if needed.
    func ensureVisitorData(
        client: YouTubeClient? = nil,
        locale: YouTubeLocale? = nil
    ) async throws {
        if auth.visitorData != nil { return }
        let homeId = config.service == .music ? "FEmusic_home" : "FEwhat_to_watch"
        _ = try await browse(browseId: homeId, client: client, locale: locale)
    }

    /// Duration only, via the iOS client.
    func fetchDuration(videoId: String) async throws -> Int {
        let response: PlayerResponse = try await playerResponse(videoId: videoId, client: .iOS)
        guard let lengthSeconds = response.videoDetails?.lengthSeconds,
              let duration = Int(lengthSeconds) else {
            throw InnerTubeError.decodingFailed
        }
        DurationCache.set(videoId, duration)
        return duration
    }

    /// Resolves a channel avatar when a feed/search renderer omits it.
    /// Search lockups can contain the channel name but neither channel ID nor
    /// avatar; `/player` provides the ID and the channel header provides the
    /// canonical avatar image.
    func resolveChannelAvatar(videoId: String) async -> String? {
        do {
            let playerJSON = try await player(videoId: videoId, client: .iOS)
            guard let videoDetails = playerJSON["videoDetails"] as? [String: Any],
                  let channelId = videoDetails["channelId"] as? String,
                  channelId.hasPrefix("UC") else {
                SwiftyTubeLog.debug("[AvatarResolve] no channelId videoId=\(videoId)")
                return nil
            }
            let channelJSON = try await browse(browseId: channelId, client: .web)
            let avatar = YouTubeChannelParser.avatarURL(in: channelJSON)
            return avatar
        } catch {
            SwiftyTubeLog.debug("[AvatarResolve] failed videoId=\(videoId) error=\(error)")
            return nil
        }
    }

    /// Cached duration, else fetch. Nil while another task fetches.
    func resolveDuration(videoId: String) async -> Int? {
        if let cached = DurationCache.get(videoId), cached > 0 {
            return cached
        }
        guard !DurationCache.isPending(videoId) else { return nil }
        DurationCache.markPending(videoId)
        do {
            return try await fetchDuration(videoId: videoId)
        } catch {
            DurationCache.clearPending(videoId)
            return nil
        }
    }

    // MARK: - Pagination

    /// All pages via continuations. Throws on repeats/cap instead of
    /// returning partial data: callers sweep remote state against the result,
    /// so a truncated page must fail the section, not corrupt the library.
    func paginate<T>(
        browseId: String,
        params: String? = nil,
        maxPages: Int = 50,
        client: YouTubeClient? = nil,
        locale: YouTubeLocale? = nil,
        parse: @escaping ([String: Any]) -> [T],
        continuation: @escaping ([String: Any]) -> String?
    ) async throws -> [T] {
        var allItems: [T] = []
        var token: String?
        var seenTokens = Set<String>()
        var pages = 0
        repeat {
            let json: [String: Any]
            if let token {
                json = try await browse(continuation: token)
            } else {
                json = try await browse(browseId: browseId, params: params, client: client, locale: locale)
            }
            allItems.append(contentsOf: parse(json))
            token = continuation(json)
            pages += 1
            if let token, !seenTokens.insert(token).inserted {
                throw InnerTubeError.truncatedResponse("paginate \(browseId): repeated continuation token")
            }
            if pages >= maxPages {
                throw InnerTubeError.truncatedResponse("paginate \(browseId): hit \(maxPages)-page cap")
            }
        } while token != nil
        return allItems
    }

    // MARK: - Account

    /// Account menu (verifies signed-in state).
    func accountMenu(
        client: YouTubeClient? = nil,
        locale: YouTubeLocale? = nil,
        poToken: String? = nil
    ) async throws -> [String: Any] {
        var body: [String: Any] = ["context": contextDict(client: client, locale: locale)]
        if let poToken { body["serviceIntegrityDimensions"] = ["poToken": poToken] }
        return try await post(endpoint: "account/account_menu", body: body, client: client)
    }

    /// Probes `account/account_menu` to confirm the session is still valid.
    func verifySession(
        client: YouTubeClient? = nil,
        locale: YouTubeLocale? = nil
    ) async throws -> Bool {
        let json = try await accountMenu(client: client, locale: locale)
        if let runs = BrowseLens.accountNameRuns(json), !runs.isEmpty {
            return true
        }
        guard let identity = BrowseLens.signedInAccount(json) else {
            if let dumpPath = PlaylistDetailService.dumpDiagnosticJSON(playlistId: "account_menu", json: json) {
                SwiftyTubeLog.notice("verifySession: no account header in menu — dumped response to \(dumpPath)")
            } else {
                SwiftyTubeLog.error("verifySession: empty account menu response")
            }
            return false
        }
        SwiftyTubeLog.debug("verifySession: signed in as \(identity.name ?? "?") email=\(identity.email != nil ? "yes" : "no") photo=\(identity.hasPhoto ? "yes" : "no")")
        return true
    }

    /// Fetches account info (name, email, profile picture).
    func accountInfo(
        client: YouTubeClient? = nil,
        locale: YouTubeLocale? = nil
    ) async throws -> AccountInfo {
        let json = try await accountMenu(client: client, locale: locale)
        let info = Self.extractAccountInfo(from: json)
        if info.name.isEmpty || info.name == "Guest" {
            SwiftyTubeLog.notice("accountInfo: guest-shaped menu — no active account header")
        } else {
            SwiftyTubeLog.notice(
                "accountInfo: name=\(info.name) photo=\(info.thumbnailUrl != nil ? "yes" : "no") email=\(info.email != nil ? "yes" : "no")"
            )
        }
        return info
    }

    static func extractAccountInfo(from json: [String: Any]) -> AccountInfo {
        guard let actions = json["actions"] as? [[String: Any]],
              let first = actions.first,
              let openPopup = first["openPopupAction"] as? [String: Any],
              let popup = openPopup["popup"] as? [String: Any],
              let multiPageMenu = (popup["multiPageMenuRenderer"]
                  ?? popup["musicMultiPageMenuRenderer"]) as? [String: Any],
              let header = multiPageMenu["header"] as? [String: Any],
              let activeAccount = header["activeAccountHeaderRenderer"] as? [String: Any] else {
            return AccountInfo(name: "Guest")
        }
        let name = InnerTubeJSON.runsText(activeAccount["accountName"] as? [String: Any]) ?? "Guest"
        let email = InnerTubeJSON.runsText(activeAccount["email"] as? [String: Any])
        let handle = InnerTubeJSON.runsText(activeAccount["channelHandle"] as? [String: Any])
        let thumbnails = (activeAccount["accountPhoto"] as? [String: Any])?["thumbnails"] as? [[String: Any]]
        return AccountInfo(
            name: name,
            email: email,
            channelHandle: handle,
            thumbnailUrl: InnerTubeJSON.lastThumbnailURL(thumbnails)
        )
    }

    // MARK: - Likes

    func like(
        videoId: String,
        client: YouTubeClient? = nil,
        locale: YouTubeLocale? = nil
    ) async throws -> [String: Any] {
        let body: [String: Any] = [
            "context": contextDict(client: client, locale: locale),
            "target": ["videoId": videoId]
        ]
        return try await post(endpoint: "like/like", body: body, client: client)
    }

    func unlike(
        videoId: String,
        client: YouTubeClient? = nil,
        locale: YouTubeLocale? = nil
    ) async throws -> [String: Any] {
        let body: [String: Any] = [
            "context": contextDict(client: client, locale: locale),
            "target": ["videoId": videoId]
        ]
        return try await post(endpoint: "like/removelike", body: body, client: client)
    }

    func dislike(
        videoId: String,
        client: YouTubeClient? = nil,
        locale: YouTubeLocale? = nil
    ) async throws -> [String: Any] {
        let body: [String: Any] = [
            "context": contextDict(client: client, locale: locale),
            "target": ["videoId": videoId]
        ]
        return try await post(endpoint: "like/dislike", body: body, client: client)
    }

    // MARK: - Transcripts

    /// Transcript segments for a video. `params` is the transcript
    /// continuation token from the watch `next` response's transcript button.
    /// `poToken` is needed by recent YouTube builds (FAILED_PRECONDITION
    /// otherwise); mint one with `PoTokenGenerator`.
    func transcript(
        params: String,
        poToken: String? = nil,
        client: YouTubeClient? = nil,
        locale: YouTubeLocale? = nil
    ) async throws -> [String: Any] {
        var body: [String: Any] = [
            "context": contextDict(client: client, locale: locale),
            "params": params
        ]
        if let poToken {
            body["serviceIntegrityDimensions"] = ["poToken": poToken]
        }
        return try await post(endpoint: "get_transcript", body: body, client: client)
    }

    // MARK: - Library mutations

    /// Library add/remove tokens.
    func feedback(
        tokens: [String],
        client: YouTubeClient? = nil,
        locale: YouTubeLocale? = nil
    ) async throws -> [String: Any] {
        let body: [String: Any] = [
            "context": contextDict(client: client, locale: locale),
            "feedbackTokens": tokens
        ]
        return try await post(endpoint: "feedback", body: body, client: client)
    }

    /// Add, remove, or reorder playlist videos.
    func editPlaylist(
        playlistId: String,
        actions: [[String: Any]],
        client: YouTubeClient? = nil,
        locale: YouTubeLocale? = nil
    ) async throws -> [String: Any] {
        let body: [String: Any] = [
            "context": contextDict(client: client, locale: locale),
            "playlistId": playlistId,
            "actions": actions
        ]
        return try await post(endpoint: "browse/edit_playlist", body: body, client: client)
    }

    /// Create a new playlist.
    func createPlaylist(
        title: String,
        description: String? = nil,
        client: YouTubeClient? = nil,
        locale: YouTubeLocale? = nil
    ) async throws -> [String: Any] {
        var body: [String: Any] = [
            "context": contextDict(client: client, locale: locale),
            "title": title
        ]
        if let description { body["description"] = description }
        return try await post(endpoint: "playlist/create", body: body, client: client)
    }

    /// Delete a playlist.
    func deletePlaylist(
        playlistId: String,
        client: YouTubeClient? = nil,
        locale: YouTubeLocale? = nil
    ) async throws -> [String: Any] {
        let body: [String: Any] = [
            "context": contextDict(client: client, locale: locale),
            "playlistId": playlistId
        ]
        return try await post(endpoint: "playlist/delete", body: body, client: client)
    }

    // MARK: - Subscriptions

    func subscribe(
        channelId: String,
        client: YouTubeClient? = nil,
        locale: YouTubeLocale? = nil
    ) async throws -> [String: Any] {
        let body: [String: Any] = [
            "context": contextDict(client: client, locale: locale),
            "channelIds": [channelId]
        ]
        return try await post(endpoint: "subscription/subscribe", body: body, client: client)
    }

    func unsubscribe(
        channelId: String,
        client: YouTubeClient? = nil,
        locale: YouTubeLocale? = nil
    ) async throws -> [String: Any] {
        let body: [String: Any] = [
            "context": contextDict(client: client, locale: locale),
            "channelIds": [channelId]
        ]
        return try await post(endpoint: "subscription/unsubscribe", body: body, client: client)
    }

    // MARK: - Playback tracking

    func registerPlayback(
        trackingUrl: String,
        playlistId: String? = nil,
        client: YouTubeClient? = nil
    ) async throws {
        let client = client ?? config.defaultClient
        guard let request = RequestBuilder.buildPlaybackTrackingRequest(
            config: config,
            trackingUrl: trackingUrl,
            client: client,
            auth: auth,
            playlistId: playlistId
        ) else {
            SwiftyTubeLog.error("Failed to build playback tracking request")
            throw InnerTubeError.invalidResponse
        }
        let (data, http) = try await HttpClient.data(for: request, session: session)
        guard (200 ... 299).contains(http.statusCode) else {
            SwiftyTubeLog.error("Playback tracking HTTP \(http.statusCode)")
            throw InnerTubeError.httpError(statusCode: http.statusCode, data: data)
        }
        SwiftyTubeLog.debug("Playback registered - status=\(http.statusCode) bytes=\(data.count)")
    }
}
