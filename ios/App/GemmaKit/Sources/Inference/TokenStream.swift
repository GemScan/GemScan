import Foundation

// MARK: - TokenStream

/// A lightweight wrapper around `AsyncStream<String>` for streaming generated tokens.
///
/// `TokenStream` provides a convenience initialiser that exposes the stream's
/// continuation, making it easy to bridge callback-based token output into
/// Swift concurrency.
public struct TokenStream: Sendable {

    /// The underlying async stream of token strings.
    public let stream: AsyncStream<String>

    /// The continuation used to yield tokens into the stream.
    public let continuation: AsyncStream<String>.Continuation

    // MARK: - Initialization

    /// Creates a new token stream with its paired continuation.
    ///
    /// Use `continuation.yield(_:)` to push tokens and
    /// `continuation.finish()` when generation is complete.
    public init() {
        let (stream, continuation) = AsyncStream<String>.makeStream()
        self.stream = stream
        self.continuation = continuation
    }

    /// Creates a token stream wrapping an existing `AsyncStream` and its continuation.
    ///
    /// - Parameters:
    ///   - stream: An existing async stream of token strings.
    ///   - continuation: The continuation paired with `stream`.
    public init(stream: AsyncStream<String>, continuation: AsyncStream<String>.Continuation) {
        self.stream = stream
        self.continuation = continuation
    }
}

// MARK: - AsyncSequence Forwarding

extension TokenStream: AsyncSequence {
    public typealias Element = String

    public struct AsyncIterator: AsyncIteratorProtocol {
        var inner: AsyncStream<String>.AsyncIterator

        public mutating func next() async -> String? {
            await inner.next()
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(inner: stream.makeAsyncIterator())
    }
}
