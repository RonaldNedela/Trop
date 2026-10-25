//
//  ArtworkMosaicView.swift
//  Trop
//
//  Created by 686udjie on 13/09/2026.
//

import SwiftUI

/// 2x2 song-artwork mosaic used for playlist artwork, matching the Downloads
/// header. Shared by PlaylistHeaderView and the playlist detail header.
struct ArtworkMosaicView: View {
    var urls: [String]
    var size: CGFloat = 200

    var body: some View {
        let first4 = Array(urls.prefix(4))
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                mosaicTile(url: first4.indices.contains(0) ? first4[0] : nil)
                mosaicTile(url: first4.indices.contains(1) ? first4[1] : nil)
            }
            HStack(spacing: 3) {
                mosaicTile(url: first4.indices.contains(2) ? first4[2] : nil)
                mosaicTile(url: first4.indices.contains(3) ? first4[3] : nil)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 16, y: 6)
    }

    private func mosaicTile(url: String?) -> some View {
        AsyncImageView(url: url)
            .aspectRatio(1, contentMode: .fill)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
