//
//  AccountMenuTests.swift
//  SwiftyTubeTests
//
//  Created by 686udjie on 23/10/2026.
//

import Foundation
import Testing

@testable import SwiftyTube

// Fixtures for the two `account/account_menu` envelopes.

private func runsHeader(_ accountName: String, email: String? = nil) -> [String: Any] {
    var renderer: [String: Any] = [
        "accountName": ["runs": [["text": accountName]]],
        "accountPhoto": ["thumbnails": [["url": "https://x/p.jpg"]]]
    ]
    if let email {
        renderer["email"] = ["runs": [["text": email]]]
    }
    return renderer
}

@Suite("Account menu session probe")
struct AccountMenuTests {
    @Test("Chrome menu shape (activeAccountHeaderRenderer) verifies signed in")
    func chromeMenu() {
        let json: [String: Any] = [
            "actions": [
                ["openPopupAction": [
                    "popup": ["multiPageMenuRenderer": [
                        "header": ["activeAccountHeaderRenderer": runsHeader("Test User", email: "t@example.com")]
                    ]]
                ]]
            ]
        ]
        let identity = BrowseLens.signedInAccount(json)
        #expect(identity?.name == "Test User")
        #expect(identity?.email == "t@example.com")
        #expect(identity?.hasPhoto == true)
    }

    @Test("musicMultiPageMenuRenderer popup variant verifies signed in")
    func musicPopupVariant() {
        let json: [String: Any] = [
            "actions": [
                ["openPopupAction": [
                    "popup": ["musicMultiPageMenuRenderer": [
                        "header": ["activeAccountHeaderRenderer": ["accountName": ["runs": [["text": "YTM User"]]]]]
                    ]]
                ]]
            ]
        ]
        #expect(BrowseLens.signedInAccount(json)?.name == "YTM User")
    }

    @Test("Legacy top-level musicAccountHeaderRenderer verifies signed in")
    func legacyHeader() {
        let json: [String: Any] = ["header": ["musicAccountHeaderRenderer": runsHeader("Legacy User")]]
        #expect(BrowseLens.signedInAccount(json)?.name == "Legacy User")
    }

    @Test("simpleText fields resolve too")
    func simpleTextVariant() {
        let json: [String: Any] = [
            "header": ["musicAccountHeaderRenderer": [
                "accountName": ["simpleText": "Simple User"],
                "email": ["simpleText": "s@example.com"]
            ]]
        ]
        let identity = BrowseLens.signedInAccount(json)
        #expect(identity?.name == "Simple User")
        #expect(identity?.email == "s@example.com")
    }

    @Test("Signed-out menu (no account header) verifies not signed in")
    func signedOutMenu() {
        let json: [String: Any] = [
            "actions": [
                ["openPopupAction": [
                    "popup": ["multiPageMenuRenderer": [
                        "sections": [
                            ["multiPageMenuSectionRenderer": [
                                "items": [["signInButtonRenderer": ["text": ["runs": [["text": "Sign in"]]]]]]
                            ]]
                        ]
                    ]]
                ]]
            ]
        ]
        #expect(BrowseLens.signedInAccount(json) == nil)
    }

    // MARK: - Real server guest shape

    /// What Google actually serves for a session whose rotating
    /// `__Secure-*PSIDTS` cookies are absent/presented stale: HTTP 200, a
    /// menu with only compact links (Premium/Settings/Terms/Help/Feedback)
    /// and no header at all — not even a sign-in button.
    private func realGuestMenuJSON() -> [String: Any] {
        [
            "actions": [
                ["openPopupAction": [
                    "popup": ["multiPageMenuRenderer": [
                        "style": "MENU_STYLE_SHORT",
                        "sections": [
                            ["multiPageMenuSectionRenderer": [
                                "items": [
                                    ["compactLinkRenderer": [
                                        "icon": ["iconType": "UNLIMITED"],
                                        "title": ["runs": [["text": "Get Music Premium"]]]
                                    ]],
                                    ["compactLinkRenderer": [
                                        "icon": ["iconType": "SETTINGS"],
                                        "title": ["runs": [["text": "Settings"]]]
                                    ]],
                                    ["compactLinkRenderer": [
                                        "icon": ["iconType": "PRIVACY_INFO"],
                                        "title": ["runs": [["text": "Terms & privacy policy"]]]
                                    ]],
                                    ["compactLinkRenderer": [
                                        "icon": ["iconType": "HELP"],
                                        "title": ["runs": [["text": "Help"]]]
                                    ]],
                                    ["compactLinkRenderer": [
                                        "icon": ["iconType": "FEEDBACK"],
                                        "title": ["runs": [["text": "Send feedback"]]]
                                    ]]
                                ]
                            ]]
                        ]
                    ]]
                ]]
            ],
            "trackingParams": "CAE"
        ]
    }

    @Test("Real guest menu (200 OK, link-only items, no header) verifies not signed in")
    func realGuestMenuHasNoAccount() {
        #expect(BrowseLens.signedInAccount(realGuestMenuJSON()) == nil)
    }

    @Test("extractAccountInfo falls back to Guest for the real menu shape")
    func extractAccountInfoGuestShape() {
        let info = InnerTubeClient.extractAccountInfo(from: realGuestMenuJSON())
        #expect(info.name == "Guest")
        #expect(info.thumbnailUrl == nil)
    }

    @Test("extractAccountInfo reads name/photo from the chrome header shape")
    func extractAccountInfoHeaderShape() {
        let json: [String: Any] = [
            "actions": [
                ["openPopupAction": [
                    "popup": ["multiPageMenuRenderer": [
                        "header": ["activeAccountHeaderRenderer": [
                            "accountName": ["runs": [["text": "Real User"]]],
                            "email": ["runs": [["text": "r@example.com"]]],
                            "channelHandle": ["runs": [["text": "@realuser"]]],
                            "accountPhoto": ["thumbnails": [
                                ["url": "https://yt3.ggpht.com/small", "width": 32],
                                ["url": "https://yt3.ggpht.com/big", "width": 96]
                            ]]
                        ]]
                    ]]
                ]]
            ]
        ]
        let info = InnerTubeClient.extractAccountInfo(from: json)
        #expect(info.name == "Real User")
        #expect(info.email == "r@example.com")
        #expect(info.channelHandle == "@realuser")
        #expect(info.thumbnailUrl == "https://yt3.ggpht.com/big")
    }
}
