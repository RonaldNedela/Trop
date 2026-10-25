//
//  InnerTubeError.swift
//  SwiftyTube
//
//  Created by 686udjie on 03/10/2026.
//

import Foundation

public enum InnerTubeError: Error, LocalizedError, Sendable {
    case invalidResponse
    case invalidResponseContent(String)
    case httpError(statusCode: Int, data: Data)
    case decodingFailed
    case truncatedResponse(String)
    case sessionExpired

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidResponseContent(let detail):
            return "Invalid response from server: \(detail)"
        case .httpError(let statusCode, _):
            return "HTTP \(statusCode)"
        case .decodingFailed:
            return "Failed to decode response JSON"
        case .truncatedResponse(let detail):
            return "Truncated response: \(detail)"
        case .sessionExpired:
            return "Session expired — sign in again"
        }
    }
}
