//
//  DurationResolver.swift
//  Trop
//
//  Created by 686udjie on 2/07/2026.
//

import Combine
import Foundation

/// Resolves unknown track durations via the shared `InnerTubeClient`,
/// shared by every song row and grid cell.
final class DurationResolver: ObservableObject {
    @Published var resolved = 0

    func effectiveDuration(known: Int) -> Int {
        known > 0 ? known : resolved
    }

    func resolve(videoId: String, knownDuration: Int) async {
        guard knownDuration <= 0 else { return }
        if let duration = await InnerTubeClient.tropShared.resolveDuration(videoId: videoId) {
            resolved = duration
        }
    }

    func handleUpdate(_ notification: Notification, videoId: String?) {
        guard let vid = notification.userInfo?["videoId"] as? String, vid == videoId else { return }
        resolved = DurationCache.get(vid) ?? 0
    }
}
