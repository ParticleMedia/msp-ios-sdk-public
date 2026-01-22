import Foundation

enum MultipleItemsInfoError: LocalizedError {
    case notEnoughItems

    var errorDescription: String? {
        switch self {
        case .notEnoughItems:
            return "Ad does not have enough items for the specified style."
        }
    }
}

struct NovaAdMultipleItemsInfo: Codable {
    enum Style: String, Codable {
        case carousel = "DEFAULT"
        case collection = "COLLECTION"
    }
    var items: [NovaNativeMultipleItemsItem]
    var style: Style

    init(items: [NovaNativeMultipleItemsItem], style: Style) throws {
        switch style {
        case .carousel:
            guard items.count > 1 else {
                throw MultipleItemsInfoError.notEnoughItems
            }
            self.items = items
            self.style = .carousel
        case .collection:
            // only support one main item with triple now
            guard items.count >= 4 else {
                throw MultipleItemsInfoError.notEnoughItems
            }
            self.items = items
            self.style = .collection
        }
    }
}
