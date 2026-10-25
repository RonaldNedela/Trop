//
//  CookieHarvest.swift
//  SwiftyTube
//
//  Created by 686udjie on 23/10/2026.
//

import Foundation

/// Harvests a usable YouTube session from a webview's cookie store.
///
/// The invariants here are load-bearing and easy to "simplify" into a broken
/// state — see Docs/Usage.md ("Webview sign-in") before touching anything:
///
/// 1. Google issues one session-cookie family per auth domain
///    (`SID`/`HSID`/`SSID`/`SIDCC`/`__Secure-1PSID`+`1PSIDCC`+`1PSIDTS` …)
///    with different domain-derived values per domain (.google.com vs
///    .google.com.hk vs …).
/// 2. InnerTube requests to music.youtube.com / youtube.com must carry ONLY
///    the youtube.com family — a browser never sends .google.com cookies to
///    a youtube.com host. Mixing a google family's values into the overlapping
///    youtube names (HSID/SSID/SID/…) makes every authenticated request
///    answer as anonymous (healthy-looking 200s with guest-shaped responses).
/// 3. The rotating `__Secure-1PSIDTS`/`__Secure-3PSIDTS` tokens exist only in
///    the youtube.com family; a session whose yt-domain tokens are missing or
///    stale is rejected the same way.
public enum CookieHarvest: Sendable {
    /// True for names that belong to the .google.com auth family; everything
    /// else is a youtube.com-domain cookie.
    public static func isGoogleAuthCookie(_ name: String) -> Bool {
        switch name {
        case "SID", "HSID", "SSID", "SIDCC", "APISID", "SAPISID",
             "__Secure-1PSID", "__Secure-3PSID",
             "__Secure-1PAPISID", "__Secure-3PAPISID",
             "__Secure-1PSIDCC", "__Secure-3PSIDCC",
             "__Secure-1PSIDTS", "__Secure-3PSIDTS",
             "OSID", "LSID", "LSOSID":
            return true
        default:
            return false
        }
    }

    /// Builds the session cookie map and SAPISID from a webview cookie dump.
    ///
    /// The returned map is the youtube.com family alone; google.com families
    /// are only used to find a SAPISID fallback for the rare case the yt-domain
    /// family does not carry one (the value is the same across domains).
    public static func select(from cookies: [HTTPCookie]) -> (cookies: [String: String], sapisid: String?) {
        var youtubeCookies: [String: String] = [:]
        var googleGroups: [String: [String: String]] = [:]
        var sapisidByGroup: [String: String] = [:]

        for cookie in cookies {
            let value = cookie.value
            guard !value.isEmpty else { continue }
            let domain = cookie.domain.lowercased()
            if domain.contains("youtube.com") {
                youtubeCookies[cookie.name] = value
            } else if domain.contains("google.") {
                let groupKey: String
                if domain.contains("google.com.hk") {
                    groupKey = "google.com.hk"
                } else if domain.contains("google.com") {
                    groupKey = "google.com"
                } else {
                    groupKey = "google-other-\(domain.replacingOccurrences(of: ".", with: "-"))"
                }
                googleGroups[groupKey, default: [:]][cookie.name] = value
                if cookie.name == "__Secure-3PSAPISID" || cookie.name == "SAPISID" {
                    sapisidByGroup[groupKey] = value
                }
            }
        }

        var sapisid = youtubeCookies["SAPISID"] ?? youtubeCookies["__Secure-3PSAPISID"]
        if sapisid == nil, let googleSapisid = sapisidByGroup.values.first {
            sapisid = googleSapisid
        }
        return (youtubeCookies, sapisid)
    }

    /// True when the cookie map carries the rotated yt-domain tokens Google
    /// requires from a session.
    public static func hasFreshRotatingTokens(_ cookies: [String: String]) -> Bool {
        cookies["__Secure-1PSIDTS"] != nil || cookies["__Secure-3PSIDTS"] != nil
    }
}
