//
//  RetryPolicy.swift
//  SwiftyTube
//
//  Created by 686udjie on 03/10/2026.
//

import Foundation

/// Exponential backoff with jitter. First retry waits `baseDelay`.
public struct RetryPolicy: Sendable {
    public var maxAttempts: Int
    public var baseDelay: TimeInterval
    public var factor: Double
    public var maxDelay: TimeInterval
    public var jitter: TimeInterval

    public init(
        maxAttempts: Int,
        baseDelay: TimeInterval,
        factor: Double,
        maxDelay: TimeInterval,
        jitter: TimeInterval
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.factor = factor
        self.maxDelay = maxDelay
        self.jitter = jitter
    }

    public static let innerTube = RetryPolicy(
        maxAttempts: 3,
        baseDelay: 0.5,
        factor: 2,
        maxDelay: 30.0,
        jitter: 0.2
    )

    public func delay(for attempt: Int) -> TimeInterval {
        let exponential = baseDelay * pow(factor, Double(max(attempt, 0)))
        let capped = min(exponential, maxDelay)
        let jitterAmount = Double.random(in: 0...jitter)
        return capped + jitterAmount
    }

    public func run<T>(
        _ operation: @Sendable () async throws -> T,
        isRetryable: @Sendable (Error) -> Bool,
        onRetry: (@Sendable (Int, Error) -> Void)? = nil
    ) async throws -> T {
        var lastError: Error?
        for attempt in 0 ..< maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                guard attempt < maxAttempts - 1, isRetryable(error) else { break }
                onRetry?(attempt, error)
                let delaySeconds = delay(for: attempt)
                let nanoseconds = UInt64(max(0, delaySeconds) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
            }
        }
        throw lastError ?? RetryError.exhausted
    }
}

public enum RetryError: Error, Sendable, Equatable {
    /// The policy allowed zero attempts, so nothing ran.
    case exhausted
}
