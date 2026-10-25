//
//  SessionTokenRefresher.swift
//  SwiftyTube
//
//  Created by 686udjie on 23/10/2026.
//

import WebKit

#if canImport(UIKit)
import UIKit
#endif

/// Google rotates the `__Secure-1PSIDTS`/`__Secure-3PSIDTS` tokens
/// continuously and stops trusting a session that keeps presenting stale
/// ones — some endpoints (e.g. `account/account_menu`) then answer with a
/// guest-shaped menu while most browsing/playback endpoints still work.
///
/// How the renewal works (and why it must work this way — see
/// Docs/Usage.md "Webview sign-in"):
///
/// Loading music.youtube.com directly does *not* re-mint anything — it
/// renders the signed-out page when presented with a stale SIDTS. Only an
/// **accounts.google.com round trip** reissues the YouTube-domain cookies
/// from the Google session the cookies still prove. So the refresher seeds
/// the saved session cookies into an offscreen webview (with the required
/// desktop Safari UA), navigates through the Google sign-in entry point
/// (which auto-redirects back when the session is accepted), waits for the
/// landing page to settle, and runs `CookieHarvest.select` on the reissued
/// set.
@MainActor
public final class SessionTokenRefresher: NSObject {
    public static let shared = SessionTokenRefresher()

    private var webView: WKWebView?
    #if canImport(UIKit)
    private var hostWindow: UIWindow?
    #endif
    private var isRunning = false

    static let loginEntryURL = URL(
        string: "https://accounts.google.com/ServiceLogin?service=youtube&continue=https%3A%2F%2Fmusic.youtube.com%2F"
    )!

    public override init() {
        super.init()
    }

    /// Runs a silent renewal. Returns the complete reissued cookie set
    /// (domain-consistent and deduplicated), or `[ ]` if the round trip never
    /// proved the session (which means a real re-login is needed). Callers
    /// should persist the result, re-run `loadState`, and confirm via
    /// `accountInfo()`; a successful renewal shows up as new
    /// `__Secure-*PSIDTS` values ("changed cookies: …").
    @discardableResult
    public func refreshRotatedTokens(
        baseCookies: [String: String],
        pollSeconds: Int = 40
    ) async -> [String: String] {
        guard !isRunning else { return [:] }
        isRunning = true
        defer { isRunning = false }

        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        let store = config.websiteDataStore.httpCookieStore

        for (name, value) in baseCookies {
            let domain = CookieHarvest.isGoogleAuthCookie(name) ? ".google.com" : ".youtube.com"
            let cookie = HTTPCookie(properties: [.name: name, .value: value, .domain: domain, .path: "/"])
            if let cookie { await store.setCookie(cookie) }
        }

        let page = WKWebView(frame: CGRect(x: 0, y: 0, width: 200, height: 200), configuration: config)
        page.customUserAgent = LoginWebviewHarvest.userAgent
        webView = page // keep alive for the whole round trip
        // WKWebView navigation is most reliable inside the view hierarchy —
        // park the webview in a tiny offscreen window so nothing is visible.
        #if canImport(UIKit)
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive || $0 is UIWindowScene }) as? UIWindowScene {
            let win = UIWindow(windowScene: scene)
            win.frame = CGRect(x: -900, y: -900, width: 200, height: 200)
            win.alpha = 0.01
            win.addSubview(page)
            win.windowLevel = UIWindow.Level(rawValue: -500)
            hostWindow = win
        }
        #endif

        SwiftyTubeLog.notice("SessionTokenRefresher: silent round trip with \(baseCookies.count) cookies")
        page.load(URLRequest(url: Self.loginEntryURL))

        // Poll until the navigation lands back on music.youtube.com — reaching
        // it is the proof Google accepted the session without interaction.
        var landed = false
        for poll in 0 ..< pollSeconds {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if let url = page.url, url.host?.contains("music.youtube.com") == true {
                landed = true
                SwiftyTubeLog.notice("SessionTokenRefresher: landed on music.youtube.com after \(poll + 1)s")
                break
            }
            if poll % 5 == 0, poll > 0 {
                SwiftyTubeLog.debug("SessionTokenRefresher: still navigating (poll \(poll)s, url host: \(page.url?.host ?? "nil"))")
            }
        }
        guard landed else {
            SwiftyTubeLog.notice("SessionTokenRefresher: never reached music.youtube.com — Google did not accept the session (re-login required)")
            cleanup(page)
            return [:]
        }

        // Let the landing page settle long enough to receive every rotated token.
        try? await Task.sleep(nanoseconds: 4_000_000_000)
        let cookies: [HTTPCookie] = await withCheckedContinuation { continuation in
            store.getAllCookies { continuation.resume(returning: $0) }
        }
        cleanup(page)

        let (harvested, sapisid) = CookieHarvest.select(from: cookies)
        guard sapisid != nil, !harvested.isEmpty else {
            SwiftyTubeLog.notice("SessionTokenRefresher: harvest came back without SAPISID")
            return [:]
        }
        if harvested == baseCookies {
            SwiftyTubeLog.notice("SessionTokenRefresher: reissued set identical — nothing rotated")
            return [:]
        }
        let changed = harvested
            .filter { baseCookies[$0.key] != $0.value }
            .keys
            .sorted()
            .joined(separator: ",")
        SwiftyTubeLog.notice("SessionTokenRefresher: session reissued — changed cookies: \(changed)")
        return harvested
    }

    private func cleanup(_ page: WKWebView) {
        webView = nil
        #if canImport(UIKit)
        hostWindow = nil
        #endif
        _ = page // webview deallocates when the stored refs drop
    }
}
