//
//  BrowseLens.swift
//  SwiftyTube
//
//  Created by 686udjie on 09/10/2026.
//

import Foundation

/// Shared descents into InnerTube browse JSON.
public enum BrowseLens: Sendable {
    /// The `sectionListRenderer` dict of a browse response. Tolerates both
    /// single- and two-column layouts plus tabbed/sectionList nesting drift;
    /// returns nil (with a diagnostic) instead of crashing call sites
    public static func sectionList(_ json: [String: Any]) -> [String: Any]? {
        if let sl = InnerTubeDecode.dict(at: ["contents", "singleColumnBrowseResultsRenderer"], in: json)
            .flatMap({ $0["tabs"] as? [[String: Any]] })?.first
            .flatMap({ $0["tabRenderer"] as? [String: Any] })
            .flatMap({ $0["content"] as? [String: Any] })
            .flatMap({ $0["sectionListRenderer"] as? [String: Any] }) {
            return sl
        }
        if let twoCol = InnerTubeDecode.dict(at: ["contents", "twoColumnBrowseResultsRenderer"], in: json),
           let tabs = twoCol["tabs"] as? [[String: Any]],
           let first = tabs.first,
           let tabRenderer = first["tabRenderer"] as? [String: Any],
           let content = tabRenderer["content"] as? [String: Any],
           let sl = content["sectionListRenderer"] as? [String: Any] {
            return sl
        }
        return nil
    }

    /// The section array of a browse response.
    public static func browseSections(_ json: [String: Any]) -> [[String: Any]]? {
        guard let sectionList = sectionList(json),
              let sections = sectionList["contents"] as? [[String: Any]] else { return nil }
        return sections
    }

    /// The first section of a browse response.
    public static func firstBrowseSection(_ json: [String: Any]) -> [String: Any]? {
        browseSections(json)?.first
    }

    /// First section's first item, tolerating single- and two-column
    /// layouts. Used by the album/podcast/playlist detail header parsers.
    public static func firstSectionItem(_ json: [String: Any]) -> [String: Any]? {
        guard let contents = json["contents"] as? [String: Any] else { return nil }
        let singleColumn = contents["singleColumnBrowseResultsRenderer"] as? [String: Any]
        let twoColumn = contents["twoColumnBrowseResultsRenderer"] as? [String: Any]
        let tabsArray: [[String: Any]]? = {
            if let tabs = twoColumn?["tabs"] as? [[String: Any]] { return tabs }
            if let tabs = singleColumn?["tabs"] as? [[String: Any]] { return tabs }
            return nil
        }()
        return tabsArray?.first
            .flatMap { $0["tabRenderer"] as? [String: Any] }
            .flatMap { $0["content"] as? [String: Any] }
            .flatMap { $0["sectionListRenderer"] as? [String: Any] }
            .flatMap { ($0["contents"] as? [[String: Any]])?.first }
    }

    /// Account-name runs from an `account/account_menu` response, used to
    /// probe session validity.
    public static func accountNameRuns(_ json: [String: Any]) -> [[String: Any]]? {
        guard let header = json["header"] as? [String: Any],
              let renderer = header["musicAccountHeaderRenderer"] as? [String: Any],
              let accountName = renderer["accountName"] as? [String: Any],
              let runs = accountName["runs"] as? [[String: Any]] else { return nil }
        return runs
    }

    public static func signedInAccount(_ json: [String: Any]) -> SignedInAccount? {
        func scalarText(_ node: Any?) -> String? {
            guard let dict = node as? [String: Any] else { return nil }
            if let simple = dict["simpleText"] as? String, !simple.isEmpty {
                return simple
            }
            return InnerTubeJSON.runsText(dict)
        }

        var stack: [Any] = [json]
        while let node = stack.popLast() {
            if let dict = node as? [String: Any] {
                for key in ["activeAccountHeaderRenderer", "musicAccountHeaderRenderer"] {
                    guard let renderer = dict[key] as? [String: Any] else { continue }
                    let name = scalarText(renderer["accountName"])
                    let email = scalarText(renderer["email"])
                    let hasPhoto = (renderer["accountPhoto"] as? [String: Any])?["thumbnails"] != nil
                    if hasPhoto || (name != nil && !(name ?? "").isEmpty) {
                        return SignedInAccount(name: name, email: email, hasPhoto: hasPhoto)
                    }
                }
                stack.append(contentsOf: dict.values)
            } else if let array = node as? [Any] {
                stack.append(contentsOf: array)
            }
        }
        return nil
    }
}

public struct SignedInAccount: Sendable, Equatable {
    public let name: String?
    public let email: String?
    public let hasPhoto: Bool

    init(name: String?, email: String?, hasPhoto: Bool) {
        self.name = name
        self.email = email
        self.hasPhoto = hasPhoto
    }
}
