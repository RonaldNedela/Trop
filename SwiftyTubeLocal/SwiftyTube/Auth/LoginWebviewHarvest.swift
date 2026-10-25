//
//  LoginWebviewHarvest.swift
//  SwiftyTube
//
//  Created by 686udjie on 23/10/2026.
//

import WebKit

/// Collects a session from a webview navigating Google sign-in, once it lands
/// on music.youtube.com. Pairs with `SessionTokenRefresher` for later renewal.
///
/// Apps own the webview itself (their own Google OAuth UI); SwiftyTube owns
/// the harvest rules. The rules matter — see Docs/Usage.md ("Webview sign-in"):
///
/// 1. The webview MUST present Google's desktop login flow with a desktop
///    Safari user agent (Google serves a cookie-incomplete mobile flow to
///    mobile UAs).
/// 2. The first harvestable snapshot right after the redirect is incomplete.
///    Harvesting immediately makes `account/account_menu` answer with a
///    guest-shaped menu while requests still return healthy-looking 200s.
///    Poll instead, and import once the youtube.com family carries fresh
///    `__Secure-1PSIDTS`/`__Secure-3PSIDTS` tokens and a SAPISID.
@MainActor
public enum LoginWebviewHarvest {
    /// Desktop Safari UA — required for the login webview (see docs).
    public static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Safari/605.1.15"

    /// Polls the webview's cookie store once per second and returns the
    /// harvested session (movable straight into `AuthState`), or nil after
    /// `maxAttempts` seconds without a complete snapshot.
    ///
    /// `shouldContinue` is probed before every poll; return false to abort
    /// (e.g. the sheet was dismissed, or the caller already imported a
    /// session). Callers that need the confirmable name/photo should verify
    /// with `InnerTubeClient.accountInfo()` after import.
    public static func collectSession(
        from webView: WKWebView,
        maxAttempts: Int = 25,
        shouldContinue: (() -> Bool)? = nil
    ) async -> (cookies: [String: String], sapisid: String)? {
        for attempt in 1 ... maxAttempts {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if let shouldContinue, !shouldContinue() { return nil }
            let cookies: [HTTPCookie] = await withCheckedContinuation { continuation in
                webView.configuration.websiteDataStore.httpCookieStore
                    .getAllCookies { continuation.resume(returning: $0) }
            }
            let (harvested, sapisid) = CookieHarvest.select(from: cookies)
            // Wait for a SAPISID and the rotated yt-domain tokens, always
            // giving the redirect chain a minimum settle before trusting
            // the snapshot; fall back to the last snapshot at the cap.
            if let sapisid, (CookieHarvest.hasFreshRotatingTokens(harvested) && attempt >= 3)
                || attempt == maxAttempts {
                SwiftyTubeLog.notice("Login webview harvest: complete after \(attempt)s")
                return (harvested, sapisid)
            }
        }
        return nil
    }
}
