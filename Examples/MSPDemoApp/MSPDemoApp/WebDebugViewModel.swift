import Foundation

// MARK: - ClipboardReading

protocol ClipboardReading {
    var urlString: String? { get }
}

// MARK: - WebDebugViewModelProtocol

protocol WebDebugViewModelProtocol: AnyObject {
    var clipboardURL: URL? { get }
    var recentURLs: [String] { get }
    var onUpdate: (() -> Void)? { get set }

    func refreshClipboard()

    /// Validates, records in history, and returns the URL.
    /// Returns nil if `urlString` is not a valid http/https URL.
    @discardableResult
    func openURL(_ urlString: String) -> URL?

    func deleteURL(at index: Int)
}

// MARK: - WebDebugViewModel

final class WebDebugViewModel: WebDebugViewModelProtocol {

    // MARK: - Constants

    static let maxHistoryCount = 15
    static let storageKey = "web_debug_recent_urls"

    // MARK: - State

    private(set) var clipboardURL: URL?
    private(set) var recentURLs: [String] = []

    /// Called whenever state changes.
    var onUpdate: (() -> Void)?

    // MARK: - Dependencies

    private let defaults: UserDefaults
    private let clipboard: ClipboardReading

    // MARK: - Init

    init(defaults: UserDefaults = .standard, clipboard: ClipboardReading) {
        self.defaults = defaults
        self.clipboard = clipboard
        loadHistory()
    }

    // MARK: - WebDebugViewModelProtocol

    func refreshClipboard() {
        let previous = clipboardURL?.absoluteString
        let string = clipboard.urlString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let url = URL(string: string), url.scheme == "http" || url.scheme == "https" {
            clipboardURL = url
        } else {
            clipboardURL = nil
        }
        if previous != clipboardURL?.absoluteString {
            onUpdate?()
        }
    }

    @discardableResult
    func openURL(_ urlString: String) -> URL? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              url.scheme == "http" || url.scheme == "https" else {
            return nil
        }
        addToHistory(trimmed)
        onUpdate?()
        return url
    }

    func deleteURL(at index: Int) {
        guard recentURLs.indices.contains(index) else { return }
        recentURLs.remove(at: index)
        saveHistory()
        onUpdate?()
    }

    // MARK: - Private

    private func loadHistory() {
        recentURLs = defaults.stringArray(forKey: Self.storageKey) ?? []
    }

    private func saveHistory() {
        defaults.set(recentURLs, forKey: Self.storageKey)
    }

    private func addToHistory(_ urlString: String) {
        recentURLs.removeAll { $0 == urlString }
        recentURLs.insert(urlString, at: 0)
        if recentURLs.count > Self.maxHistoryCount {
            recentURLs = Array(recentURLs.prefix(Self.maxHistoryCount))
        }
        saveHistory()
    }
}
