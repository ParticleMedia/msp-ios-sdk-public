//
//  AsyncValue.swift
//  NovaCore
//
//  Created by Shanyu Li on 2025/12/26.
//

/// A single-shot async container that produces at most one value.
///
/// - `value()` suspends with async/await until the result is available.
/// - `valueIfReady` provides a synchronous, non-blocking read of a successful value.
/// - `resultIfReady` provides a synchronous, non-blocking read of the final result.
/// - `cancel()` cancels the producer and resumes all awaiters with `CancellationError`.
///
/// Multiple callers can await `value()` concurrently and will receive the same outcome.
import Foundation

public final class AsyncValue<T> {
    enum State {
        case pending
        case success(T)
        case failure(Error)
        case cancelled
    }

    private var state: State = .pending
    // Only protects state and continuations; never used for waiting.
    private let lock = NSLock()

    private var continuations: [CheckedContinuation<T, Error>] = []
    private var producerTask: Task<Void, Never>?

    public init(
        priority: TaskPriority? = nil,
        operation: @escaping () async throws -> T
    ) {
        // Start the producer task immediately.
        self.producerTask = Task(priority: priority) { [weak self] in
            guard let self else { return }
            do {
                let value = try await operation()
                self.finish(.success(value))
            } catch is CancellationError {
                self.finish(.cancelled)
            } catch {
                self.finish(.failure(error))
            }
        }
    }

    deinit {
        cancel()
    }

    // MARK: - Public API

    /// Suspends the caller until the value is produced (no polling).
    public func value() async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            var immediateResult: Result<T, Error>?

            lock.lock()
            switch state {
            case .success(let value):
                immediateResult = .success(value)
            case .failure(let error):
                immediateResult = .failure(error)
            case .cancelled:
                immediateResult = .failure(CancellationError())
            case .pending:
                continuations.append(continuation)
            }
            lock.unlock()

            if let immediateResult {
                continuation.resume(with: immediateResult)
            }
        }
    }

    /// Synchronous, non-blocking access to a successful value if ready.
    public var valueIfReady: T? {
        lock.lock()
        defer { lock.unlock() }
        if case .success(let value) = state { return value }
        return nil
    }

    /// Synchronous, non-blocking access to the final result if ready.
    public var resultIfReady: Result<T, Error>? {
        lock.lock()
        defer { lock.unlock() }

        switch state {
        case .success(let value): return .success(value)
        case .failure(let error): return .failure(error)
        case .cancelled: return .failure(CancellationError())
        case .pending: return nil
        }
    }

    /// Cancels the underlying producer task.
    public func cancel() {
        lock.lock()
        producerTask?.cancel()
        producerTask = nil
        lock.unlock()
        finish(.cancelled)
    }

    // MARK: - Internal

    private func finish(_ newState: State) {
        var pendingContinuations: [CheckedContinuation<T, Error>] = []

        lock.lock()
        guard case .pending = state else {
            lock.unlock()
            return
        }
        state = newState
        pendingContinuations = continuations
        continuations.removeAll()
        producerTask = nil
        lock.unlock()

        // Resume outside the lock to avoid re-entrancy hazards.
        switch newState {
        case .success(let value):
            pendingContinuations.forEach { $0.resume(returning: value) }
        case .failure(let error):
            pendingContinuations.forEach { $0.resume(throwing: error) }
        case .cancelled:
            pendingContinuations.forEach { $0.resume(throwing: CancellationError()) }
        case .pending:
            break
        }
    }
}
