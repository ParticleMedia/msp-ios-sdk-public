//
//  NovaAdHtmlMediaModel.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 10/29/25.
//

/// A model representing HTML media content with support for multiple pages.
///
/// This struct maintains internal state to track the current page index and provides
/// methods to navigate through pages. Since `toNextPage()` mutates the internal state,
/// instances must be declared as `var` (not `let`) if page navigation is needed.
public struct NovaAdHtmlMediaModel {
    /// Represents a validated page index within the bounds of total pages.
    struct PageIndex {
        let value: Int

        /// Creates a page index if the value is within valid bounds.
        /// - Parameters:
        ///   - value: The zero-based page index.
        ///   - total: The total number of pages.
        /// - Returns: A valid `PageIndex` or `nil` if out of bounds.
        init?(value: Int, total: Int) {
            guard value >= 0 && value < total else { return nil }
            self.value = value
        }
    }

    private var currentPageIndex: PageIndex
    private let pages: [NovaAdHtmlPageModel]

    /// The current page being displayed.
    var currentPage: NovaAdHtmlPageModel {
        pages[currentPageIndex.value]
    }

    /// Indicates whether there is a next page available.
    var hasNextPage: Bool {
        currentPageIndex.value < pages.count - 1
    }

    /// Initializes the model with a list of HTML pages.
    /// - Parameter pages: An array of `NovaAdHtmlPageModel` objects.
    /// - Throws: An error if the pages array is empty or invalid.
    init(pages: [NovaAdHtmlPageModel]) throws {
        guard let pageIndex = PageIndex(value: 0, total: pages.count) else {
            throw SimpleError(message: "html pages are empty or all invalid")
        }
        self.currentPageIndex = pageIndex
        self.pages = pages
    }

    /// Advances to the next page in the sequence.
    ///
    /// This method mutates the internal state by updating `currentPageIndex`.
    /// After calling this method, `currentPage` will return the next page,
    /// and `hasNextPage` will reflect whether additional pages remain.
    ///
    /// - Throws: An error if there are no more pages available.
    /// - Note: The instance must be declared as `var` for this method to work.
    mutating func toNextPage() throws {
        if let index = PageIndex(value: currentPageIndex.value + 1, total: pages.count) {
            currentPageIndex = index
        } else {
            throw SimpleError(message: "No more pages")
        }
    }
}

public struct NovaAdHtmlPageModel {
    var resource: NovaAdHtmlResource
    var closeCountDownSeconds: Int?
    var closeDelaySeconds: Int?
    var useClickUrl: Bool
    var useCustomClose: Bool
    var appStoreId: Int?

    init(
        resource: NovaAdHtmlResource, closeCountDownSeconds: Int?, closeDelaySeconds: Int?, useClickUrl: Bool,
        useCustomClose: Bool, appStoreId: Int?
    ) {
        self.resource = resource
        self.closeCountDownSeconds = closeCountDownSeconds
        self.closeDelaySeconds = closeDelaySeconds
        self.useClickUrl = useClickUrl
        self.useCustomClose = useCustomClose
        self.appStoreId = appStoreId
    }
}
